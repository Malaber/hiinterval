#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd "$(dirname "$0")/.." && pwd)
coverage_dir="$package_dir/coverage"
minimum_coverage=${HIINTERVAL_COVERAGE_MINIMUM:-99}

mkdir -p "$coverage_dir" "$package_dir/.clang-module-cache"
rm -f \
  "$coverage_dir/coverage.json" \
  "$coverage_dir/coverage.lcov" \
  "$coverage_dir/report.txt" \
  "$coverage_dir/summary.txt"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$package_dir/.clang-module-cache}"

swift test \
  --package-path "$package_dir" \
  --enable-code-coverage

profdata=$(find "$package_dir/.build" -name default.profdata -type f -print | sort | head -n 1)
if [[ -z "$profdata" ]]; then
  echo "Coverage profile not found" >&2
  exit 1
fi

binary=$(find "$package_dir/.build" -type f \( \
  -name 'HiIntervalIOSPackageTests.xctest' -o \
  -path '*/HiIntervalIOSPackageTests.xctest/Contents/MacOS/HiIntervalIOSPackageTests' \
\) -print | sort | head -n 1)
if [[ -z "$binary" ]]; then
  echo "HiIntervalIOSPackageTests executable not found" >&2
  exit 1
fi

llvm_cov=(llvm-cov)
if ! command -v llvm-cov >/dev/null 2>&1; then
  llvm_cov=(xcrun llvm-cov)
fi

ignore_regex='(/Tests/|/.build/)'
"${llvm_cov[@]}" export \
  "$binary" \
  -instr-profile "$profdata" \
  -ignore-filename-regex="$ignore_regex" \
  > "$coverage_dir/coverage.json"
"${llvm_cov[@]}" export \
  "$binary" \
  -instr-profile "$profdata" \
  -ignore-filename-regex="$ignore_regex" \
  -format=lcov \
  > "$coverage_dir/coverage.lcov"
"${llvm_cov[@]}" report \
  "$binary" \
  -instr-profile "$profdata" \
  -ignore-filename-regex="$ignore_regex" \
  > "$coverage_dir/report.txt"

swift "$package_dir/Scripts/coverage_gate.swift" \
  "$coverage_dir/coverage.json" \
  "$minimum_coverage" \
  | tee "$coverage_dir/summary.txt"
