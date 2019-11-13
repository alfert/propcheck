#!/bin/bash
#
# Test that exception detection works as intended.
#

# run tests in order
seed=0

echo "Attempting to detect exceptions"

check() {
  echo -n "PROPCHECK_DETECT_EXCEPTIONS: $PROPCHECK_DETECT_EXCEPTIONS "
  mix propcheck.clean > /dev/null
  fixture=$1
  output=$(mix test --include manual test/verify_exception_detection_test.exs --seed $seed)
  count_detected_exceptions=$(echo "$output" | grep -c "PropCheck detected")
  fixture_count_detected_exceptions=$(grep -c "PropCheck detected" $fixture)
  if [ "$count_detected_exceptions" -lt "$fixture_count_detected_exceptions" ]; then
    echo >&2 "Detected $count_detected_exceptions, but expected to find at least $fixture_count_detected_exceptions"
    exit 1
  fi

  echo -e "\t---> OK"
}

check .travis-fixtures/exception_detection/non_global_detection.output
PROPCHECK_DETECT_EXCEPTIONS=0 check .travis-fixtures/exception_detection/global_disable_detection.output
PROPCHECK_DETECT_EXCEPTIONS= check .travis-fixtures/exception_detection/global_disable_detection.output
PROPCHECK_DETECT_EXCEPTIONS=1 check .travis-fixtures/exception_detection/global_enable_detection.output

exit 0
