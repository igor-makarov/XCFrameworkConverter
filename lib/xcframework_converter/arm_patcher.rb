# frozen_string_literal: true

require 'cocoapods'
require 'cocoapods/xcode/xcframework'
require 'digest/md5'
require 'fileutils'
require 'shellwords'
require 'xcodeproj'

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

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

        minos_version, sdk_version = version_strings(extracted_path).map(&:to_i)
        `xcrun vtool -arch arm64 -set-build-version 7 #{minos_version} #{sdk_version} -replace -output \"#{extracted_path}\" \"#{extracted_path}\"`
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
        if macho_file_type(extracted_path) == :object
          patch_object_file(extracted_path)
        else
          object_files = `ar t \"#{extracted_path}\"`.split("\n").map(&:chomp).sort
                                                     .select { |o| o.end_with?('.o') }
                                                     .group_by(&:itself).transform_values(&:count)
          processed_files = []
          index = 0
          while object_files.any?
            object_files.keys.each do |object_file|
              file_shard = Digest::MD5.hexdigest(object_file).to_s[0..2]
              file_dir = extracted_path_dir.join("#{index}-#{file_shard}")
              file_path = file_dir.join(object_file)
              file_dir.mkdir unless file_dir.exist?
              `ar p \"#{extracted_path}\" \"#{object_file}\" > \"#{file_path}\"`
              patch_object_file(file_path)
              $stderr.printf '.'
              processed_files << file_path
            end
            `ar d \"#{extracted_path}\" #{object_files.keys.map(&:shellescape).join(' ')}`
            $stderr.printf '#'
            object_files.reject! { |_, count| count <= index + 1 }
            index += 1
          end
          $stderr.puts
          `cd \"#{extracted_path_dir}\" ; ar cqv \"#{extracted_path}\" #{processed_files.map(&:shellescape).join(' ')}`
        end
        `xcrun lipo \"#{slice.binary_path}\" -replace arm64 \"#{extracted_path}\" -output \"#{slice.binary_path}\"`
        extracted_path_dir.rmtree
        extracted_path.rmtree
      end

      def macho_file_type(file_path)
        MachO.open(file_path).filetype
      rescue MachO::MagicError
        nil
      end

      def patch_object_file(file_path)
        minos_version, sdk_version = version_strings(file_path).map(&:to_i)
        `\"#{arm2sim_path}\" \"#{file_path}\" \"#{minos_version}\" \"#{sdk_version}\"`
      end

      def version_strings(file_path)
        macho_file = MachO::MachOFile.new(file_path)
        if (version_min_command = macho_file.load_commands.find { |c| c.is_a?(MachO::LoadCommands::VersionMinCommand) })
          return [version_min_command.version_string, version_min_command.sdk_string]
        end
        if (build_version_command = macho_file.load_commands.find { |c| c.is_a?(MachO::LoadCommands::BuildVersionCommand) })
          return [build_version_command.minos_string, build_version_command.sdk_string]
        end

        raise "Could not find version strings in #{file_path}"
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
