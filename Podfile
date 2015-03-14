source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
xcodeproj 'Xcode/Awful'
link_with 'Awful'
inhibit_all_warnings!
use_frameworks!

# In general I don't trust library authors to adhere to semantic versioning, so always pin to a specific version or commit.

def install(*args)
  pod 'AFNetworking', '2.5.1' if args.include? :networking
  pod 'FLAnimatedImage', '1.0.2' if args.include? :gifs
  pod 'HTMLReader', '0.6.1' if args.include? :scraping
end

target :Awful do
  install :gifs, :networking, :scraping
  pod '1PasswordExtension', '1.1.2'
  pod 'ARChromeActivity', '1.0.4'
  pod 'GRMustache', '7.3.0'
  pod 'ImgurAnonymousAPIClient', '0.3.1'
  pod 'JLRoutes', '1.5.1'
  pod 'KVOController', '1.0.3'
  pod 'MRProgress/Overlay', '0.8.0'
  # This commit fixes a compile error in PSMenuItem; I'm happy to pin to some subsequent tagged version if that happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  pod 'SVPullToRefresh', :head
  pod 'TUSafariActivity', '1.0.2'
  pod 'WebViewJavascriptBridge', '4.1.4'
  pod 'YABrowserViewController', '0.1.1'
end

target :Core do
  install :networking, :scraping
end

target :CoreTests do
  install :scraping
end

target :Smilies do
  install :gifs, :scraping
end

target :SmiliesTests do
  install :scraping
end

target :SmilieExtractor do
  install :scraping
end
