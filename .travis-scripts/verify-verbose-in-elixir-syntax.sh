#!/bin/bash
#
# Test that verbose output is printed in Elixir syntax.
#

# run tests in order
seed=0

elixir_syntax_output=$(mix test --seed 0 test/verify_verbose_elixir_syntax_test.exs)

# linked process crashes
expected='A linked process died with reason: an exception was raised:
** (ArithmeticError) bad argument in arithmetic expression'
if [[ ! $elixir_syntax_output =~ "$expected" ]]; then
    echo >&2 "Crash report from linked process not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi

# linked process kills it self
expected='A linked process died with reason :killed.'
if [[ ! $elixir_syntax_output =~ "$expected" ]]; then
    echo >&2 "Crash report from linked process not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi

# collect prints Elixir syntax
expected='100% %{test: VerifyVerboseElixirSyntaxTest}'
if [[ ! $elixir_syntax_output =~ "$expected" ]]; then
    echo >&2 "Collected categories not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi

# exception was raised with stacktrace
expected='An exception was raised:
** (RuntimeError) test crash
Stacktrace:
    test/verify_verbose_elixir_syntax_test.exs:'
if [[ ! $elixir_syntax_output =~ "$expected" ]]; then
    echo >&2 "Collected categories not found"
    echo >&2 "Output:"
    echo >&2 "$elixir_syntax_output"
    exit 1
fi
