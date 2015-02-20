source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
xcodeproj 'Xcode/Awful', 'Awful Beta' => :release, 'Awful App Store' => :release
link_with 'Awful'
inhibit_all_warnings!

target :Awful do
  pod 'ARChromeActivity', '1.0.4'
  pod 'GRMustache', '7.3.0'
  pod 'JLRoutes', '1.5.1'
  pod 'KVOController', '1.0.3'
  pod 'MRProgress/Overlay', '0.8.0'
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  pod 'SVPullToRefresh', :head
  pod 'TUSafariActivity', '1.0.2'
  pod 'WebViewJavascriptBridge', '4.1.4'
  pod 'YABrowserViewController', '0.1.1'
end

# Until we get proper CocoaPods framework support, Smilies.framework will be our home for these pods. Other targets should link against Smilies.framework and expand their Header Search Paths as needed.
target :Smilies do
  pod 'FLAnimatedImage', '1.0.2'
end
