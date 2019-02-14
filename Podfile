source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
project 'Xcode/Awful'

inhibit_all_warnings!
use_frameworks!
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'Awful' do
  pod '1PasswordExtension'
  pod 'ARChromeActivity'
  pod 'Crashlytics'
  pod 'FLAnimatedImage'
  #pod 'GRMustache.swift' # Waiting for Swift 4 support
  pod 'GRMustache.swift', :git => 'https://github.com/chrisballinger/GRMustache.swift', :branch => 'feature/swift4'
  pod 'HTMLReader'
  pod 'ImgurAnonymousAPI'
  pod 'KVOController'
  pod 'MRProgress/Overlay'
  pod 'PromiseKit'

  # Fixes a compile error; I'm happy to pin to some subsequent tagged version if that ever happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'

  # Swift 4 support that doesn't crash in KVO. Go back to main pod when it arrives there
  pod 'PullToRefresher', :git => 'https://github.com/MindSea/PullToRefresh', :branch => 'fix-simultaneous-access'

  pod 'SwiftTweaks', :git => 'https://github.com/Khan/SwiftTweaks', :branch => 'master'

  pod 'TUSafariActivity'

  target :AwfulTests do
    inherit! :search_paths
  end
end

target 'Core' do
  pod 'HTMLReader'
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

post_install do |installer|
  extension_safe_pods = %w[FLAnimatedImage HTMLReader PromiseKit]
  swift_4_pods = %w[GRMustache.swift]
  swift_4_2_pods = %w[PullToRefresher]

  installer.pods_project.targets.each do |target|
    if extension_safe_pods.include?(target.name)
      target.build_configurations.each do |config|
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      end
    end

    if swift_4_pods.include?(target.name)
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.0'
      end
    elsif swift_4_2_pods.include?(target.name)
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end
  end
end
