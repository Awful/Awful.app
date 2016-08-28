source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
project 'Xcode/Awful'
inhibit_all_warnings!
use_frameworks!

# In general I don't trust library authors to adhere to semantic versioning, so always pin to a specific version or commit.

def afnetworking; pod 'AFNetworking', '2.5.2'; end
def fl_animated_image; pod 'FLAnimatedImage', '1.0.2'; end
def html_reader; pod 'HTMLReader', '0.9.6'; end

target 'Awful' do
  afnetworking
  pod 'ARChromeActivity', '1.0.6'
  fl_animated_image
  pod 'GRMustache', '7.3.2'
  html_reader
  pod 'ImgurAnonymousAPIClient', '0.3.2'
  pod 'JLRoutes', '1.5.1'
  pod 'KVOController', '1.0.3'
  pod 'MRProgress/Overlay', '0.8.0'
  # Fixes a compile error; I'm happy to pin to some subsequent tagged version if that ever happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  pod 'PullToRefresher', '1.4.0'
  pod 'TUSafariActivity', '1.0.4'
  pod 'WebViewJavascriptBridge', '4.1.4'
end

target 'Core' do
  afnetworking
  html_reader
  
  target 'CoreTests' do
    inherit! :search_paths
  end
end

# FLAnimatedImage is used by both Awful and Smilies targets, but CocoaPods doesn't have a good story for dealing with that. Instead we'll compile it in Smilies and leave Awful's dependency implicit.
target :Smilies do
  fl_animated_image
  html_reader
  
  target :SmiliesTests do
    inherit! :search_paths
  end
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
