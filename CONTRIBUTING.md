# Contributing to the Registry Directory

Thank you for helping grow the Flutter UI ecosystem.

## Repository Workflow

- Registry source files live in `registries/entries/*.json` (one file per registry).
- `registries/registries.json` is generated. Do not hand-edit it.
- Regenerate before opening a PR:
  - `dart run scripts/build_registries.dart`

## Before Submitting

Please ensure:

- Your registry is publicly hosted.
- `components.json` is reachable.
- Your `baseUrl` is HTTPS and stable.
- Your namespace is unique.
- Your install root is unique.
- Your registry works with the latest CLI version.

## Schema Requirements (v1)

Required top-level registry fields:

- `id`
- `displayName`
- `maintainers`
- `repo`
- `license`
- `minCliVersion`
- `baseUrl`
- `paths.componentsJson`
- `install.namespace`
- `install.root`

Path and install constraints:

- Paths must be relative and safe (no traversal / unsafe absolute forms).
- `install.namespace` must be lowercase and CLI-safe.
- `install.root` must be under `lib/...`.
- Namespaces are permanent once merged.

If you use `init` actions:

- `init.version` must be `1`.
- `init.actions` must contain at least one action.
- `copyFiles`: requires `files` unless using `from` + `to` directory semantics.
- `copyDir`: requires `from` + `to`, and exactly one of `files` or `index`.
- If `base` is set, `destBase` must also be set (and vice versa).

## Pull Request Checklist

- [ ] Registry entry added to `registries/entries/<id>.json`
- [ ] Ran `dart run scripts/build_registries.dart`
- [ ] Generated `registries/registries.json` is included in the PR
- [ ] Namespace is unique
- [ ] Install root is unique
- [ ] URLs are HTTPS
- [ ] `minCliVersion` follows SemVer
- [ ] `baseUrl` resolves correctly
- [ ] `paths.componentsJson` resolves correctly
- [ ] Optional paths (`indexJson`, `themesJson`, `metaJson`, etc.) resolve if provided
- [ ] `init` actions validate against `registries.schema.json` (if present)
- [ ] `trust.mode=sha256` includes a `sha256` value (if used)
- [ ] No breaking schema changes introduced
