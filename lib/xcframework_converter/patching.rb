# frozen_string_literal: true

require_relative 'arm_patcher'
require_relative 'xcframework_ext'

require 'cocoapods'
require 'cocoapods/xcode/xcframework'
require 'fileutils'
require 'xcodeproj'

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

# Converts a framework (static or dynamic) to an XCFramework, adding an arm64 simulator patch.
# For more info:
# static libs: https://bogo.wtf/arm64-to-sim.html
# dylibs: https://bogo.wtf/arm64-to-sim-dylibs.html
module XCFrameworkConverter
  class << self
    def patch_xcframework(xcframework_path)
      xcframework = Pod::Xcode::XCFramework.open_xcframework(xcframework_path)

      return nil if xcframework.slices.any? do |slice|
        slice.platform == :ios &&
        slice.platform_variant == :simulator &&
        slice.supported_archs.include?('arm64')
      end

      original_arm_slice = xcframework.slices.find do |slice|
        slice.platform == :ios && slice.supported_archs.include?('arm64')
      end

      simulator_slice = xcframework.slices.find do |slice|
        slice.platform == :ios && slice.platform_variant == :simulator
      end

      patched_simulator_slice_identifier = simulator_slice.identifier.gsub('-simulator', '_arm64-simulator')

      warn "Will patch #{xcframework_path}: #{patched_simulator_slice_identifier}:= " \
           "#{simulator_slice.identifier} + patched(#{original_arm_slice.identifier})"

      plist = xcframework.plist
      slice_plist_to_edit = plist['AvailableLibraries'].find { |s| s['LibraryIdentifier'] == simulator_slice.identifier }
      slice_plist_to_edit['LibraryIdentifier'] = patched_simulator_slice_identifier
      slice_plist_to_edit['SupportedArchitectures'] << 'arm64'

      `xcrun lipo \"#{original_arm_slice.binary_path}\" -thin arm64 -output \"#{simulator_slice.binary_path}.arm64\"`
      `xcrun lipo \"#{simulator_slice.binary_path}\" \"#{simulator_slice.binary_path}.arm64\" -create -output \"#{simulator_slice.binary_path}\"`

      FileUtils.rm_rf("#{simulator_slice.binary_path}.arm64")
      FileUtils.rm_rf(xcframework_path.join(patched_simulator_slice_identifier))
      FileUtils.mv(xcframework_path.join(simulator_slice.identifier), xcframework_path.join(patched_simulator_slice_identifier))

      Xcodeproj::Plist.write_to_path(plist, xcframework_path.join('Info.plist'))

      xcframework = Pod::Xcode::XCFramework.open_xcframework(xcframework_path)

      slice = xcframework.slices.find { |s| s.identifier == patched_simulator_slice_identifier }

      ArmPatcher.patch_arm_binary(slice)
      ArmPatcher.cleanup_unused_archs(slice)

      xcframework_path
    end
  end
end
