# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | ✅                 |
| staging | ⚠️ preview only    |

## Reporting a Vulnerability

**Não abra issue público para vulnerabilidades de segurança.**

Envie email para: **security@pianolouvorja.com.br**

Inclua:
- Descrição da vulnerabilidade
- Passos para reproduzir
- Impacto potencial
- Prova de conceito (se houver)

**SLA de resposta:**
- Confirmação de recebimento: 24h úteis
- Avaliação inicial: 72h úteis
- Correção: depende da severidade (P0: 24h, P1: 72h, P2: 1 semana)

## Exemplos de vulnerabilidades reportadas

- Credenciais/segredos expostos em código/docs
- Injeção (SQL, XSS, template)
- Acesso não autorizado a dados sensíveis
- Bypass de autenticação/autorização
- Vazamento de dados pessoais (LGPD)

## Histórico

| Data | Tipo | Severidade | Status |
|------|------|------------|--------|
| 2026-09-28 | Senha em claro em doc | Crítica | Corrigida no wiki, rotação recomendada |

---

> **Nota:** Esta wiki é pública e sanitizada. Vulnerabilidades em repos privados (api, app, etc.) devem ser reportadas aos mantenedores via issue privada ou email acima.
