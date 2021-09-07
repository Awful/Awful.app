source 'https://cdn.cocoapods.org/'
platform :ios, '9.0'
project 'Xcode/Awful'

use_frameworks!
inhibit_all_warnings!
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

install! 'cocoapods', :generate_multiple_pod_projects => true

target 'Awful' do
  pod 'PullToRefresher', '3.2' # 3.3 breaks custom refresher views

  target :AwfulTests
end

post_install do |installer|
  swift_4_2_pods = %w[PullToRefresher]

  installer.pod_target_subprojects.each do |subproj|
    if swift_4_2_pods.include?(subproj.project_name.to_s)
      subproj.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end
  end

  deployment_target = installer.pods_project.build_configurations.first.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
  installer.pod_target_subprojects.each do |subproj|
    subproj.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
    end
    subproj.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      end
    end
  end
end
