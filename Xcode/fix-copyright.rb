#!/usr/bin/env ruby
require 'pathname'

Dir.chdir(Pathname.new(__FILE__).dirname + "../Source")

REGEX = %r{\A
  // \s*
  (// .* \n)
  // \s* Awful \s*
  (// \s*)
  // .* \n
  // .* (\d{4}) .* \n
  // \s*
}x

BOILERPLATE = "Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app"

`ag -il "copyright.*all rights reserved"`.split("\n").each do |path|
  before = File.read(path)
  after = before.sub(REGEX, "\\1\\2//  Copyright \\3 #{BOILERPLATE}\n\n")
  File.write(path, after)
end
