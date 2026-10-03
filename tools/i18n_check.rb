#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Internationalisation gate.
#
# A translation is only useful if it stays in step with its source. Without a
# check, a page gets edited in English and the Portuguese copy silently rots —
# nothing fails, readers just get told the wrong thing.
#
# Checks:
#   1. every translated page declares `lang:` and `locale:` in its front matter
#   2. every internal link in a translated page resolves, in that language
#   3. the set of headings matches the source language (structure parity)
#   4. no translated file reintroduces content the allowlist forbids
#
# A page that has no translation is reported as a gap, not an error — partial
# language coverage is a legitimate state, a wrong one is not.
#
# Usage: ruby tools/i18n_check.rb [--strict]
#   --strict  treat a missing translation as a failure

ROOT = File.expand_path('..', __dir__)
STRICT = ARGV.include?('--strict')

# prefix => language tag
LANGUAGES = { 'pt' => 'pt-BR' }.freeze
SOURCE_LANG = 'en'

problems = []
gaps = []

def headings(md)
  md.each_line.filter_map do |line|
    m = line.match(/^(\#+)\s+(.+?)\s*$/)
    next unless m
    # Compare structure by level and position, not by wording — the wording is
    # exactly what a translation is supposed to change.
    [m[1].length, m[2].gsub(/[*_`]/, '').strip.downcase]
  end
end

# Headings that are only a translated copy of the page title carry no structural
# meaning; the layout renders the real <h1>.
def content_headings(md)
  headings(md).reject { |lvl, _| lvl == 1 }
end

def front_matter(raw)
  return {} unless raw.start_with?('---')
  body = raw.split(/^---\s*$/, 3)[1]
  return {} unless body
  body.each_line.with_object({}) do |line, acc|
    k, v = line.split(':', 2)
    next unless k && v
    acc[k.strip] = v.strip.gsub(/\A["']|["']\z/, '')
  end
end

def body_of(raw)
  raw.start_with?('---') ? (raw.split(/^---\s*$/, 3)[2].to_s) : raw
end

source_docs = Dir[File.join(ROOT, '*.md')].map { |f| File.basename(f, '.md') }.sort

LANGUAGES.each do |prefix, tag|
  dir = File.join(ROOT, prefix)
  unless Dir.exist?(dir)
    problems << "#{prefix}/: diretório ausente (idioma #{tag} declarado mas sem traduções)"
    next
  end

  translated = Dir[File.join(dir, '*.md')].map { |f| File.basename(f, '.md') }.sort

  # 1 — front matter
  translated.each do |slug|
    raw = File.read(File.join(dir, "#{slug}.md"))
    fm = front_matter(raw)

    if fm['lang'] != tag
      problems << "#{prefix}/#{slug}.md: front matter `lang:` deve ser #{tag} (encontrado #{fm['lang'].inspect})"
    end
    if fm['locale'].to_s.empty?
      problems << "#{prefix}/#{slug}.md: front matter `locale:` ausente (ex.: pt_BR)"
    elsif fm['locale'] != fm['locale'].tr('-', '_')
      problems << "#{prefix}/#{slug}.md: `locale:` deve usar underscore (pt_BR, não pt-BR)"
    end
  end

  # 2 — internal links resolve inside the same language
  translated.each do |slug|
    File.read(File.join(dir, "#{slug}.md")).scan(/\]\(([^)]+\.md)\)/).flatten.uniq.each do |href|
      target = File.basename(href, '.md')
      unless translated.include?(target)
        if translated.include?(target)
          next
        else
          problems << "#{prefix}/#{slug}.md: link relativo '#{href}' não existe em #{prefix}/"
        end
      end
    end
  end

  # 3 — structure parity with the English source
  translated.each do |slug|
    src = File.join(ROOT, "#{slug}.md")
    unless File.exist?(src)
      problems << "#{prefix}/#{slug}.md: sem original em #{slug}.md (tradução órfã)"
      next
    end

    # Compare the heading *sequence* from h2 down. The h1 is the page title and
    # the layout renders it — a translation that starts at h2 is correct, not
    # missing a section. What matters is that the content sections line up.
    src_shape = headings(body_of(File.read(src))).select { |lvl, _| lvl >= 2 }.map(&:first)
    tr_shape  = headings(body_of(File.read(File.join(dir, "#{slug}.md")))).select { |lvl, _| lvl >= 2 }.map(&:first)

    is_home = slug == 'index'

    if src_shape != tr_shape
      # The home page legitimately adds sections per language (pt links the agent
      # pages, en does not); every other page must match exactly.
      if is_home && (src_shape - tr_shape).empty?
        # translated home is a superset — acceptable
      else
        problems << "#{prefix}/#{slug}.md: estrutura de seções diverge de #{slug}.md " \
                     "(#{SOURCE_LANG}: #{src_shape.join(',')} vs #{tag}: #{tr_shape.join(',')})"
      end
    end

    # 3b — a translation must not say something the source does not. Headings
    # matching is not enough: a translated page can still leak a host, a port or
    # a personal name that the English source deliberately omits.
    src_words = body_of(File.read(src)).downcase
    tr_words  = body_of(File.read(File.join(dir, "#{slug}.md"))).downcase
    # Terms the allowlist forbids, checked against the translation body.
    %w[oracle hostinger tailscale].each do |term|
      next unless tr_words.include?(term)
      next if src_words.include?(term)
      problems << "#{prefix}/#{slug}.md: contém '#{term}', ausente no original #{SOURCE_LANG}"
    end
  end

  # 4 — report untranslated documents
  (source_docs - translated).each do |slug|
    msg = "#{slug}.md: sem tradução em #{prefix}/"
    STRICT ? problems << msg : gaps << msg
  end
end

if problems.any?
  warn "I18N FALHOU (#{problems.size}):"
  problems.each { |p| warn "  - #{p}" }
  exit 1
end

unless gaps.empty?
  warn "Cobertura parcial (#{gaps.size} documento(s) sem tradução — não é erro):"
  gaps.each { |g| warn "  ~ #{g}" }
end

puts "OK — #{LANGUAGES.keys.join(', ')}: front matter, links e estrutura conferidos."
exit 0