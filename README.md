# flutter-shadcn Registry Directory

This repository hosts the official registry directory for third-party Flutter UI registries consumed by `flutter_shadcn`.

## Directory URL

https://flutter-shadcn.github.io/registry-directory/registries/registries.json

## Repository Contents

- `registries/entries/*.json`: Source-of-truth registry entry files (one file per registry)
- `registries/registries.json`: Generated combined registries directory
- `registries/registries.schema.json`: Draft 2020-12 strict schema
- `scripts/build_registries.dart`: Builds the combined directory from entries
- `.github/workflows/validate.yml`: PR and push validation

This repository does not host UI components. Each external registry hosts its own component files.

## Adding a Registry

1. Fork this repository.
2. Add a new file in `registries/entries/` (for example: `registries/entries/my-registry.json`).
3. Run:
`dart run scripts/build_registries.dart`
4. Open a pull request.

CI validates entry syntax, rebuilds `registries/registries.json`, checks it is up to date, validates schema correctness, checks duplicate namespaces/install roots, URL reachability, and `components.json` availability.

## Registry Rules

- Must be publicly reachable over HTTPS.
- Must provide a valid `components.json` through `baseUrl + paths.componentsJson`.
- Must declare required fields:
`id`, `displayName`, `maintainers`, `repo`, `license`, `minCliVersion`, `baseUrl`, `paths.componentsJson`, `install.namespace`, `install.root`.
- Must use a unique `install.namespace`.
- Must use a unique `install.root`.
- Namespaces are permanent once merged.
- Paths must be registry-relative and must not include unsafe traversal patterns.
- `minCliVersion` must be SemVer.
- `trust.mode=sha256` requires `trust.sha256`.

## Init Action Model

If you define `init`, it must follow schema v1:

- `init.version` must be `1`
- `init.actions` must have at least one item
- Supported actions: `ensureDirs`, `copyFiles`, `copyDir`, `mergePubspec`, `message`
- `copyFiles` supports optional `base` + `destBase` (must be provided together)
- `copyDir` requires `from` + `to` and exactly one of `files` or `index`

## Governance

Maintainers may reject, remove, or require updates to entries that are unsafe, broken, abandoned, or out of policy.

## CLI Notes

CLI-specific usage and integration details are documented in `registries/README.md`.

## License

This repository is licensed under MIT.
