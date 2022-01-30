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

        patch_xcframeworks_if_needed(xcframeworks_to_patch)

        frameworks_to_convert = spec.available_platforms.map do |platform|
          consumer = Pod::Specification::Consumer.new(spec, platform)
          before_rename = consumer.vendored_frameworks.select { |f| File.extname(f) == '.framework' }
          next [] if before_rename.empty?

          after_rename = before_rename.map { |f| Pathname.new(f).sub_ext('.xcframework').to_s }
          proxy = Pod::Specification::DSL::PlatformProxy.new(spec, platform.symbolic_name)
          proxy.vendored_frameworks = consumer.vendored_frameworks - before_rename + after_rename
          before_rename.map { |f| pod_path.join(f) }
        end.flatten.uniq

        convert_xcframeworks_if_present(frameworks_to_convert)

        remember_spec_as_patched(spec) unless frameworks_to_convert.empty?

        remove_troublesome_xcconfig_items(spec)
      end

      warn "Specs with patched XCFrameworks: #{@patched_specs.sort.join(', ')}"
    end

    def convert_xcframeworks_if_present(frameworks_to_convert)
      frameworks_to_convert.each do |path|
        convert_framework_to_xcframework(path) if Dir.exist?(path)
      end
    end

    def patch_xcframeworks_if_needed(xcframeworks)
      xcframeworks.each do |path|
        patch_xcframework(path) if Dir.exist?(path)
      end
    end

    def remove_troublesome_xcconfig_items(spec)
      xcconfigs = %w[
        pod_target_xcconfig
        user_target_xcconfig
      ].map { |key| spec.attributes_hash[key] }.compact

      xcconfigs.each do |xcconfig|
        # some pods put these as a way to NOT support arm64 sim
        # may stop working if a pod decides to put these in a platform proxy
        excluded_arm = xcconfig['EXCLUDED_ARCHS[sdk=iphonesimulator*]']&.include?('arm64')
        not_inlcuded_arm = xcconfig['VALID_ARCHS[sdk=iphonesimulator*]'] && !xcconfig['VALID_ARCHS[sdk=iphonesimulator*]'].include?('arm64')

        remember_spec_as_patched(spec) if excluded_arm || not_inlcuded_arm

        xcconfig.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
        xcconfig.delete('VALID_ARCHS[sdk=iphonesimulator*]')
      end
    end

    def remember_spec_as_patched(spec)
      @patched_specs ||= Set.new
      @patched_specs << spec.root.name
    end
  end
end
