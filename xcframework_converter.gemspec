# frozen_string_literal: true

require_relative 'lib/xcframework_converter/version'

Gem::Specification.new do |spec|
  spec.name          = 'xcframework_converter'
  spec.version       = XCFrameworkConverter::VERSION
  spec.authors       = ['Igor Makarov']
  spec.email         = ['igormaka@gmail.com']

  spec.summary       = 'Convert an ancient .framework to an .xcframework.'
  spec.description   = 'Convert an ancient .framework (dynamic or static) to an .xcframework. Add an arm64 Simulator patch.'
  spec.homepage      = 'https://github.com/igor-makarov/XCFrameworkConverter'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.4.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/igor-makarov/XCFrameworkConverter'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = %w[README.md] + Dir['lib/**/*.{plist,rb,swift}']
  spec.executables   = ['xcfconvert']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'cocoapods', '>= 1.10.0', '~> 1'
  spec.add_runtime_dependency 'xcodeproj', '>= 1.20.0', '~> 1'
end
