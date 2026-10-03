#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Content sanitization gate.
#
# Mirrors the checks from the repo's own `.github/workflows/sanitize.yml`
# (which lives on the unmerged `feat/portar-conhecimento-docs` branch, so it
# cannot run here) and adds the content rules from `wiki-publica/ALLOWLIST.md`:
# no infrastructure, no personal names, no operational topology.
#
# Usage: ruby tools/sanitize_check.rb
# Exits non-zero and lists every violation.

SRC = File.expand_path('..', __dir__)

# Only the allowlisted documents are scanned. `tools/` is internal tooling and
# legitimately mentions the terms it forbids.
DOCS = %w[
  AGENTS.md AGENT_SETUP.md ARCHITECTURE.md CONTRIBUTING.md FAQ.md
  GETTING_STARTED.md GOVERNANCE.md PLAN_TEMPLATE.md README.md
  SPEC_TEMPLATE.md index.md
].freeze

violations = []
flag = ->(file, rule, match) { violations << "#{file}: [#{rule}] #{match}" }

# --- Rules from sanitize.yml, verbatim -------------------------------------
SANITIZE_RULES = {
  'email pessoal' =>
    /rafael\.zendron[0-9]*@gmail\.com|ezequiasfonseca@gmail\.com|rafaelejosi/i,
  'senha em claro' =>
    /Piano@2026/i,
  'IP de produção' =>
    /\b31\.97\.[0-9]{1,3}\.[0-9]{1,3}\b/,
  'token de API' =>
    /ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}/,
  'chave privada' =>
    /BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY/i
}.freeze

# --- Rules from the allowlist: operational detail must not leak ------------
ALLOWLIST_RULES = {
  'alias SSH / host de infra' =>
    /\bssh\s+(oracle-vm|hostinger)\b|\b(oracle-vm|hostinger)\b/i,
  'porta de serviço' =>
    /:(?:3012|3025|3100|3101|5678|9090)\b/,
  'topologia de rede' =>
    /\btailscale\b/i,
  'nome de pessoa' =>
    /\b(ezequias|rafael zendron|rafael dias zendron)\b/i,
  'board automation' =>
    /\bkanban\b|\bprojects?\s+board\b/i,
  'rota de review interna' =>
    /bot-review-checklist|ia-approved|ia-changes-requested|z\.ai\s*GLM/i,
  'referência a repo privado' =>
    /Piano-Louvor-JA\/docs\b/,
  'dica de teste específico' =>
    /Athus|Vox|Arautos/i,
  'runbook interno' =>
    /04-Projects\//,
  'stack com versão interna' =>
    /Node\s*(?:24|22)\b|nvm\b/i,
  # A rule that names a concrete branch or a workflow a reader cannot reach is
  # worse than no rule: an external contributor cannot comply with it.
  'regra não acionável' =>
    /PRs?\s+to\s+`?staging|from\s+`?staging|branch\s+from\s+`?staging|pull requests? go through\s+`?staging/i,
  'promessa de automação interna' =>
    /checklist it points to|\b(ia-approved|ia-changes-requested|ia-reviewed)\b/i
}.freeze

# Translations are published pages too — a leak in pt/ ships exactly like a leak
# in the root. Scanned with the same rules.
translated = Dir[File.join(SRC, '*', '*.md')].map do |f|
  f.sub("#{SRC}/", '')
end

DOCUMENTS = DOCS + translated

DOCUMENTS.each do |doc|
  path = File.join(SRC, doc)
  unless File.exist?(path)
    violations << "#{doc}: não encontrado"
    next
  end

  body = File.read(path)

  SANITIZE_RULES.each { |rule, rx| flag[doc, rule, body[/#{rx}/]] if body =~ rx }
  ALLOWLIST_RULES.each { |rule, rx| flag[doc, rule, body[/#{rx}/]] if body =~ rx }
end

# The allowlist itself must not drift: this script and the page list must agree.
root_docs = Dir[File.join(SRC, '*.md')].map { |f| File.basename(f) }.sort
if root_docs != DOCS.sort
  violations << "allowlist da raiz divergiu:\n  disco:    #{root_docs.inspect}\n  esperado: #{DOCS.sort.inspect}"
end

if violations.any?
  warn "SANITIZAÇÃO FALHOU (#{violations.size}):"
  violations.each { |v| warn "  - #{v}" }
  warn "\nNada disso pode ser publicado no wiki público."
  exit 1
end

puts "OK — #{DOCUMENTS.size} documentos (#{translated.size} traduzidos), nenhuma violação."