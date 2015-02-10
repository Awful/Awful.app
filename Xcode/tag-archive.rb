#!/usr/bin/env ruby
require 'fileutils'
require 'pathname'

ARCHIVE = Pathname.new(ENV['ARCHIVE_PRODUCTS_PATH']).dirname
INFO_PLIST = ARCHIVE + "Info.plist"

def buddy(command)
  IO.popen(["/usr/libexec/PlistBuddy", "-c", command, INFO_PLIST.to_s]) do |io|
    io.read.strip
  end
end

short_version = buddy("Print :ApplicationProperties:CFBundleShortVersionString").strip
bundle_version = buddy("Print :ApplicationProperties:CFBundleVersion").to_i

comment = "#{short_version}-beta#{bundle_version % 100}"
buddy "Add :Comment string \"#{comment}\""

TMP_ARCHIVE = ARCHIVE.dirname + "#{ARCHIVE.basename}tmp"

# This stupidity works around the Xcode Organizer not picking up on changes. It does, however, pick up on folders disappearing and reappearing!
FileUtils.mv(ARCHIVE, TMP_ARCHIVE)
sleep 1
FileUtils.mv(TMP_ARCHIVE, ARCHIVE)
