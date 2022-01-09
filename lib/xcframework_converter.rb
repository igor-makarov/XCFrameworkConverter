# frozen_string_literal: true

require_relative 'xcframework_converter/creation'
require_relative 'xcframework_converter/patching'
require_relative 'xcframework_converter/version'

require 'cocoapods'
require 'cocoapods/xcode/xcframework'
require 'fileutils'
require 'xcodeproj'

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

# Converts a framework (static or dynamic) to XCFrameworks, adding an arm64 simulator patch.
# For more info:
# static libs: https://bogo.wtf/arm64-to-sim.html
# dylibs: https://bogo.wtf/arm64-to-sim-dylibs.html
module XCFrameworkConverter
  class << self
    def convert_frameworks_to_xcframeworks!(installer)
      installer.analysis_result.specifications.each do |spec|
        next if spec.source && spec.local?

        pod_path = installer.sandbox.pod_dir(Pod::Specification.root_name(spec.name))

        xcframeworks_to_patch = spec.available_platforms.map do |platform|
          consumer = Pod::Specification::Consumer.new(spec, platform)
          consumer.vendored_frameworks.select { |f| File.extname(f) == '.xcframework' }
                  .map { |f| pod_path.join(f) }
        end.flatten.uniq

        patch_xcframeworks_if_needed(spec, xcframeworks_to_patch)

        frameworks_to_convert = spec.available_platforms.map do |platform|
          consumer = Pod::Specification::Consumer.new(spec, platform)
          before_rename = consumer.vendored_frameworks.select { |f| File.extname(f) == '.framework' }
          next [] if before_rename.empty?

          after_rename = before_rename.map { |f| Pathname.new(f).sub_ext('.xcframework').to_s }
          proxy = Pod::Specification::DSL::PlatformProxy.new(spec, platform.symbolic_name)
          proxy.vendored_frameworks = consumer.vendored_frameworks - before_rename + after_rename
          before_rename.map { |f| pod_path.join(f) }
        end.flatten.uniq

        convert_xcframeworks_if_present(spec, frameworks_to_convert)
      end
    end

    def convert_xcframeworks_if_present(spec, frameworks_to_convert)
      frameworks_to_convert.each do |path|
        convert_framework_to_xcframework(path) if Dir.exist?(path)
      end
      remove_troublesome_xcconfig_items(spec) unless frameworks_to_convert.empty?
    end

    def patch_xcframeworks_if_needed(spec, xcframeworks)
      patched = xcframeworks.map do |path|
        next nil unless Dir.exist?(path)

        patch_xcframework(path)
      end.compact
      remove_troublesome_xcconfig_items(spec) unless patched.empty?
    end

    def remove_troublesome_xcconfig_items(spec)
      # some pods put these as a way to NOT support arm64 sim
      # may stop working if a pod decides to put these in a platform proxy
      spec.attributes_hash['pod_target_xcconfig']&.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      spec.attributes_hash['user_target_xcconfig']&.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      spec.attributes_hash['pod_target_xcconfig']&.delete('VALID_ARCHS[sdk=iphonesimulator*]')
      spec.attributes_hash['user_target_xcconfig']&.delete('VALID_ARCHS[sdk=iphonesimulator*]')
    end
  end
end
