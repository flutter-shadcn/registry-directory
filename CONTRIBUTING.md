# Contributing to the Registry Directory

Thank you for helping grow the Flutter UI ecosystem.

## Before Submitting

Please ensure:

- Your registry is publicly hosted.
- `components.json` is reachable.
- Your namespace is unique.
- Your install root is unique.
- Your registry works with the latest CLI version.

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
- [ ] No breaking schema changes introduced
