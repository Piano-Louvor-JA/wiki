#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Escapes the <placeholder> angle brackets in the template documents.
#
# Why: kramdown (GFM) parses `<Observable result and acceptance criteria.>` as
# a raw HTML tag, so the placeholder text vanishes from the rendered page and
# the whole rest of the file gets swallowed into that bogus tag. This is a
# pre-existing bug on the live site, not something the redesign introduced —
# verified against https://piano-louvor-ja.github.io/wiki/SPEC_TEMPLATE.html
#
# `&#60;` / `&#62;` keep the visual `<placeholder>` while rendering as text.
# The visible wording is unchanged.
#
# Idempotent: running twice is a no-op.
#
# Usage: ruby tools/escape_placeholders.rb [--check]

require 'set'

SRC = File.expand_path('..', __dir__)
TARGETS = %w[SPEC_TEMPLATE.md PLAN_TEMPLATE.md].freeze

# <word...> where the content starts with a letter: an HTML-ish tag, not prose.
PLACEHOLDER = /<([A-Za-z][^<>\n]*)>/

CHECK_ONLY = ARGV.include?('--check')
changed = []

TARGETS.each do |file|
  path = File.join(SRC, file)
  original = File.read(path)
  escaped = original.gsub(PLACEHOLDER) do
    inner = Regexp.last_match(1)
    if inner.start_with?('#') || inner.include?('&#')
      Regexp.last_match(0) # already escaped
    else
      "&#60;#{inner}&#62;"
    end
  end

  next if escaped == original

  changed << file
  if CHECK_ONLY
    warn "não escapado: #{file}"
  else
    File.write(path, escaped)
    puts "escapado: #{file}"
  end
end

if CHECK_ONLY && changed.any?
  warn "\nFALHOU: #{changed.size} arquivo(s) com placeholders crus."
  exit 1
end

exit 0