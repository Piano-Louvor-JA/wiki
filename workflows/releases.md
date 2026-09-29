# Releases

## General release flow

1. Merge validated changes into `staging` through review.
2. Open a release PR from `staging` to `main`.
3. Publish with the repository's documented release tooling.
4. Validate the released public behavior and affected consumers.

## Desktop

Use the repository version scripts and release pipeline. Validate native packaging and auto-update behavior where applicable.

## Web

Release the production build only after its checks pass. Validate the published user path, not only the build artifact.

## API

Deploy from the release branch through the documented operations path. Verify the health endpoint, intended contract behavior and database migration result after deployment. Do not publish operational topology in PRs or public docs.

## Mobile

Release tags follow product phases:

| Version line | Scope |
|---|---|
| `0.1.x` | Read existing content |
| `0.2.x` | Edit and organize content |
| `0.3.x` | Create custom content |
| `1.0.x` | Supported parity and production readiness |

Use patch versions for bug fixes only. Validate on a representative device before broad rollout.

## TV receiver

Receiver updates can affect presentation devices. Validate protocol compatibility before publishing an update channel release.
