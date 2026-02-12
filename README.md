# flutter-shadcn Registry Directory

This repository hosts the official registry directory for third-party Flutter UI registries consumed by `flutter_shadcn`.

## Directory URL

https://flutter-shadcn.github.io/registry-directory/registries/registries.json

## Repository Contents

- `registries/registries.json`: Approved registries directory
- `registries/registries.schema.json`: Draft 2020-12 strict schema
- `.github/workflows/validate.yml`: PR and push validation

This repository does not host UI components. Each external registry hosts its own component files.

## Adding a Registry

1. Fork this repository.
2. Add your entry to `registries/registries.json`.
3. Open a pull request.

CI validates schema correctness, duplicate namespaces, duplicate install roots, URL reachability, and `components.json` availability.

## Registry Rules

- Must be publicly reachable over HTTPS.
- Must provide a valid `components.json` through `baseUrl + paths.componentsJson`.
- Must declare required fields:
`id`, `displayName`, `maintainers`, `repo`, `license`, `minCliVersion`, `baseUrl`, `paths.componentsJson`, `install.namespace`, `install.root`.
- Must use a unique `install.namespace`.
- Must use a unique `install.root`.
- Namespaces are permanent once merged.
- Paths must be registry-relative and must not include unsafe traversal patterns.

## Governance

Maintainers may reject, remove, or require updates to entries that are unsafe, broken, abandoned, or out of policy.

## CLI Notes

CLI-specific usage and integration details are documented in `registries/README.md`.

## License

This repository is licensed under MIT.
