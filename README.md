# XCFrameworkConverter
[![Gem](https://img.shields.io/gem/v/xcframework_converter.svg)](https://rubygems.org/gems/xcframework_converter)
[![Twitter: @igormaka](https://img.shields.io/badge/contact-@igormaka-blue.svg?style=flat)](https://twitter.com/igormaka)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](./LICENSE.txt)

This little gem allows to take an ancient `.framework` (static or dynamic), and turn it into a fully fledged `.xcframework`. In addition, it will patch the binary to add an `arm64` simulator slice. There's also a CocoaPods patcher that allows this to operate without customizing the `Podfile` dependencies.
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'xcframework_converter'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install xcframework_converter

## Usage

### CLI

```bash
xcfconvert <path/to/Framework.framework>
```

### CocoaPods
In your podfile:
```ruby
require 'xcframework_converter'
# Define your dependencies...
pre_install do |installer|
  XCFrameworkConverter.convert_frameworks_to_xcframeworks!(installer)
end
```

This will achieve two things:

1. When a pod with vendored `.framework`-s is added, they will be converted to `.xcframework`-s.
2. Upon each `pod install`, the corresponding pod specifications will be patched so that the project will consume the `.xcframework`-s correctly.

## Is it reliable?
Sort of. The software is provided as is, with no guarantees of correctnes. It's meant to be a workaround. For the correct solution, ask the framework vendor for an update. However, PRs are welcome.

## How does it work?
An XCFramework is basically a bundle of folders.

The tool will create the folder and its subfolders, write the correct `Info.plist`, and clean up the relevant fat binary files so that they contain only the relevant architectures.

Additionally, the tool will create a new, patched `arm64` binary for the iOS Simulator. For that, it uses the code and knowledge of [Bogo Giertler](https://github.com/bogo). The binary patching code is embedded in the gem. For more info, check Bogo's blog for the posts on how to patch a [static library](https://bogo.wtf/arm64-to-sim.html) and a [dynamic library](https://bogo.wtf/arm64-to-sim-dylibs.html).

## Contributing

Pull requests are welcome on GitHub at https://github.com/igor-makarov/XCFrameworkConverter. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/igor-makarov/XCFrameworkConverter/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the XcframeworkConverter project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/igor-makarov/XCFrameworkConverter/blob/master/CODE_OF_CONDUCT.md).
