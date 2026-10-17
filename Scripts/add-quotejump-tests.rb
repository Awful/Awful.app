#!/usr/bin/env ruby
# Adds the quote-jump test harness (App/Tests/QuoteJump/*.swift and its README) and the quotejump fixture pages
# (AwfulCore/Tests/AwfulCoreTests/Fixtures/quotejump-*.html) to the AwfulTests target in
# Awful.xcodeproj.
#
# Run from the repo root: `ruby Scripts/add-quotejump-tests.rb`
# Kept in the repo so the pbxproj change is reproducible and reviewable rather than hand-edited.
# Safe to re-run: files already in the target are skipped, so run it again after adding a new
# scenario file or regenerating fixtures with a new variant.

require 'xcodeproj'

repo = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(repo, 'Awful.xcodeproj'))
target = project.targets.find { |t| t.name == 'AwfulTests' } or abort 'no AwfulTests target'

tests_group = project.main_group.find_subpath('App/Tests', false) or abort 'no App/Tests group'
quote_jump_group = tests_group.find_subpath('QuoteJump', true)
quote_jump_group.set_source_tree('<group>')
quote_jump_group.set_path('QuoteJump') if quote_jump_group.path.nil?

fixtures_group = tests_group.find_subpath('QuoteJump Fixtures', true)
fixtures_group.set_source_tree('<group>')

def ensure_file(group, absolute_path)
  relative = Pathname.new(absolute_path).relative_path_from(Pathname.new(group.real_path)).to_s
  existing = group.files.find { |f| f.real_path.to_s == absolute_path }
  existing || group.new_file(relative)
end

added = []

Dir[File.join(repo, 'App/Tests/QuoteJump/*.swift')].sort.each do |path|
  ref = ensure_file(quote_jump_group, path)
  next if target.source_build_phase.files_references.include?(ref)
  target.add_file_references([ref])
  added << File.basename(path)
end

# The folder's README is in the group so it shows in Xcode, but belongs to no build phase.
readme = File.join(repo, 'App/Tests/QuoteJump/README.md')
if File.exist?(readme) && quote_jump_group.files.none? { |f| f.real_path.to_s == readme }
  ensure_file(quote_jump_group, readme)
  added << 'README.md'
end

Dir[File.join(repo, 'AwfulCore/Tests/AwfulCoreTests/Fixtures/quotejump-*.html')].sort.each do |path|
  ref = ensure_file(fixtures_group, path)
  next if target.resources_build_phase.files_references.include?(ref)
  target.resources_build_phase.add_file_reference(ref)
  added << File.basename(path)
end

project.save
puts added.empty? ? 'nothing to add' : "added: #{added.join(', ')}"
