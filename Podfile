source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
xcodeproj 'Xcode/Awful'
link_with 'Awful'
inhibit_all_warnings!

# In general I don't trust library authors to adhere to semantic versioning, so always pin to a specific version or commit.

target :Awful do
  pod 'ARChromeActivity', '1.0.4'
  pod 'GRMustache', '7.3.0'
  pod 'JLRoutes', '1.5.1'
  pod 'KVOController', '1.0.3'
  pod 'MRProgress/Overlay', '0.8.0'
  # Fixes a compile error; I'm happy to pin to some subsequent tagged version if that ever happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  pod 'SVPullToRefresh', :head
  pod 'TUSafariActivity', '1.0.2'
  pod 'WebViewJavascriptBridge', '4.1.4'
  pod 'YABrowserViewController', '0.1.1'
end

# FLAnimatedImage is used by both Awful and Smilies targets, but CocoaPods doesn't have a good story for dealing with that. Instead we'll compile it in Smilies and leave Awful's dependency implicit.
target :Smilies do
  pod 'FLAnimatedImage', '1.0.2'
end
