# ADR-001: Multi-device communication through a project WebSocket protocol

Status: Accepted

## Context

Presentation must work across supported TV receiver environments and client platforms without requiring proprietary casting hardware.

## Decision

TV receivers act as display clients and communicate through the project's versioned WebSocket protocol. Desktop, web and mobile can control a receiver through that contract.

Chromecast and AirPlay are not part of the supported architecture.

## Consequences

- Receiver compatibility depends on protocol versioning and release validation.
- Clients retain control of presentation state.
- New display features must be tested against the receiver contract.
