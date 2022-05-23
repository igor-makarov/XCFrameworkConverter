# frozen_string_literal: true

require_relative 'arm_patcher'
require_relative 'xcframework_ext'

require 'cocoapods'
require 'cocoapods/xcode/xcframework'
require 'fileutils'
require 'xcodeproj'

# rubocop:disable Metrics/AbcSize

# Converts a framework (static or dynamic) to an XCFramework, adding an arm64 simulator patch.
# For more info:
# static libs: https://bogo.wtf/arm64-to-sim.html
# dylibs: https://bogo.wtf/arm64-to-sim-dylibs.html
module XCFrameworkConverter
  class << self
    def plist_template_path
      Pathname.new(__FILE__).dirname.join('../xcframework_template.plist')
    end

    def convert_framework_to_xcframework(path, current_platform)
      plist = Xcodeproj::Plist.read_from_path(plist_template_path)
      xcframework_path = Pathname.new(path).sub_ext('.xcframework')
      xcframework_path.mkdir
      plist['AvailableLibraries'].each do |slice|
        slice_library_identifier = slice['LibraryIdentifier'].sub("platform", "#{current_platform.name}")
        slice_path = xcframework_path.join(slice_library_identifier)
        slice_path.mkdir
        slice['LibraryPath'] = File.basename(path)
        slice['SupportedPlatform'] = current_platform.name
        slice['LibraryIdentifier'] = slice_library_identifier
        FileUtils.cp_r(path, slice_path)
      end
      Xcodeproj::Plist.write_to_path(plist, xcframework_path.join('Info.plist'))
      FileUtils.rm_rf(path)
      final_framework = Pod::Xcode::XCFramework.open_xcframework(xcframework_path)
      final_framework.slices.each do |slice|
        ArmPatcher.patch_arm_binary(slice) if slice.platform == current_platform && slice.platform_variant == :simulator
        ArmPatcher.cleanup_unused_archs(slice)
      end
    end
  end
end
