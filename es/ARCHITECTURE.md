---
lang: es
locale: es_ES
title: Arquitectura
---

## Ecosistema de productos

PIANO / LouvorJA se organiza en aplicaciones y servicios que cooperan entre sí:

- Las aplicaciones cliente ofrecen experiencias de creación, reproducción y presentación.
- Las APIs de servicio aportan capacidades de dominio compartidas cuando hacen falta.
- Las experiencias web cubren flujos públicos y de acompañamiento.
- Los componentes de receiver y display dan soporte a entornos de presentación.
- La documentación recoge el uso público y las guías de contribución.

## Principios de diseño

- Mantener simples los flujos dirigidos al usuario.
- Preservar la compatibilidad entre clientes soportados.
- Preferir contratos explícitos entre componentes.
- Validar los cambios en la frontera del componente y en los flujos consumidores relevantes.
- Mantener la topología operativa, las credenciales y los detalles privados de despliegue fuera de la documentación pública.

Esto es un mapa de alto nivel, no un manual de operaciones.