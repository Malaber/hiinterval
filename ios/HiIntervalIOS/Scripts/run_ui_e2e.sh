#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$package_dir/../.." && pwd)
device_name=${1:-"iPhone 17 Pro"}
artifact_dir=${2:-"e2e-artifacts/ios-iphone"}
only_testing=${3:-"HiIntervalUITests"}
attempts=${HIINTERVAL_E2E_ATTEMPTS:-2}

if [[ "$artifact_dir" = /* ]]; then
  artifact_candidate="$artifact_dir"
else
  artifact_candidate="$repo_dir/$artifact_dir"
fi
artifact_path=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' \
  "$artifact_candidate")
case "$artifact_path" in
  "$repo_dir/e2e-artifacts/"*) ;;
  *)
    echo "Artifact directory must be a child of $repo_dir/e2e-artifacts" >&2
    exit 2
    ;;
esac

safe_device=$(printf '%s' "$device_name" | tr -cs '[:alnum:]' '-')
derived_data="$package_dir/.derived-e2e-$safe_device"
result_bundle="$artifact_path/TestResults.xcresult"
summary_path="$artifact_path/summary.md"
simulator_inventory="$artifact_path/simulators.json"

rm -rf "$artifact_path" "$derived_data"
mkdir -p "$artifact_path" "$package_dir/.clang-module-cache"
cleanup() {
  if [[ -n "${device_udid:-}" ]]; then
    xcrun simctl shutdown "$device_udid" >/dev/null 2>&1 || true
  fi
  rm -rf "$derived_data"
}
trap cleanup EXIT

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$package_dir/.clang-module-cache}"
export HIINTERVAL_UI_TEST_ARTIFACT_DIR="$artifact_path"

xcrun simctl list devices available -j > "$simulator_inventory"
device_udid=$(python3 "$package_dir/Scripts/resolve_simulator.py" \
  "$simulator_inventory" \
  "$device_name")

cd "$package_dir"
xcodegen generate

build_log="$artifact_path/build-for-testing.log"
set +e
xcodebuild \
  -project HiIntervalApp.xcodeproj \
  -scheme HiInterval \
  -derivedDataPath "$derived_data" \
  -destination "platform=iOS Simulator,id=$device_udid" \
  -destination-timeout 120 \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:"$only_testing" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing \
  2>&1 | tee "$build_log"
build_status=${PIPESTATUS[0]}
set -e
if [[ "$build_status" -ne 0 ]]; then
  {
    echo "# HiInterval UI e2e"
    echo
    echo "- Device: \`$device_name\`"
    echo "- Result: build failed"
  } > "$summary_path"
  exit "$build_status"
fi

test_status=1
used_attempts=0
test_selections=("$only_testing")
for ((attempt = 1; attempt <= attempts; attempt++)); do
  used_attempts=$attempt
  rm -rf "$result_bundle"
  xcrun simctl shutdown "$device_udid" >/dev/null 2>&1 || true
  xcrun simctl boot "$device_udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_udid" -b
  xcrun simctl ui "$device_udid" appearance light
  xcrun simctl uninstall "$device_udid" de.malaber.hiinterval >/dev/null 2>&1 || true

  test_log="$artifact_path/test-attempt-$attempt.log"
  only_testing_args=()
  for selection in "${test_selections[@]}"; do
    only_testing_args+=("-only-testing:$selection")
  done
  set +e
  xcodebuild \
    -project HiIntervalApp.xcodeproj \
    -scheme HiInterval \
    -derivedDataPath "$derived_data" \
    -destination "platform=iOS Simulator,id=$device_udid" \
    -destination-timeout 120 \
    -resultBundlePath "$result_bundle" \
    -parallel-testing-enabled NO \
    -maximum-parallel-testing-workers 1 \
    "${only_testing_args[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    test-without-building \
    2>&1 | tee "$test_log"
  test_status=${PIPESTATUS[0]}
  set -e

  if [[ "$test_status" -eq 0 ]]; then
    break
  fi
  if [[ "$attempt" -lt "$attempts" ]]; then
    if [[ -d "$result_bundle" ]]; then
      mv "$result_bundle" "$artifact_path/TestResults-attempt-$attempt.xcresult"
    fi
    failed_tests=()
    while IFS= read -r failed_test; do
      if [[ -n "$failed_test" ]]; then
        failed_tests+=("$failed_test")
      fi
    done < <(
      sed -nE \
        "s/^Test Case '-\[([^.]*)\.([^ ]+) ([^]]+)\]' failed.*/\1\/\2\/\3/p" \
        "$test_log"
    )
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
      test_selections=("${failed_tests[@]}")
      echo "Retrying failed UI tests ($attempt/$attempts): ${test_selections[*]}"
    else
      test_selections=("$only_testing")
      echo "Retrying full isolated UI test run ($attempt/$attempts)..."
    fi
  fi
done

result="passed"
if [[ "$test_status" -ne 0 ]]; then
  result="failed"
fi
screenshot_count=$(find "$artifact_path" -maxdepth 1 -type f -name '*.png' -print | wc -l | tr -d ' ')
{
  echo "# HiInterval UI e2e"
  echo
  echo "- Device: \`$device_name\`"
  echo "- Simulator UDID: \`$device_udid\`"
  echo "- Selection: \`$only_testing\`"
  echo "- Result: $result"
  echo "- Attempts: $used_attempts"
  echo "- Screenshots: $screenshot_count"
  echo "- Result bundle: \`TestResults.xcresult\`"
} > "$summary_path"

exit "$test_status"
