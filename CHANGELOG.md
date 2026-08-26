# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because the exit codes are the interface, a change to what any of `0`, `1` or
`2` means is a breaking change and takes a major version, even if the script
looks barely different.

## [Unreleased]

## [1.0.0] - 2026-08-27

First release.

### Added

- `android-16kb-check <path.apk|path.aab>` — checks archive alignment and the
  ELF LOAD alignment of every 64-bit `.so` against Google Play's 16 KB page
  requirement.
- Three-way exit code: `0` aligned, `1` unaligned, `2` could not verify.
  `2` is deliberately distinct from `0`; a machine without the toolchain
  reports an unproven gate rather than a pass.
- `--ndk` and `ANDROID_NDK_HOME` / `ANDROID_NDK_ROOT` for naming the NDK that
  supplies `llvm-objdump`. An explicitly named NDK is authoritative: if it has
  no `llvm-objdump`, the run fails instead of falling back to another one.
- Auto-detection of the highest `$ANDROID_HOME/ndk/<version>`, the newest
  `$ANDROID_HOME/build-tools/<version>/zipalign`, and `~/Library/Android/sdk`
  or `~/Android/Sdk` when no SDK root is set.
- `--bundletool` and `BUNDLETOOL` for AAB input, accepting either an
  executable or a `.jar` path run through `java -jar`.
- 32-bit ABIs reported as `SKIP` rather than omitted, so an exempt ABI cannot
  be mistaken for one that passed.
- `--help` and `--version`.

[Unreleased]: https://github.com/saimskywalker/android-16kb-check/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/saimskywalker/android-16kb-check/releases/tag/v1.0.0
