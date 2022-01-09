# frozen_string_literal: true

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
    def patch_xcframework(xcframework_path)
      xcframework = Pod::Xcode::XCFramework.open_xcframework(xcframework_path)

      return nil if xcframework.slices.any? do |slice|
        slice.platform == :ios &&
        slice.platform_variant == :simulator &&
        slice.supported_archs.include?('arm64')
      end

      # require 'pry'; binding.pry
      STDERR.puts "Will patch #{xcframework_path}"
      xcframework_path
    end
  end
end
