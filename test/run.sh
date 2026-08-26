#!/usr/bin/env bash
#
# Test suite for android-16kb-check.
#
# Needs nothing but bash, coreutils and unzip. The external tools the checker
# depends on (llvm-objdump, bundletool, zipalign) are replaced by the stubs in
# test/stubs, and the artifacts by the tiny archives in test/fixtures, so the
# suite runs anywhere without an Android SDK.
#
# The load-bearing case is "toolchain missing must exit 2, never 0". A checker
# that reports success when it could not look is worse than no checker, so
# several tests here exist only to pin that down.
#
# Usage: test/run.sh [name-filter]

# Test bodies and assertion helpers are invoked indirectly, by name, from
# check(). ShellCheck cannot see that, so it reports every one of them as dead
# code.
# shellcheck disable=SC2329

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
TOOL="${ROOT}/android-16kb-check"
FIXTURES="${HERE}/fixtures"
STUBS="${HERE}/stubs"
FILTER="${1:-}"

TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

# An isolated PATH holding only the coreutils the checker needs — no
# llvm-objdump, no bundletool, no zipalign. This is how "toolchain absent" is
# simulated without touching the machine's real environment.
BARE_BIN="${TMPROOT}/bare-bin"
mkdir -p "${BARE_BIN}"
for prog in bash env sh unzip mktemp find awk sort grep basename tail wc tr rm cat sed; do
  src="$(command -v "${prog}" 2>/dev/null || true)"
  if [[ -n "${src}" ]]; then
    ln -sf "${src}" "${BARE_BIN}/${prog}"
  fi
done
BARE_PATH="${BARE_BIN}"
FULL_PATH="${STUBS}:${BARE_BIN}"

# A HOME with no ~/Library/Android/sdk, so auto-detection cannot wander off
# onto the developer's real SDK mid-test.
FAKE_HOME="${TMPROOT}/home"
mkdir -p "${FAKE_HOME}"

# An NDK-shaped directory that contains no llvm-objdump.
BOGUS_NDK="${TMPROOT}/bogus-ndk"
mkdir -p "${BOGUS_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin"

export -n ANDROID_HOME ANDROID_SDK_ROOT ANDROID_NDK_HOME ANDROID_NDK_ROOT BUNDLETOOL 2>/dev/null || true
unset ANDROID_HOME ANDROID_SDK_ROOT ANDROID_NDK_HOME ANDROID_NDK_ROOT BUNDLETOOL

PASSED=0
FAILED=0
CURRENT=""
OUT=""
RC=0

# Run the checker with a controlled environment. Everything after the first
# argument is passed to the tool; env overrides come in via TEST_ENV.
run_tool() {
  local -a env_args=("HOME=${FAKE_HOME}" "PATH=${TEST_PATH:-${FULL_PATH}}")
  if [[ -n "${TEST_ENV:-}" ]]; then
    # shellcheck disable=SC2206  # deliberate word splitting: TEST_ENV is a
    # space-separated list of KEY=VALUE pairs written by the tests themselves.
    local -a extra=(${TEST_ENV})
    env_args+=("${extra[@]}")
  fi
  OUT="$(env -i "${env_args[@]}" "${TOOL}" "$@" 2>&1)"
  RC=$?
  return 0
}

start() {
  CURRENT="$1"
  TEST_PATH=""
  TEST_ENV=""
}

fail() {
  FAILED=$((FAILED + 1))
  printf 'FAIL  %s\n' "${CURRENT}"
  printf '      %s\n' "$1"
  printf '      --- output (exit %s) ---\n' "${RC}"
  printf '%s\n' "${OUT}" | sed 's/^/      /'
  printf '      ---\n'
}

pass() {
  PASSED=$((PASSED + 1))
  printf 'ok    %s\n' "${CURRENT}"
}

assert_rc() {
  if [[ "${RC}" != "$1" ]]; then
    fail "expected exit $1, got ${RC}"
    return 1
  fi
  return 0
}

assert_out() {
  if ! printf '%s' "${OUT}" | grep -qF -- "$1"; then
    fail "expected output to contain: $1"
    return 1
  fi
  return 0
}

assert_not_out() {
  if printf '%s' "${OUT}" | grep -qF -- "$1"; then
    fail "expected output NOT to contain: $1"
    return 1
  fi
  return 0
}

# A test body is a function named t_<something>; check() runs one unless the
# filter excludes it.
check() {
  local name="$1"
  if [[ -n "${FILTER}" && "${name}" != *"${FILTER}"* ]]; then
    return 0
  fi
  start "${name}"
  if "$2"; then
    pass
  fi
}

# --------------------------------------------------------------- help/version

t_help_exits_zero() {
  run_tool --help
  assert_rc 0 || return 1
  assert_out "USAGE" || return 1
  assert_out "EXIT CODES" || return 1
  # The exit-2 caveat must survive any future rewrite of the help text.
  assert_out "NOT A PASS" || return 1
}

t_help_short_flag() {
  run_tool -h
  assert_rc 0 || return 1
  assert_out "USAGE" || return 1
}

t_version() {
  run_tool --version
  assert_rc 0 || return 1
  assert_out "android-16kb-check" || return 1
}

t_version_short_flag() {
  run_tool -V
  assert_rc 0 || return 1
  assert_out "android-16kb-check" || return 1
}

# ---------------------------------------------------------- argument handling

t_no_arguments() {
  run_tool
  assert_rc 2 || return 1
  assert_out "no artifact given" || return 1
  assert_out "--help" || return 1
}

t_missing_file() {
  run_tool "${TMPROOT}/does-not-exist.apk"
  assert_rc 2 || return 1
  assert_out "artifact not found" || return 1
  assert_out "does-not-exist.apk" || return 1
}

t_directory_instead_of_file() {
  run_tool "${TMPROOT}"
  assert_rc 2 || return 1
  return 0
}

t_wrong_extension() {
  : > "${TMPROOT}/thing.zip"
  run_tool "${TMPROOT}/thing.zip"
  assert_rc 2 || return 1
  assert_out "expected a .aab or .apk" || return 1
}

t_unknown_option() {
  run_tool --wat "${FIXTURES}/sample.apk"
  assert_rc 2 || return 1
  assert_out "unknown option: --wat" || return 1
}

t_ndk_flag_requires_value() {
  run_tool --ndk
  assert_rc 2 || return 1
  assert_out "--ndk requires a value" || return 1
}

t_bundletool_flag_requires_value() {
  run_tool --bundletool
  assert_rc 2 || return 1
  assert_out "--bundletool requires a value" || return 1
}

t_two_artifacts_rejected() {
  run_tool "${FIXTURES}/sample.apk" "${FIXTURES}/sample.aab"
  assert_rc 2 || return 1
  assert_out "expected exactly one artifact" || return 1
}

t_double_dash_ends_options() {
  # After `--`, a leading dash is part of the filename, not a flag. Proven by
  # the error naming the file rather than complaining about an unknown option.
  run_tool -- -weird-name.apk
  assert_rc 2 || return 1
  assert_out "artifact not found: -weird-name.apk" || return 1
  assert_not_out "unknown option" || return 1
}

t_equals_form_of_ndk_flag() {
  run_tool "--ndk=${BOGUS_NDK}" "${FIXTURES}/sample.apk"
  assert_rc 2 || return 1
  assert_out "no llvm-objdump under the NDK named by --ndk" || return 1
}

# ----------------------------------------------- the exit-2 contract (core)

t_missing_toolchain_is_two_not_zero() {
  # THE test. Nothing that resolves the toolchain is on PATH, so there is no
  # way to know whether this artifact is aligned. Reporting 0 here is the bug
  # this tool exists to avoid.
  TEST_PATH="${BARE_PATH}"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 2 || return 1
  assert_out "llvm-objdump" || return 1
  assert_out "Exit code 2 means unproven, not passed." || return 1
  assert_not_out "PASS" || return 1
}

t_missing_toolchain_on_aab_is_two() {
  TEST_PATH="${BARE_PATH}"
  run_tool "${FIXTURES}/sample.aab"
  assert_rc 2 || return 1
  assert_not_out "PASS" || return 1
}

t_bogus_ndk_dir_is_two() {
  # An explicitly named NDK with nothing in it must fail, not quietly fall back
  # to some other objdump that happens to be on PATH.
  run_tool --ndk "${BOGUS_NDK}" "${FIXTURES}/sample.apk"
  assert_rc 2 || return 1
  assert_out "no llvm-objdump under the NDK named by --ndk" || return 1
  assert_out "sdkmanager" || return 1
}

t_bogus_android_ndk_home_is_two() {
  TEST_ENV="ANDROID_NDK_HOME=${BOGUS_NDK}"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 2 || return 1
  assert_out "ANDROID_NDK_HOME" || return 1
}

t_missing_bundletool_is_two() {
  # objdump present, bundletool absent: still unproven.
  TEST_PATH="${TMPROOT}/objdump-only:${BARE_BIN}"
  mkdir -p "${TMPROOT}/objdump-only"
  ln -sf "${STUBS}/llvm-objdump" "${TMPROOT}/objdump-only/llvm-objdump"
  run_tool "${FIXTURES}/sample.aab"
  assert_rc 2 || return 1
  assert_out "bundletool not found on PATH" || return 1
  assert_out "brew install bundletool" || return 1
}

t_missing_zipalign_is_two() {
  TEST_PATH="${TMPROOT}/objdump-only:${BARE_BIN}"
  mkdir -p "${TMPROOT}/objdump-only"
  ln -sf "${STUBS}/llvm-objdump" "${TMPROOT}/objdump-only/llvm-objdump"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 2 || return 1
  assert_out "zipalign not found" || return 1
}

t_missing_bundletool_jar_is_two() {
  run_tool --bundletool "${TMPROOT}/nope.jar" "${FIXTURES}/sample.aab"
  assert_rc 2 || return 1
  return 0
}

t_artifact_without_native_libs_is_two() {
  # No .so at all is not a pass — there was nothing to measure.
  run_tool "${FIXTURES}/no-native-libs.apk"
  assert_rc 2 || return 1
  assert_out "no native libraries found" || return 1
  assert_not_out "PASS" || return 1
}

t_only_32bit_is_two_not_zero() {
  # A 32-bit-only artifact proves nothing about the 64-bit build users install.
  run_tool "${FIXTURES}/only-32bit.apk"
  assert_rc 2 || return 1
  assert_out "no 64-bit ABI" || return 1
  assert_not_out "PASS" || return 1
}

# --------------------------------------------------------- aligned / unaligned

t_apk_aligned_passes() {
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 0 || return 1
  assert_out "PASS" || return 1
  assert_out "libexample.so" || return 1
  assert_out "min align 2**14" || return 1
}

t_apk_reports_32bit_as_skip() {
  # Reported explicitly: an ABI mentioned nowhere reads like one that passed.
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 0 || return 1
  assert_out "armeabi-v7a" || return 1
  assert_out "[SKIP]" || return 1
}

t_apk_over_aligned_passes() {
  TEST_ENV="STUB_OBJDUMP_ALIGN=2**16"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 0 || return 1
  assert_out "PASS" || return 1
}

t_apk_underaligned_elf_fails_with_one() {
  TEST_ENV="STUB_OBJDUMP_ALIGN=2**12"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 1 || return 1
  assert_out "min align 2**12" || return 1
  assert_out "Play will reject this upload" || return 1
  # The remedy has to point at the dependency, not at the caller's own NDK.
  assert_out "PREBUILT" || return 1
}

t_apk_unaligned_zip_fails_with_one() {
  TEST_ENV="STUB_ZIPALIGN_RC=1"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 1 || return 1
  assert_out "not 16 KB aligned" || return 1
  assert_out "AGP 8.5.1" || return 1
}

t_unreadable_elf_fails_with_one() {
  TEST_ENV="STUB_OBJDUMP_NO_LOAD=1"
  run_tool "${FIXTURES}/sample.apk"
  assert_rc 1 || return 1
  assert_out "no LOAD segments readable" || return 1
}

t_aab_aligned_passes() {
  run_tool "${FIXTURES}/sample.aab"
  assert_rc 0 || return 1
  assert_out "PAGE_ALIGNMENT_16K" || return 1
  assert_out "PASS" || return 1
}

t_aab_without_page_alignment_fails_with_one() {
  TEST_ENV="STUB_BUNDLETOOL_ALIGNED=0"
  run_tool "${FIXTURES}/sample.aab"
  assert_rc 1 || return 1
  assert_out "does NOT declare PAGE_ALIGNMENT_16K" || return 1
  assert_out "AGP 8.5.1" || return 1
}

t_aab_bundletool_failure_is_two() {
  TEST_ENV="STUB_BUNDLETOOL_FAIL=1"
  run_tool "${FIXTURES}/sample.aab"
  assert_rc 2 || return 1
  assert_out "could not read" || return 1
}

t_bundletool_env_var_is_honoured() {
  TEST_PATH="${TMPROOT}/objdump-only:${BARE_BIN}"
  mkdir -p "${TMPROOT}/objdump-only"
  ln -sf "${STUBS}/llvm-objdump" "${TMPROOT}/objdump-only/llvm-objdump"
  TEST_ENV="BUNDLETOOL=${STUBS}/bundletool"
  run_tool "${FIXTURES}/sample.aab"
  assert_rc 0 || return 1
  assert_out "PASS" || return 1
}

t_bundletool_flag_is_honoured() {
  TEST_PATH="${TMPROOT}/objdump-only:${BARE_BIN}"
  mkdir -p "${TMPROOT}/objdump-only"
  ln -sf "${STUBS}/llvm-objdump" "${TMPROOT}/objdump-only/llvm-objdump"
  run_tool --bundletool "${STUBS}/bundletool" "${FIXTURES}/sample.aab"
  assert_rc 0 || return 1
  assert_out "PASS" || return 1
}

# -------------------------------------------------------------------- runner

printf 'android-16kb-check test suite\n\n'

check "--help exits 0"                              t_help_exits_zero
check "-h exits 0"                                  t_help_short_flag
check "--version exits 0"                           t_version
check "-V exits 0"                                  t_version_short_flag
check "no arguments is a clear error"               t_no_arguments
check "missing file is a clear error"               t_missing_file
check "a directory is rejected"                     t_directory_instead_of_file
check "wrong extension is rejected"                 t_wrong_extension
check "unknown option is rejected"                  t_unknown_option
check "--ndk requires a value"                      t_ndk_flag_requires_value
check "--bundletool requires a value"               t_bundletool_flag_requires_value
check "two artifacts are rejected"                  t_two_artifacts_rejected
check "-- ends option parsing"                      t_double_dash_ends_options
check "--ndk=VALUE form works"                      t_equals_form_of_ndk_flag
check "missing toolchain exits 2, not 0"            t_missing_toolchain_is_two_not_zero
check "missing toolchain on an AAB exits 2"         t_missing_toolchain_on_aab_is_two
check "bogus --ndk exits 2 without falling back"    t_bogus_ndk_dir_is_two
check "bogus ANDROID_NDK_HOME exits 2"              t_bogus_android_ndk_home_is_two
check "missing bundletool exits 2"                  t_missing_bundletool_is_two
check "missing zipalign exits 2"                    t_missing_zipalign_is_two
check "missing bundletool jar exits 2"              t_missing_bundletool_jar_is_two
check "an artifact with no .so exits 2"             t_artifact_without_native_libs_is_two
check "a 32-bit-only artifact exits 2, not 0"       t_only_32bit_is_two_not_zero
check "an aligned APK exits 0"                      t_apk_aligned_passes
check "32-bit ABIs are reported as SKIP"            t_apk_reports_32bit_as_skip
check "over-aligned libraries pass"                 t_apk_over_aligned_passes
check "an under-aligned library exits 1"            t_apk_underaligned_elf_fails_with_one
check "an unaligned zip exits 1"                    t_apk_unaligned_zip_fails_with_one
check "an unreadable ELF exits 1"                   t_unreadable_elf_fails_with_one
check "an aligned AAB exits 0"                      t_aab_aligned_passes
check "an AAB without PAGE_ALIGNMENT_16K exits 1"   t_aab_without_page_alignment_fails_with_one
check "a bundletool failure exits 2"                t_aab_bundletool_failure_is_two
check "BUNDLETOOL env var is honoured"              t_bundletool_env_var_is_honoured
check "--bundletool flag is honoured"               t_bundletool_flag_is_honoured

printf '\n%s passed, %s failed\n' "${PASSED}" "${FAILED}"
if (( FAILED > 0 )); then
  exit 1
fi
exit 0
