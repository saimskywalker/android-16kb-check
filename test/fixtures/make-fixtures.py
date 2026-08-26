#!/usr/bin/env python3
"""Regenerate the archive fixtures. Run from this directory: python3 make-fixtures.py

The .so payloads are deliberately not valid ELF. The tests stub llvm-objdump,
so the only thing these fixtures need to get right is the archive layout.
"""
import zipfile

SO = b"\x7fELF\x02\x01\x01\x00" + b"\x00" * 56 + b"not-a-real-elf-body-fixture-only\n"


def make(path, entries):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
        for name, data in entries:
            z.writestr(name, data)


make("sample.apk", [
    ("AndroidManifest.xml", b"fixture\n"),
    ("lib/arm64-v8a/libexample.so", SO),
    ("lib/arm64-v8a/libsecond.so", SO),
    ("lib/armeabi-v7a/liblegacy.so", SO),
])
make("sample.aab", [
    ("BundleConfig.pb", b"fixture\n"),
    ("base/lib/arm64-v8a/libexample.so", SO),
    ("base/lib/armeabi-v7a/liblegacy.so", SO),
])
make("no-native-libs.apk", [
    ("AndroidManifest.xml", b"fixture\n"),
])
make("only-32bit.apk", [
    ("AndroidManifest.xml", b"fixture\n"),
    ("lib/armeabi-v7a/liblegacy.so", SO),
])
