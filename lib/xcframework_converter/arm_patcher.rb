# frozen_string_literal: true

require 'cocoapods'
require 'cocoapods/xcode/xcframework'
require 'fileutils'
require 'xcodeproj'

# rubocop:disable Metrics/AbcSize

module XCFrameworkConverter
  # Patches a binary (static or dynamic), turning an arm64-device into an arm64-simualtor.
  # For more info:
  # static libs: https://bogo.wtf/arm64-to-sim.html
  # dylibs: https://bogo.wtf/arm64-to-sim-dylibs.html
  module ArmPatcher
    class << self
      def patch_arm_binary(slice)
        require 'macho'

        case slice.build_type.linkage
        when :dynamic
          patch_arm_binary_dynamic(slice)
        when :static
          patch_arm_binary_static(slice)
        end

        slice.path.glob('**/arm64*.swiftinterface').each do |interface_file|
          `sed -i '' -E 's/target arm64-apple-ios([0-9.]+) /target arm64-apple-ios\\1-simulator /g' "#{interface_file}"`
        end
      end

      private

      def patch_arm_binary_dynamic(slice)
        extracted_path = slice.path.join('arm64.dylib')
        `xcrun lipo \"#{slice.binary_path}\" -thin arm64 -output \"#{extracted_path}\"`

        file = MachO::MachOFile.new(extracted_path)
        sdk_version = file[:LC_VERSION_MIN_IPHONEOS].first.version_string
        `xcrun vtool -arch arm64 -set-build-version 7 #{sdk_version} #{sdk_version} -replace -output \"#{extracted_path}\" \"#{extracted_path}\"`
        `xcrun lipo \"#{slice.binary_path}\" -replace arm64 \"#{extracted_path}\" -output \"#{slice.binary_path}\"`
        extracted_path.rmtree
      end

      def gem_path(fragment)
        Pathname.new(__FILE__).dirname.join('../..').join(fragment)
      end

      def arm2sim_path
        @arm2sim_path ||= begin
          warn 'Pre-building `arm64-to-sim` with SwiftPM'
          Dir.chdir gem_path('lib/arm64-to-sim') do
            system 'xcrun swift build -c release --arch arm64 --arch x86_64'
          end
          gem_path('lib/arm64-to-sim/.build/apple/Products/Release/arm64-to-sim')
        end
      end

      def patch_arm_binary_static(slice)
        extracted_path = slice.path.join('arm64.a')
        `xcrun lipo \"#{slice.binary_path}\" -thin arm64 -output \"#{extracted_path}\"`
        extracted_path_dir = slice.path.join('arm64-objects')
        extracted_path_dir.mkdir
        `cd \"#{extracted_path_dir}\" ; ar x \"#{extracted_path}\"`
        Dir[extracted_path_dir.join('*.o')].each do |object_file|
          file = MachO::MachOFile.new(object_file)
          sdk_version = file[:LC_VERSION_MIN_IPHONEOS].first.version_string.to_i
          `\"#{arm2sim_path}\" \"#{object_file}\" \"#{sdk_version}\" \"#{sdk_version}\"`
          $stderr.printf '.'
        end
        $stderr.puts
        `cd \"#{extracted_path_dir}\" ; ar crv \"#{extracted_path}\" *.o`

        `xcrun lipo \"#{slice.binary_path}\" -replace arm64 \"#{extracted_path}\" -output \"#{slice.binary_path}\"`
        extracted_path_dir.rmtree
        extracted_path.rmtree
      end

      public

      def cleanup_unused_archs(slice)
        supported_archs = slice.supported_archs
        unsupported_archs = `xcrun lipo \"#{slice.binary_path}\" -archs`.split - supported_archs
        unsupported_archs.each do |arch|
          `xcrun lipo \"#{slice.binary_path}\" -remove \"#{arch}\" -output \"#{slice.binary_path}\"`
        end
      end
    end
  end
end
