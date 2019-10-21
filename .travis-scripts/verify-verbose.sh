#!/bin/bash
#
# Verify that PROPCHECK_VERBOSE works as intended.
#

search_for="OK: Passed 100 test(s)"
no_global_verbose=$(mix test test/verify_verbose_test.exs)
global_quiet=$(PROPCHECK_VERBOSE=0 mix test test/verify_verbose_test.exs)
global_verbose=$(PROPCHECK_VERBOSE=1 mix test test/verify_verbose_test.exs)

count_output_no_global_verbose=$(echo "$no_global_verbose" | grep -c "$search_for")
count_output_global_quiet=$(echo "$global_quiet" | grep -c "$search_for")
count_output_global_verbose=$(echo "$global_verbose" | grep -c "$search_for")

if [ "$count_output_no_global_verbose" -ne 1 ]; then
    echo >&2 "Found '$search_for' more than once when it should exist only once"
    echo >&2 "Output:"
    echo >&2 "$no_global_verbose"
    exit 1
fi

if [ "$count_output_global_quiet" -ne 0 ]; then
    echo >&2 "Found '$search_for' when it should be quiet"
    echo >&2 "Output:"
    echo >&2 "$global_quiet"
    exit 2
fi

if [ "$count_output_global_verbose" -ne 2 ]; then
    echo >&2 "Found '$search_for' only $count_output_global_verbose times when it should be 2"
    echo >&2 "Output:"
    echo >&2 "$global_verbose"
    exit 3
fi
