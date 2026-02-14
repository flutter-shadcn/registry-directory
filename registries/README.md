# Registry Directory for CLI

This folder contains the canonical registry directory consumed by `flutter_shadcn`.

`registries.json` is generated from `registries/entries/*.json` via:

```bash
dart run scripts/build_registries.dart
```

## CLI Component Addressing

Use fully-qualified component addresses:

```bash
flutter_shadcn add <namespace>:<component>
```

Examples:

- `flutter_shadcn add shadcn:button`
- `flutter_shadcn add orient:card`

## Directory Endpoint

https://flutter-shadcn.github.io/registry-directory/registries/registries.json

## Resolution Model

For each registry entry:

- `baseUrl` is the root URL.
- `paths.componentsJson` is resolved relative to `baseUrl`.
- `install.namespace` is the address prefix.
- `install.root` is the destination root in the consumer project.

## Validation Expectations

The CLI should enforce:

- JSON schema validity
- namespace uniqueness (`install.namespace`)
- install-root uniqueness (`install.root`)
- minimum CLI version gate (`minCliVersion`)
- optional trust pin checks (`trust.mode = sha256`)
