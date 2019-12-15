#!/bin/sh
#
# Verify that we can configure storing counterexamples
#

out=$(mix test --include manual test/store_counter_examples_test.exs --include will_fail:true)
if [ $? -eq 0 ]; then
    echo "$out" | cat
    echo Test succeeded but should fail
    exit 1
fi

mix test --include manual test/verify_counter_examples_test.exs
