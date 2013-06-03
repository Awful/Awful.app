require 'erb'
require 'uri'

def urlescape(f)
  URI.escape(f, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

desc "Compile list of thread tags available from GitHub Pages"
task :tags do
  tags = %w[Resources Thread\ Tags]
  paths = Dir[File.join(tags + ["*.png"])]
  File.open("tags.txt", "w") do |out|
    out << tags.map { |t| urlescape(t) }.join("/") << "\n"
    out << paths.map { |n| File.basename(n) }.join("\n")
  end
end

desc "Sort thread tags alphabetically in Xcode"
task :sort_tags do
  pbxproj = "Awful.xcodeproj/project.pbxproj"
  project = File.readlines(pbxproj)
  start_group = nil
  start_children = nil
  end_children = nil
  project.each_with_index do |line, i|
    if line =~ /8CCD527B15B783FC00E5893B.*\{/ # Thread Tags group
      start_group = i
    elsif start_group and !start_children and line =~ /[0-9A-Fa-b]{24}/
      start_children = i
    elsif start_children and line =~ /;/
      end_children = i
      break
    end
  end
  return unless start_group and start_children and end_children
  tags = project[start_children...end_children]
  project[start_children...end_children] = tags.sort_by { |t|
    path = t.match(/\/\* (.*) \*\/,?$/)[1]
    path.downcase + path
  }
  File.open(pbxproj, "w") do |out|
    project.each { |line| out << line }
  end
end

desc "Include Crashlytics API key"
task :crashlytics do
  api_key = begin
    File.read('crashlytics-api-key').strip
  rescue
    nil
  end
  File.open("Source/Main/AwfulCrashlytics.h", "w") do |h|
    h << %Q|#define CRASHLYTICS_API_KEY @"#{api_key}"| if api_key
  end
end
