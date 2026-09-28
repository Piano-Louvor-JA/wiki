# Architecture

## Product ecosystem

PIANO / LouvorJA is organized as cooperating applications and services:

- Client applications provide creation, playback and presentation experiences.
- Service APIs provide shared domain capabilities where required.
- Web experiences support public and companion workflows.
- Receiver and display components support presentation environments.
- Documentation captures public usage and contribution guidance.

## Design principles

- Keep user-facing workflows simple.
- Preserve compatibility across supported clients.
- Prefer explicit contracts between components.
- Validate changes at the component boundary and in relevant consumer flows.
- Keep operational topology, credentials and private deployment details out of public documentation.

This is intentionally a high-level map, not an operations manual.
