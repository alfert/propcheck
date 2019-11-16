#!/bin/sh
#
# Verify that we can configure storing counterexamples
#

mix test --include manual test/store_counter_examples_test.exs --include will_fail:true && exit 1
mix test --include manual test/verify_counter_examples_test.exs
