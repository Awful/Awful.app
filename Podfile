source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
project 'Xcode/Awful'
inhibit_all_warnings!
use_frameworks!
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'Awful' do
  pod 'AFNetworking', '~> 2.0'
  pod 'ARChromeActivity', '~> 1.0.6'
  pod 'Crashlytics'
  pod 'FLAnimatedImage', '~> 1.0'
  pod 'GRMustache', '~> 7.3.2'
  pod 'HTMLReader', '~> 2.0'
  pod 'ImgurAnonymousAPIClient', '~> 0.3'
  pod 'JLRoutes', '~> 1.5'
  pod 'KVOController', '~> 1.0'
  pod 'MRProgress/Overlay', '~> 0.8.0'
  
  # Fixes a compile error; I'm happy to pin to some subsequent tagged version if that ever happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  
  # swift 3 support, go back to main pod when it arrives there
  pod 'PullToRefresher', :git => 'https://github.com/marlontojal/PullToRefresh', :commit => 'f740b9e3e7a7497f81b2e2ef5acea7d15d4d91b0'
  
  pod 'TUSafariActivity', '~> 1.0'
  pod 'WebViewJavascriptBridge', '~> 4.1'
end

target 'Core' do
  pod 'AFNetworking', '~> 2.0'
  pod 'HTMLReader', '~> 2.0'
  
  target 'CoreTests' do
      inherit! :search_paths
  end
end

target :Smilies do
  pod 'FLAnimatedImage', '~> 1.0'
  pod 'HTMLReader', '~> 2.0'
  
  target :SmiliesTests do
    inherit! :search_paths
  end
end

target :SmilieExtractor do
  pod 'FLAnimatedImage', '~> 1.0'
  pod 'HTMLReader', '~> 2.0'
end

post_install do |extension_safe_api|
  EXTENSION_SAFE_TARGETS = %w[FLAnimatedImage HTMLReader Pods-Smilies]
  extension_safe_api.pods_project.targets.each do |target|
    if EXTENSION_SAFE_TARGETS.include? target.name
      target.build_configurations.each do |config|
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      end
    end
  end
end
