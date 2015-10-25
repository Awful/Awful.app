#!/usr/bin/env ruby
require 'pathname'
Dir.chdir((Pathname.new(__FILE__).dirname + "../App").to_s)

def ensure_git_clean()
  if !`git status --porcelain`.empty?
    puts "Commit or stash your changes first."
    exit false
  end
end

def buddy(command, file="Info.plist")
  IO.popen(["/usr/libexec/PlistBuddy", "-c", command, file]) { |io|
    io.read.strip
  }
end

def old_version()
  buddy("Print :CFBundleVersion").to_i
end

def set_version(new_version)
  ensure_git_clean()
  
  from_version = old_version
  new_minor = (new_version / 100) % 100
  new_major = new_version / 10000
  short_version = "#{new_major}.#{new_minor}"
  
  ["Info.plist", "../Smilies/Keyboard/Info.plist"].each do |plist|
    buddy("Set :CFBundleShortVersionString #{short_version}", plist)
    buddy("Set :CFBundleVersion #{new_version}", plist)
  end
  
  `git commit -am "Bump bundle version to #{short_version} (#{new_version})."`
  
  beta = new_version % 100
  tag = "#{short_version}-beta#{beta}"
  message = "Awful #{short_version} beta #{beta}"
  `git tag -a "#{tag}" -m "#{message}"`
  puts "Committed CFBundleVersion change from #{from_version} to #{new_version} and git-tagged #{tag}"
end

case (ARGV[0] || "help").downcase
when "beta"
  new_version = old_version + 1
  set_version(new_version)
  
when "minor"
  new_version = ((old_version / 100) + 1) * 100
  set_version(new_version)
  
else
  puts <<-END

Usage: version-bump.rb COMMAND

  Change the Awful.app version.

Commands:
    beta   Increase the bundle version by one, commit, then git-tag a new beta.
    minor  Increase the bundle version to the next minor version (e.g. 30402 -> 30500), commit, then git-tag a new beta.

  END
end
