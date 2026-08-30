#!/usr/bin/env ruby
# Adds the AwfulUITests UI-testing target to Awful.xcodeproj.
#
# Run once from the repo root: `ruby Scripts/add-uitest-target.rb`
# Kept in the repo so the pbxproj change is reproducible and reviewable
# rather than hand-edited. Safe to re-run: exits if the target exists.
#
# Prints the new target's UUID, which Config/UITests.xctestplan references.

require 'xcodeproj'

project_path = File.expand_path('../Awful.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'AwfulUITests' }
  existing = project.targets.find { |t| t.name == 'AwfulUITests' }
  puts "AwfulUITests already exists (uuid #{existing.uuid}); nothing to do"
  exit 0
end

app_target = project.targets.find { |t| t.name == 'Awful' }
abort 'no Awful target?' unless app_target

target = project.new_target(:ui_test_bundle, 'AwfulUITests', :ios, '15.0')
target.add_dependency(app_target)

target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_NAME'] = 'AwfulUITests'
  settings['TEST_TARGET_NAME'] = 'Awful'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.awfulapp.Awful.UITests'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

group = project.main_group.new_group('UITests', 'App/UITests')
source = group.new_file('SidebarAlignmentTests.swift')
target.add_file_references([source])

project.save
puts "created AwfulUITests, uuid #{target.uuid}"
