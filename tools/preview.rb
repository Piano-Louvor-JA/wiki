#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Local preview renderer for the PIANO wiki.
#
# NOT shipped to GitHub — GitHub Pages renders this with its own Jekyll 3.10
# (kramdown + Liquid + jekyll-seo-tag). This script reuses the same two engines
# so the layout/CSS can be inspected in a browser before pushing.
#
# Usage:  ruby tools/preview.rb <out_dir>

require 'kramdown'
require 'kramdown-parser-gfm'
require 'liquid'
require 'fileutils'

SRC = File.expand_path('..', __dir__)
OUT = ARGV[0] or abort('usage: preview.rb <out_dir>')
BASE = '/wiki' # mirrors the GitHub Pages project-path prefix
ORIGIN = 'https://piano-louvor-ja.github.io'

# Language prefix => locale. English lives at the root (the canonical URL);
# every other language lives under /<prefix>/.
LANGUAGES = {
  ''    => { lang: 'en',    locale: 'en_US', label: 'English' },
  'pt/' => { lang: 'pt-BR', locale: 'pt_BR', label: 'Português' }
}.freeze

DOCS = {
  'index'           => { layout: 'home',    title: 'PIANO Developer Wiki' },
  'README'          => { layout: 'default', title: 'Piano LouvorJA — Wiki' },
  'GETTING_STARTED' => { layout: 'default', title: 'Getting started' },
  'ARCHITECTURE'    => { layout: 'default', title: 'Architecture' },
  'CONTRIBUTING'    => { layout: 'default', title: 'Contributing' },
  'GOVERNANCE'      => { layout: 'default', title: 'Governance' },
  'FAQ'             => { layout: 'default', title: 'FAQ' },
  'AGENTS'          => { layout: 'default', title: 'Public agent guide' },
  'AGENT_SETUP'     => { layout: 'default', title: 'Setup for coding agents' },
  'SPEC_TEMPLATE'   => { layout: 'default', title: 'Specification template' },
  'PLAN_TEMPLATE'   => { layout: 'default', title: 'Implementation plan template' }
}.freeze

# Per-language overrides. A document missing from a language set is simply not
# rendered for that language — the language switcher only offers what exists.
# Discovered from disk so a new translation needs no edit here: adding
# pt/FOO.md is enough to publish it.
def discover(prefix)
  dir = prefix.empty? ? SRC : File.join(SRC, prefix)
  return {} unless Dir.exist?(dir)

  Dir[File.join(dir, '*.md')].each_with_object({}) do |path, acc|
    slug = File.basename(path, '.md')
    layout = slug == 'index' ? 'home' : 'default'
    acc[slug] = { layout: layout, title: slug }
  end
end

# The English root has curated titles in DOCS; translated pages carry their own
# in front matter, and the slug is only a fallback.
PAGES = LANGUAGES.keys.each_with_object({}) do |prefix, acc|
  acc[prefix] = prefix.empty? ? DOCS : discover(prefix)
end.freeze

# Stand-in for jekyll-seo-tag: the real plugin injects this on Pages.
# Registered as a Liquid::Tag so `{% seo %}` parses like the plugin's own tag.
class SeoTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super
    @markup = markup
  end

  def render(context)
    page = context['page']
    title = page['title'] || 'PIANO Developer Wiki'
    description = page['description'] || context['site']['description'].to_s
    lang = page['lang'] || 'en'
    locale = (page['locale'] || 'en_US').tr('-', '_')
    url = page['url'] || 'https://piano-louvor-ja.github.io/wiki/'
    safe = ->(s) { s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;') }
    <<~HTML
      <title>#{safe.call(title)} | PIANO Developer Wiki</title>
      <meta name="generator" content="Jekyll v3.10.0" />
      <meta name="description" content="#{safe.call(description)}" />
      <link rel="canonical" href="#{safe.call(url)}" />
      <meta property="og:title" content="#{safe.call(title)}" />
      <meta property="og:description" content="#{safe.call(description)}" />
      <meta property="og:type" content="website" />
      <meta property="og:url" content="#{safe.call(url)}" />
      <meta property="og:site_name" content="PIANO Developer Wiki" />
      <meta property="og:locale" content="#{safe.call(locale)}" />
      <meta property="og:image" content="https://piano-louvor-ja.github.io/wiki/assets/og-cover.png" />
      <meta property="og:image:width" content="1200" />
      <meta property="og:image:height" content="630" />
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content="#{safe.call(title)}" />
      <meta name="twitter:description" content="#{safe.call(description)}" />
      <meta name="twitter:image" content="https://piano-louvor-ja.github.io/wiki/assets/og-cover.png" />
      <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"TechArticle","headline":"#{title}","url":"#{url}","inLanguage":"#{lang}","image":"https://piano-louvor-ja.github.io/wiki/assets/og-cover.png","publisher":{"@type":"Organization","name":"Piano LouvorJA","url":"https://pianolouvorja.com.br"},"isPartOf":{"@type":"WebSite","name":"PIANO Developer Wiki","url":"https://piano-louvor-ja.github.io/wiki/"}}
      </script>
    HTML
  end
end

Liquid::Template.register_tag('seo', SeoTag)

def render_layout(name, assigns, content)
  tpl = File.read(File.join(SRC, '_layouts', "#{name}.html"))
  Liquid::Template.parse(tpl, error_mode: :strict).render(assigns.merge('content' => content))
end

FileUtils.rm_rf(OUT)
FileUtils.mkdir_p(OUT)

# Copy static assets with the /wiki prefix so relative_url paths resolve.
FileUtils.cp_r(File.join(SRC, 'assets'), File.join(OUT, 'assets'))

# --- index.md: the home layout owns the <h1>, so drop the duplicate ----------
index_raw = File.read(File.join(SRC, 'index.md'))
index_body = index_raw.sub(/\A#\s+PIANO Developer Wiki\s*\n+/, '')

errors = []

# Parse the YAML-ish front matter a translated page needs (only `lang`,
# `locale` and `title` — enough for this site, and it avoids a YAML dependency).
# Front matter is the block between the first two `---` lines. Splitting on a
# bare /^---$/ also matches the opening marker, so the indexes have to account
# for the leading empty field.
def split_front_matter(raw)
  return [nil, raw] unless raw.start_with?("---")

  lines = raw.lines
  close = nil
  lines.each_with_index do |line, i|
    next if i.zero?
    if line.rstrip == '---'
      close = i
      break
    end
  end
  return [nil, raw] unless close

  [lines[1...close].join, lines[(close + 1)..].to_a.join]
end

def front_matter(raw)
  block, = split_front_matter(raw)
  return {} unless block

  block.each_line.with_object({}) do |line, acc|
    k, v = line.split(':', 2)
    next unless k && v
    acc[k.strip] = v.strip.sub(/\A["']/, '').sub(/["']\z/, '')
  end
end

def strip_front_matter(raw)
  _, body = split_front_matter(raw)
  body
end

rendered = []

PAGES.each do |prefix, pages|
  lang = LANGUAGES[prefix]

  pages.each do |slug, meta|
    md_path = File.join(SRC, prefix.empty? ? '' : prefix, "#{slug}.md")
    unless File.exist?(md_path)
      errors << "#{prefix}#{slug}: fonte ausente (#{md_path})"
      next
    end

    raw = File.read(md_path)
    fm = front_matter(raw)
    body = strip_front_matter(raw)

    # The layout renders the document <h1> — and on the home page a hero <h1> with
    # the same text — so the leading ATX heading in the markdown is dropped.
    # \A\s* because the body can start with a newline left over from front matter.
    body = body.sub(/\A\s*#\s+.+?\n+/, '')

    html = Kramdown::Document.new(body, input: 'GFM').to_html

    # Heading permalinks. Empty and decorative, kept out of the tab order —
  # same treatment anchor-js gives them on the live site.
    add_permalink = lambda do |level, id, inner|
      %(<h#{level} id="#{id}">#{inner}) +
        %(<a class="headerlink" href="##{id}" tabindex="-1" aria-hidden="true"></a></h#{level}>)
    end
    html = html.gsub(/<h2 id="([^"]+)">(.*?)<\/h2>/m) { add_permalink[2, Regexp.last_match(1), Regexp.last_match(2)] }
    html = html.gsub(/<h3 id="([^"]+)">(.*?)<\/h3>/m) { add_permalink[3, Regexp.last_match(1), Regexp.last_match(2)] }

    page_url = "#{ORIGIN}#{BASE}/#{prefix}#{slug == 'index' ? '' : "#{slug}.html"}"

    assigns = {
      'site' => {
        'title' => 'PIANO Developer Wiki',
        'lang' => lang[:lang],
        'locale' => lang[:locale],
        'description' => 'Onboarding público + docs de contribuidor para o ecossistema Piano-Louvor-JA'
      },
      'page' => {
        'title' => fm['title'] || meta[:title],
        'lang' => fm['lang'] || lang[:lang],
        'locale' => fm['locale'] || lang[:locale],
        'url' => page_url
      }
    }

    html_out = render_layout(meta[:layout], assigns, html).gsub('"/', "\"#{BASE}/")

    path = File.join(OUT, prefix, slug == 'index' ? 'index.html' : "#{slug}.html")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, html_out)

    label = "#{prefix}#{slug}"
    rendered << { slug: label, prefix: prefix, file: slug, path: path }

    # Cheap sanity gates so a broken layout fails here, not on Pages.
    errors << "#{label}: no <html"     unless html_out.include?('<html')
    errors << "#{label}: no stylesheet" unless html_out.include?("href=\"#{BASE}/assets/css/brand.css\"")
    errors << "#{label}: no toggle"     unless html_out.include?('id="theme-toggle"')
    errors << "#{label}: no header"     unless html_out.include?('class="site-header"')
    errors << "#{label}: no logo"       unless html_out.include?("#{BASE}/assets/logo.svg")
    count = html_out.scan(/<h1[\s>]/).size
    errors << "#{label}: expected 1 <h1>, found #{count}" unless count == 1
    errors << "#{label}: Liquid leak" if html_out.include?('{{') || html_out.include?('{%')
    # The page must declare the language it is actually written in, or search
    # engines and screen readers will treat Portuguese as English.
    errors << "#{label}: html lang is not #{lang[:lang]}" unless html_out.include?("lang=\"#{lang[:lang]}\"")
  end
end

# Internal link check: every internal href must resolve to a built file.
# /wiki/* maps to the preview root; assets keep their real relative layout.
rendered.each do |page|
  File.read(page[:path]).scan(/href="([^"]+)"/).flatten.each do |href|
    next unless href.start_with?("#{BASE}/")
    # Assets are validated by the dedicated check below.
    next if href.include?('/assets/')
    target = href.sub("#{BASE}/", '').split('#').first.to_s.split('?').first.to_s
    next if target.empty?
    # A directory URL (/pt/) is served as its index.html, like Pages does.
    expected = if target.end_with?('.html')
                 File.join(OUT, target)
               else
                 File.join(OUT, target, 'index.html')
               end
    unless File.exist?(expected)
      errors << "#{page[:slug]}: broken link #{href}"
    end
  end
end

# Assets referenced by the layout must exist on disk.
rendered.each do |page|
  File.read(page[:path]).scan(/(?:href|src)="(#{Regexp.escape(BASE)}\/assets\/[^"]+)"/).flatten.uniq.each do |href|
    asset = href.sub("#{BASE}/", '')
    errors << "#{page[:slug]}: missing asset #{asset}" unless File.exist?(File.join(OUT, asset))
  end
end

if errors.empty?
  puts "OK — #{rendered.size} páginas renderizadas em #{OUT} (#{PAGES.size} idiomas)"
  exit 0
else
  warn "FALHOU (#{errors.size}):"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
