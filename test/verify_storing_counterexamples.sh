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

# Verify that counterexamples for failing parallel tests are printed correctly
out=$(mix test --include manual test/broken_ticket_issuer_test.exs --include will_fail:true)
if [ $? -eq 0 ]; then
    echo "$out" | cat
    echo Test succeeded but should fail
    exit 1
else
  if    ! grep -q "Counter-Example is:" <<< "$out" \
     || ! grep -q "Sequential Start:"   <<< "$out" \
     || ! grep -q "Parallel Process 1:" <<< "$out"; then
    echo "$out" | cat
    echo
    echo Test did not print the counter example correctly
    exit 1
  fi
fi

mix test --include manual test/verify_counter_examples_test.exs
