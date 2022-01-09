
# frozen_string_literal: true

require 'cocoapods'
require 'cocoapods/xcode/xcframework'

module Pod
  module Xcode
    # open XCFramework
    class XCFramework
      def self.open_xcframework(xcframework_path)
        if instance_method(:initialize).arity == 2
          new(File.basename(xcframework_path), xcframework_path.realpath)
        else
          new(xcframework_path.realpath)
        end
      end
    end
  end
end