#!/usr/bin/env ruby
require 'pathname'

REGEX = %r{\A
  // \s*
  (// .* \n)
  // \s* (?:Awful|\S*Tests\S*) \s*
  (// \s*)
  // .* \n
  // .* (\d{4}) .* \n
  // \s*
}x

BOILERPLATE = "Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app"

ROOT = (Pathname.new(__FILE__).dirname + "../").realpath

%w[Source Tests].each do |subpath|
  Dir.chdir(ROOT + subpath)
  `ag -il "copyright.*all rights reserved"`.split("\n").each do |path|
    before = File.read(path)
    after = before.sub(REGEX, "\\1\\2//  Copyright \\3 #{BOILERPLATE}\n\n")
    File.write(path, after)
  end
end
