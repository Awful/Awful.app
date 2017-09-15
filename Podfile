source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
project 'Xcode/Awful'
inhibit_all_warnings!
use_frameworks!
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'Awful' do
  pod 'AFNetworking', '~> 2.0'
  pod 'ARChromeActivity'
  pod 'Crashlytics'
  pod 'FLAnimatedImage'
  pod 'GRMustache'
  pod 'GRMustache.swift'
  pod 'HTMLReader'
  pod 'ImgurAnonymousAPIClient'
  pod 'JLRoutes'
  pod 'KVOController'
  pod 'MRProgress/Overlay'
  
  # Fixes a compile error; I'm happy to pin to some subsequent tagged version if that ever happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  
  # swift 3 support, go back to main pod when it arrives there
  pod 'PullToRefresher', :git => 'https://github.com/marlontojal/PullToRefresh', :commit => 'f740b9e3e7a7497f81b2e2ef5acea7d15d4d91b0'
  
  pod 'TUSafariActivity'
  pod 'WebViewJavascriptBridge'
end

target 'Core' do
  pod 'HTMLReader'
  pod 'OMGHTTPURLRQ'
  pod 'PromiseKit'
  
  target 'CoreTests' do
    inherit! :search_paths
  end
end

target :Smilies do
  pod 'FLAnimatedImage'
  pod 'HTMLReader'
  
  target :SmiliesTests do
    inherit! :search_paths
  end
end

target :SmilieExtractor do
  pod 'FLAnimatedImage'
  pod 'HTMLReader'
end
