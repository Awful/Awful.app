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

# Compile all third-party licenses into a single HTML file for inclusion in
# Awful. This file is displayed verbatim within the app when a button on the
# Settings screen is tapped.
licenses = "Resources/licenses.html"

(Dir["Vendor/**/LICEN[CS]E*.*"] + Dir["Vendor/*.h"]).each do |license|
  file licenses => license
end

# Include Rakefile as prerequisite, for when we change the template.
file licenses => __FILE__

file licenses do |t|
  licenses = {}
  headers = t.prerequisites.select { |p| p.match(/\.h$/) }
  standalone = t.prerequisites.select { |p| p.match(/LICEN[CS]E/) }
  standalone.each do |license_path|
    project = license_path.split(File::SEPARATOR)[1]
    File.open(license_path) do |license|
      licenses[project] = "#{project}\n" + license.read
    end
  end
  
  headers.each do |header_path|
    project = File.basename(header_path, ".h")
    File.open(header_path) do |f|
      lines = []
      f.each do |line|
        break if line[0, 2] != "//"
        lines << line[2..-1].strip
      end
      lines = lines[4...-1]
      lines.insert(0, project)
      licenses[project] = lines.join("\n")
    end
  end
  
  File.open("Resources/licenses.html", "w") do |out|
    projects = licenses.keys.sort { |a, b| a.downcase <=> b.downcase || a <=> b }
    # DATA doesn't work in Rakefiles :-(
    template = File.open(__FILE__).read.split(/^__END__\s*/, 2).last
    html = ERB.new(template, 0, "%<>")
    out << html.result(binding)
  end
end

desc "Compile third-party code licenses"
task :licenses => licenses

__END__
<!doctype html>
<meta charset=utf-8>
<style>
* { font-family: Helvetica, sans-serif; }
a { text-decoration: none; }
ul { margin: 0; padding: 0; }
ul > li {
  line-height: 1.5em;
  display: inline;
}
pre { white-space: pre-wrap; }
</style>

<ul>
% projects.each do |project|
  <li> <a href="#<%= project %>"><%= project %></a>
% end
</ul>

% projects.each do |project|
<section id="<%= project %>">
  <h1><%= project %></h1>
  <pre><%= licenses[project] %></pre>
</section>
% end
