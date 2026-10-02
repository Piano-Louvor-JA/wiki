#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Emits one text sentinel per allowlisted page, taken from the markdown source
# itself. verify-preview.mjs asserts each sentinel survives into the built HTML,
# so "no text lost" is checked against the source of truth rather than against
# a hand-written list that could drift.
#
# Usage: ruby tools/content_sentinels.rb

require 'json'

SRC = File.expand_path('..', __dir__)

# The distinctive, hand-picked clause per page — the sentence that would
# obviously break if the layout swallowed or reflowed content.
PICK = {
  'GETTING_STARTED' => 'Remove credentials, private URLs, operational paths, customer data',
  'ARCHITECTURE'    => 'This is intentionally a high-level map, not an operations manual.',
  'CONTRIBUTING'    => 'Avoid unrelated formatting or refactoring.',
  'GOVERNANCE'      => 'Public pages may include stable concepts, contribution workflow and blank templates.',
  'FAQ'              => 'Credentials, tokens, private paths, infrastructure addresses',
  'AGENTS'          => 'When unsure whether information is public, omit it and request review.',
  'SPEC_TEMPLATE'   => 'Observable result and acceptance criteria.',
  'PLAN_TEMPLATE'   => 'safe reversal if applicable',
  'index'           => 'This site intentionally publishes only safe, reusable onboarding material.'
}.freeze

problems = []

PICK.each do |slug, needle|
  file = slug == 'index' ? 'index.md' : "#{slug}.md"
  body = File.read(File.join(SRC, file))
  problems << "#{file}: sentinela ausente da fonte (#{needle.inspect})" unless body.include?(needle)
end

# Sanity: the allowlist itself must not drift.
EXPECTED = %w[
  AGENTS.md ARCHITECTURE.md CONTRIBUTING.md FAQ.md GETTING_STARTED.md
  GOVERNANCE.md PLAN_TEMPLATE.md SPEC_TEMPLATE.md index.md
].freeze

actual = Dir[File.join(SRC, '*.md')].map { |f| File.basename(f) }.sort
problems << "allowlist divergiu: #{actual.inspect}" unless actual == EXPECTED.sort

if problems.any?
  warn 'FALHOU:'
  problems.each { |p| warn "  - #{p}" }
  exit 1
end

# Keyed by slug so the consumer can't drift out of sync with page order.
puts JSON.generate(PICK)