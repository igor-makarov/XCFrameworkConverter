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
      original_arm_slice_identifier = original_arm_slice.identifier

      patched_arm_slice_identifier = 'ios-arm64-simulator'

      warn "Will patch #{xcframework_path}: #{original_arm_slice_identifier} -> #{patched_arm_slice_identifier}"

      plist = xcframework.plist
      slice_plist_to_add = plist['AvailableLibraries'].find { |s| s['LibraryIdentifier'] == original_arm_slice_identifier }.dup
      slice_plist_to_add['LibraryIdentifier'] = patched_arm_slice_identifier
      slice_plist_to_add['SupportedArchitectures'] = ['arm64']
      slice_plist_to_add['SupportedPlatformVariant'] = 'simulator'
      plist['AvailableLibraries'] << slice_plist_to_add

      FileUtils.rm_rf(xcframework_path.join(patched_arm_slice_identifier))
      FileUtils.cp_r(xcframework_path.join(original_arm_slice_identifier), xcframework_path.join(patched_arm_slice_identifier))

      Xcodeproj::Plist.write_to_path(plist, xcframework_path.join('Info.plist'))

      xcframework = Pod::Xcode::XCFramework.open_xcframework(xcframework_path)

      slice = xcframework.slices.find { |s| s.identifier == patched_arm_slice_identifier }

      ArmPatcher.fix_bad_arm_binary(original_arm_slice)
      ArmPatcher.patch_arm_binary(slice)
      ArmPatcher.cleanup_unused_archs(slice)

      xcframework_path
    end
  end
end
