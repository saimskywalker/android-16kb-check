#!/usr/bin/env python3
"""Regenerate the archive fixtures. Run from this directory: python3 make-fixtures.py

The .so payloads are deliberately not valid ELF. The tests stub llvm-objdump,
so the only thing these fixtures need to get right is the archive layout.
"""
import struct
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
# A 64-bit ABI directory that holds no .so. wrap.sh is a real file Android
# looks for at lib/<abi>/wrap.sh, so this shape is not hypothetical. There is
# no 64-bit library here to measure, which makes it a 2 and not a pass.
make("empty-64bit-abi.apk", [
    ("AndroidManifest.xml", b"fixture\n"),
    ("lib/arm64-v8a/wrap.sh", b"#!/system/bin/sh\nexec \"$@\"\n"),
    ("lib/armeabi-v7a/liblegacy.so", SO),
])

# An archive holding a 64-bit .so that unzip will refuse to extract: its
# compression method is patched to one Info-ZIP does not implement, which is
# how a partial extraction is produced without depending on a corrupt file.
# The point is only that unzip skips an entry and says so in its exit status;
# a full disk or a truncated archive produce the same shape. One 64-bit
# library is readable and one is not, so a run that ignores unzip's status
# measures half the artifact and calls it a pass.
make("unreadable-entry.apk", [
    ("AndroidManifest.xml", b"fixture\n"),
    ("lib/arm64-v8a/libgood.so", SO),
    ("lib/arm64-v8a/libopaque.so", SO),
])

def patch_method(path, entry, method=14):
    """Rewrite one entry's compression method, in both headers that carry it."""
    data = bytearray(open(path, "rb").read())
    for magic, name_off, method_off in ((b"PK\x03\x04", 26, 8), (b"PK\x01\x02", 28, 10)):
        i = 0
        while True:
            i = data.find(magic, i)
            if i < 0:
                break
            nlen = struct.unpack_from("<H", data, i + name_off)[0]
            start = i + (30 if magic == b"PK\x03\x04" else 46)
            if data[start:start + nlen] == entry:
                struct.pack_into("<H", data, i + method_off, method)
            i += 4
    open(path, "wb").write(bytes(data))

patch_method("unreadable-entry.apk", b"lib/arm64-v8a/libopaque.so")
