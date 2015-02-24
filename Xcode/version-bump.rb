#!/usr/bin/env ruby
require 'pathname'
Dir.chdir((Pathname.new(__FILE__).dirname + "../App").to_s)

def ensure_git_clean()
  if !`git status --porcelain`.empty?
    puts "Commit or stash your changes first."
    exit false
  end
end

def buddy(command)
  IO.popen(["/usr/libexec/PlistBuddy", "-c", command, "Info.plist"]) { |io|
    io.read.strip
  }
end

case (ARGV[0] || "help").downcase
when "beta"
  ensure_git_clean()
  
  old_version = buddy("Print :CFBundleVersion").to_i
  new_version = old_version + 1
  buddy("Set :CFBundleVersion #{new_version}")
  
  `git commit -am "Bump bundle version to #{new_version}."`
  
  short_version = buddy("Print :CFBundleShortVersionString")
  beta = new_version % 100
  tag = "#{short_version}-beta#{beta}"
  message = "Awful #{short_version} beta #{beta}"
  `git tag -a "#{tag}" -m "#{message}"`
  puts "Committed CFBundleVersion change from #{old_version} to #{new_version} and git-tagged #{tag}"
else
  puts <<-END

Usage: version-bump.rb COMMAND

  Change the Awful.app version.

Commands:
    beta  Increase the bundle version by one, commit, then git-tag a new beta.

  END
end
