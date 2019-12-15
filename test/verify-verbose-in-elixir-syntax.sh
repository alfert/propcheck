#!/bin/bash
#
# Test that verbose output is printed in Elixir syntax.
#

# run tests in order
seed=0

elixir_syntax_output=$(PROPCHECK_VERBOSE=1 mix test --include manual --include will_fail test/verify_verbose_elixir_syntax_test.exs --seed $seed)

# linked process crashes
expected1='A linked process died with reason: an exception was raised:'
expected2='** (ArithmeticError) bad argument in arithmetic expression'
if ! echo "$elixir_syntax_output" | grep -FA1 "$expected1" | grep -qF "$expected2"; then
    echo >&2 "Crash report from linked process not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi

# linked process kills it self
expected='A linked process died with reason :killed.'
if ! echo "$elixir_syntax_output" | grep -qF "$expected"; then
    echo >&2 "Crash report from linked process not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi

# collect prints Elixir syntax
expected='100% %{test: VerifyVerboseElixirSyntaxTest}'
if ! echo "$elixir_syntax_output" | grep -qF "$expected"; then
    echo >&2 "Collected categories not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi

# exception was raised on test crash
expected1='An exception was raised:'
expected2='** (RuntimeError) test crash'
if ! echo "$elixir_syntax_output" | grep -FA1 "$expected1" | grep -qF "$expected2"; then
    echo >&2 "Raised exception on test crash not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi


# exception was raised with stacktrace
expected1='Stacktrace:'
expected2='    test/verify_verbose_elixir_syntax_test.exs:'
if ! echo "$elixir_syntax_output" | grep -FA1 "$expected1" | grep -qF "$expected2"; then
    echo >&2 "Raised exception with stacktrace not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi
