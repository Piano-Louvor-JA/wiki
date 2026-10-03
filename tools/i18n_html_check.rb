#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Per-language HTML gate.
#
# Checks the rendered output directly instead of driving a browser. On a memory
# constrained host, opening 24 pages in Chrome is what exhausts the swap and
# surfaces as "Target crashed" — a false failure that hides real problems. The
# generated HTML already carries everything worth asserting here; the browser
# gates in verify-preview.mjs cover rendering behaviour.
#
# Per page and per language:
#   - <html lang> declares the language the page is actually written in
#   - canonical is absolute and carries the language prefix
#   - og:locale matches the language
#   - JSON-LD present and declares inLanguage
#   - exactly one <h1>
#   - the stylesheet, the logo and the language switcher are wired
#   - no unrendered Liquid
#
# Usage: ruby tools/i18n_html_check.rb <rendered_root>
#   e.g. ruby tools/i18n_html_check.rb /tmp/wikiroot/wiki

require 'json'

ROOT = ARGV[0] or abort('usage: i18n_html_check.rb <rendered_root>')
ORIGIN = 'https://piano-louvor-ja.github.io'

# prefix => [lang, locale]
LANGS = {
  ''    => ['en', 'en_US'],
  'es/' => ['es', 'es_ES'],
  'pt/' => ['pt-BR', 'pt_BR']
}.freeze

problems = []
total = 0

LANGS.each do |prefix, (lang, locale)|
  dir = File.join(ROOT, prefix)
  pages = Dir[File.join(dir, '*.html')].sort

  if pages.empty?
    problems << "#{prefix}: nenhum HTML renderizado em #{dir}"
    next
  end

  pages.each do |file|
    total += 1
    html = File.read(file, encoding: 'utf-8')
    name = "#{prefix}#{File.basename(file)}"

    # Anchor on the <html> tag: a bare substring check matches `lang="en"` inside
    # `lang="en-US"` and would pass a page declaring the wrong language.
    html_tag = html[/<html[^>]*>/m]
    if html_tag.nil?
      problems << "#{name}: tag <html> ausente"
    elsif html_tag !~ /\blang=["']#{Regexp.escape(lang)}["']/
      declared = html_tag[/\blang=["']([^"']+)["']/, 1]
      problems << "#{name}: <html lang> é #{declared.inspect}, esperado #{lang.inspect}"
    end
    problems << "#{name}: og:locale não declara #{locale}" unless html.include?("content=\"#{locale}\"")
    problems << "#{name}: JSON-LD ausente" unless html.include?('application/ld+json')

    canonical = html[/<link rel="canonical" href="([^"]+)"/, 1]
    if canonical.nil?
      problems << "#{name}: canonical ausente"
    else
      problems << "#{name}: canonical não absoluto (#{canonical})" unless canonical.start_with?("#{ORIGIN}/wiki/")
      problems << "#{name}: canonical sem prefixo de idioma (#{canonical})" if prefix != '' && !canonical.include?("/wiki/#{prefix}")
    end

    ld = html[%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m, 1]
    if ld
      begin
        data = JSON.parse(ld)
        if data['inLanguage'] != lang
          problems << "#{name}: JSON-LD inLanguage=#{data['inLanguage'].inspect}, esperado #{lang.inspect}"
        end
      rescue JSON::ParserError => e
        problems << "#{name}: JSON-LD inválido (#{e.message})"
      end
    end

    h1 = html.scan(/<h1[\s>]/).size
    problems << "#{name}: #{h1} <h1>, esperado exatamente 1" unless h1 == 1

    problems << "#{name}: stylesheet ausente"  unless html.include?('/wiki/assets/css/brand.css')
    problems << "#{name}: logo ausente"        unless html.include?('/wiki/assets/logo.svg')
    problems << "#{name}: seletor de idioma ausente" unless html.include?('lang-switch')
    problems << "#{name}: toggle de tema ausente"    unless html.include?('id="theme-toggle"')

    if html.include?('{{') || html.include?('{%')
      problems << "#{name}: Liquid não renderizado"
    end
  end
end

# The language switcher must offer exactly the languages that actually exist.
LANGS.each_key do |prefix|
  home = File.join(ROOT, prefix, 'index.html')
  next unless File.exist?(home)
  html = File.read(home, encoding: 'utf-8')
  opts = html.scan(/class="lang-opt[^"]*"/).size
  unless opts == LANGS.size
    problems << "#{prefix}index.html: seletor com #{opts} opções, esperado #{LANGS.size}"
  end
end

if problems.any?
  warn "I18N HTML FALHOU (#{problems.size}):"
  problems.each { |p| warn "  - #{p}" }
  exit 1
end

puts "OK — #{total} páginas em #{LANGS.size} idiomas: lang, canonical, og:locale, JSON-LD, h1 e assets."
exit 0