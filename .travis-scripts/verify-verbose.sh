#!/bin/bash
#
# Verify that PROPCHECK_VERBOSE works as intended.
#

search_for="Passed 100 test(s)"
quiet=$(mix test test/verify_verbose_test.exs)
verbose=$(PROPCHECK_VERBOSE=1 mix test test/verify_verbose_test.exs)

if echo $quiet | grep "$search_for" -q; then
    echo >&2 "Found '$search_for' when it should be quiet"
    echo >&2 "Output:"
    echo >&2 $quiet
    exit 1
fi

if ! echo $verbose | grep "$search_for" -q; then
    echo >&2 "Did not find '$search_for' when it should be verbose"
    echo >&2 "Output:"
    echo >&2 $verbose
    exit 2
fi
