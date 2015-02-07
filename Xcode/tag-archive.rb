#!/usr/bin/env ruby
require 'fileutils'
require 'pathname'

ARCHIVE = Pathname.new(ARGV[0])
INFO_PLIST = ARCHIVE + "Info.plist"

def buddy(command)
  IO.popen(["/usr/libexec/PlistBuddy", "-c", command, INFO_PLIST.to_s]) { |io|
    io.read.strip
  }
end

short_version = buddy("Print :ApplicationProperties:CFBundleShortVersionString")
bundle_version = buddy("Print :ApplicationProperties:CFBundleVersion").to_i

comment = "#{short_version}-beta#{bundle_version % 100}"
buddy "Add :Comment string \"#{comment}\""

ARCHIVE_DIR = ARCHIVE.dirname
TMP_ARCHIVE = ARCHIVE_DIR + "#{ARCHIVE.basename}tmp"

# This stupidity works around the Xcode Organizer not picking up on changes. It does, however, pick up on folders disappearing and reappearing!
FileUtils.mv ARCHIVE TMP_ARCHIVE
sleep 1
FileUtils.mv TMP_ARCHIVE ARCHIVE
