# Test fixtures

These are tiny ZIP archives that mimic the *layout* of an APK and an AAB. The
`.so` entries are not real ELF files — the tests stub `llvm-objdump`, so what
matters here is only where the entries sit inside the archive.

| file | contains |
|---|---|
| `sample.apk` | `lib/arm64-v8a/` (two libs) and `lib/armeabi-v7a/` (one lib) |
| `sample.aab` | the same, nested under `base/lib/` as an AAB stores it |
| `no-native-libs.apk` | no `lib/` directory at all |
| `only-32bit.apk` | `lib/armeabi-v7a/` only, no 64-bit ABI |
| `empty-64bit-abi.apk` | `lib/arm64-v8a/` holding only a `wrap.sh`, so there is a 64-bit ABI directory but no 64-bit library to measure |

Committed as binaries so the suite needs no zip tool. Regenerate with
`make-fixtures.py` if the layout ever has to change.
