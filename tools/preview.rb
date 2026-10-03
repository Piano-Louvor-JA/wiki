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

PAGES = {
  'index'            => { layout: 'home',    title: 'PIANO Developer Wiki' },
  'README'           => { layout: 'default', title: 'Piano LouvorJA — Wiki' },
  'GETTING_STARTED'  => { layout: 'default', title: 'Getting started' },
  'ARCHITECTURE'     => { layout: 'default', title: 'Architecture' },
  'CONTRIBUTING'     => { layout: 'default', title: 'Contributing' },
  'GOVERNANCE'       => { layout: 'default', title: 'Governance' },
  'FAQ'              => { layout: 'default', title: 'FAQ' },
  'AGENTS'           => { layout: 'default', title: 'Public agent guide' },
  'AGENT_SETUP'      => { layout: 'default', title: 'Setup for coding agents' },
  'SPEC_TEMPLATE'    => { layout: 'default', title: 'Specification template' },
  'PLAN_TEMPLATE'    => { layout: 'default', title: 'Implementation plan template' }
}.freeze

# Stand-in for jekyll-seo-tag: the real plugin injects this on Pages.
# Registered as a Liquid::Tag so `{% seo %}` parses like the plugin's own tag.
class SeoTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super
    @markup = markup
  end

  def render(context)
    title = context['page']['title'] || 'PIANO Developer Wiki'
    description = context['site']['description'].to_s
    safe = ->(s) { s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;') }
    <<~HTML
      <title>#{safe.call(title)} | PIANO Developer Wiki</title>
      <meta name="generator" content="Jekyll v3.10.0" />
      <meta name="description" content="#{safe.call(description)}" />
      <meta property="og:title" content="#{safe.call(title)}" />
      <meta property="og:description" content="#{safe.call(description)}" />
      <meta property="og:type" content="website" />
      <meta property="og:url" content="https://piano-louvor-ja.github.io#{BASE}/" />
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

PAGES.each do |slug, meta|
  md = if slug == 'index'
         index_body
       else
         raw = File.read(File.join(SRC, "#{slug}.md"))
         # Layout supplies the document <h1>; strip the leading ATX heading so
         # the page has exactly one h1 (same as the current live site behaviour).
         raw.sub(/\A#\s+.+?\n+/, '')
       end

  html = Kramdown::Document.new(md, input: 'GFM').to_html

  # Heading permalinks. Empty and decorative, kept out of the tab order —
    # same treatment anchor-js gives them on the live site.
    add_permalink = lambda do |level, id, inner|
      %(<h#{level} id="#{id}">#{inner}) +
        %(<a class="headerlink" href="##{id}" tabindex="-1" aria-hidden="true"></a></h#{level}>)
    end
    html = html.gsub(/<h2 id="([^"]+)">(.*?)<\/h2>/m) { add_permalink[2, Regexp.last_match(1), Regexp.last_match(2)] }
    html = html.gsub(/<h3 id="([^"]+)">(.*?)<\/h3>/m) { add_permalink[3, Regexp.last_match(1), Regexp.last_match(2)] }

  assigns = {
    'site' => {
      'title' => 'PIANO Developer Wiki',
      'lang' => 'pt-BR',
      'description' => 'Onboarding público + docs de contribuidor para o ecossistema Piano-Louvor-JA'
    },
    'page' => { 'title' => meta[:title] }
  }

  # relative_url: prefix with the project path like jekyll does on Pages.
  html_out = render_layout(meta[:layout], assigns, html).gsub('"/', "\"#{BASE}/")

  path = File.join(OUT, slug == 'index' ? 'index.html' : "#{slug}.html")
  File.write(path, html_out)

  # Cheap sanity gates so a broken layout fails here, not on Pages.
  errors << "#{slug}: no <html"     unless html_out.include?('<html')
  errors << "#{slug}: no stylesheet" unless html_out.include?("href=\"#{BASE}/assets/css/brand.css\"")
  errors << "#{slug}: no toggle"     unless html_out.include?('id="theme-toggle"')
  errors << "#{slug}: no header"     unless html_out.include?('class="site-header"')
  errors << "#{slug}: no footer"     unless html_out.include?('class="site-footer"')
  errors << "#{slug}: no logo"       unless html_out.include?("#{BASE}/assets/logo.svg")
  count = html_out.scan(/<h1[\s>]/).size
  errors << "#{slug}: expected 1 <h1>, found #{count}" unless count == 1
  errors << "#{slug}: Liquid/Liquid leak" if html_out.include?('{{') || html_out.include?('{%')
end

# Internal link check: every internal href must resolve to a built file.
# /wiki/* maps to the preview root; assets keep their real relative layout.
Dir[File.join(OUT, '*.html')].each do |file|
  slug = File.basename(file, '.html')
  File.read(file).scan(/href="([^"]+)"/).flatten.each do |href|
    next unless href.start_with?("#{BASE}/")
    # Assets are validated by the dedicated check below.
    next if href.include?('/assets/')
    target = href.sub("#{BASE}/", '').split('#').first.to_s.split('?').first.to_s
    next if target.empty?
    expected = File.join(OUT, target.end_with?('.html') ? target : "#{target}.html")
    errors << "#{slug}: broken link #{href}" unless File.exist?(expected)
  end
end

# Assets referenced by the layout must exist on disk.
Dir[File.join(OUT, '*.html')].each do |file|
  slug = File.basename(file, '.html')
  File.read(file).scan(/(?:href|src)="(#{Regexp.escape(BASE)}\/assets\/[^"]+)"/).flatten.uniq.each do |href|
    asset = href.sub("#{BASE}/", '')
    errors << "#{slug}: missing asset #{asset}" unless File.exist?(File.join(OUT, asset))
  end
end

if errors.empty?
  puts "OK — #{PAGES.size} páginas renderizadas em #{OUT}"
  exit 0
else
  warn "FALHOU (#{errors.size}):"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
