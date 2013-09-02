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
