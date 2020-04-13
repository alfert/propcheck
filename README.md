# PropCheck - Property based testing for Elixir

`PropCheck` is a testing library, that provides a wrapper around PropEr, an Erlang
based property testing framework in the spirit of QuickCheck.

[![Build Status](https://travis-ci.org/alfert/propcheck.svg?branch=master)](https://travis-ci.org/alfert/propcheck)
[![Hex.pm version](https://img.shields.io/hexpm/v/propcheck.svg)](https://hex.pm/packages/propcheck)
[![Gitter](https://badges.gitter.im/propcheck/community.svg)](https://gitter.im/propcheck/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
![Elixir CI](https://github.com/alfert/propcheck/workflows/Elixir%20CI/badge.svg)

## Installation
To use PropCheck with your project, add it as a dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:propcheck, "~> 1.1", only: [:test, :dev]}
  ]
end
```

## Changes

Relevant changes are documented in the [Changelog](CHANGELOG.html), on [GitHub  
follow this link](CHANGELOG.md).

## Basic Usage and Build Configuration
PropCheck allows to define properties, which automatically executed via `ExUnit`
when running `mix test`. You find relevant information here:

* details about the `property` macro are found in `PropCheck.Properties`,
* details about how to specify the property conditions are documented in
  `PropCheck`,
* the basic data generators are found in `PropCheck.BasicTypes`,
* for property testing of state-based systems take a loot at
  `PropCheck.StateM.ModelDSL` for the new DSL (since PropCheck 1.1.0-rc1), 
  which is a layer on top of `PropCheck.StateM`.
* The new targeted property based testing approach (TBPT) employing an automated
  search strategy towards more interesting test data is described in
  `PropCheck.TargetedPBT`.

For PropCheck, there is only one configuration option. All counter examples found
are stored in a file, the name of which is configurable in `mix.exs` as part of
the `project` configuration:

```elixir
def project() do
  [ # many other options
    propcheck: [counter_examples: "filename"]
  ]
end
```

Per default, the counter examples file is stored in the build directory (`_build`),
independent from the build environment, in the file `propcheck.ctex`. The file can
be removed using `mix propcheck.clean`. Note that this task is only available if PropCheck
is also available in `:dev`. Otherwise, `MIX_ENV=test mix propcheck.clean` can be used.

### Setting PropCheck into Verbose Mode

Properties in PropCheck can be run in quiet or verbose mode. Usually, quiet is the default. To
enable verbose mode without requiring to touch the source code, the environment variable `PROPCHECK_VERBOSE`
can be used. If this is set to 1, the `forall` macro prints verbose output.

### Detecting Exceptions and Errors in Tests

PropCheck can attempt to detect and output exceptions in non-verbose mode. This can be done using
the `detect_exceptions: true` option for `property` or `forall`, or using the environment variable
`PROPCHECK_DETECT_EXCEPTIONS`. If this environment variable is set to 1, exception detection is enabled
globally.

## Links to other documentation

The guides for PropEr are an essential set of documents to make full use of `PropCheck`

* [PropEr Home Page](https://proper-testing.github.io/index.html)
* [PropEr Tutorials](https://proper-testing.github.io/tutorials.html)

Elixir versions of most of PropEr's tutorial material can be found in the
[test folder on GitHub](https://github.com/alfert/propcheck/tree/master/test).

Jesper Andersen and Robert Aloi blog about their thoughts and experience on
using QuickCheck which are (mostly) directly transferable to PropCheck (with
the notable exception of concurrency and the new state machine DSL from
QuickCheck with the possibility to add requirement tags):

* [Jesper Andersen's QuickCheck Advice](https://medium.com/@jlouis666/quickcheck-advice-c357efb4e7e6#.b9wpla7oi)
* [Jesper Andersen's Breaking Erlang Maps (4 part series)](https://medium.com/@jlouis666/breaking-erlang-maps-4-4ebc3c64068c#.4d61kua92)
* [Roberto Aloi's Notes on Erlang Quickcheck](http://roberto-aloi.com/erlang/notes-on-erlang-quickcheck)

Rather new introductory resources are

* [Fred Hebert's PropEr Testing](http://propertesting.com) and
* Fred Hebert's book [Property-Based Testing With PropEr, Erlang and Elixir](https://pragprog.com/book/fhproper/property-based-testing-with-proper-erlang-and-elixir).
  This book explains the new approach of targeted property based testing (TPBT) very nicely
  and is way more approachable then the scientific papers regarding TPBT. Some of the
  Erlang only examples of the book are ported to Elixir and can be found in the test
  [test folder on GitHub](https://github.com/alfert/propcheck/tree/master/test).

In contrast to the book, the free website is concerned with
Erlang only. The Erlang examples translate easily into Elixir (beside
that at least a reading knowledge of Erlang is extremely helpful to survive
in the BEAM ecosystem ...). Eventually I will port some of the examples to
Elixir and PropCheck and certainly like to accept PRs.

## What is not available

PropCheck does not support PropEr's capability to derive automatically type
generators from type specifications. This is due to some shortcomings in PropEr,
where the specification analysis in certain situation attempt to parse the Erlang source
code of the file with the type specification. Apparently, this fails if the
types are specified in an Elixir source file.

Effectively this means, that to
to support this feature from Elixir, the type management system in PropEr needs
to be rewritten completely. Jesper Andersen argues in his aforementioned blog
post eloquently that automatically derived type generators are not needed, even
more that carefully crafted type generators for specific testing purposes is
an essential part of the QuickCheck philosophy. Therefore, this missing feature
is not that bad. For the same reason, automatic `@spec`-checking is of limited
value in PropCheck since type generators for functions specification are also
generated automatically.

PropCheck has only very limited support for parallel testing since it introduces
no new features for concurrency compared to PropEr.


## Contributing

Please use the GitHub issue tracker for

* bug reports and for
* submitting pull requests

Before submitting a pull request, please use Credo to ensure code consistency
and run `mix tests` to check PropCheck itself. `mix tests` is a Mix alias that
runs regular tests (via `mix test`) and some external tests (via another Mix
alias `mix test_ext`) which test PropCheck's side effects, like storing
counterexamples or proper output format, that can't be easily tested using
regular tests.

## License

PropCheck is provided under the GPL 3 License due to its intimate use of PropEr
(which is licensed under GPL 3). In particular, PropEr's exclusion rule of
open source software from copyleft applies here as well [as described in this discussion on GitHub](https://github.com/proper-testing/proper/issues/29#issuecomment-4956226).

Personally, I would prefer to use the LPGL to differentiate between extending PropEr
and PropCheck as GPL-licensed software and the use of PropEr/PropCheck, which would
not be infected by GPL's copyleft. But as long as PropEr does not change its
licensing, we have no options. PropCheck is clearly an extension of PropEr, so it
is derived work falling under GPL's copyleft. Using LGPL or any other license for
PropCheck will not help, since GPL's copyleft overrules other licenses or result
in an invalid or at least questionable licensing which does not help anybody.

From my understanding of open source licenses as a legal amateur, the situation is
currently as follows: Since PropCheck is a testing framework, the
system under test is not infected by the CopyLeft of GPL, since PropCheck is only
a tool used temporarily during development of the system under test. At least,
if you don't distribute your system together with the test code and the test libs
as a binary. Another friendly approach is
to have the tests in a separate project, such that the tests are a real client
of the system under test. But again, this is my personal take. In question, please
consult a professional legal advisor.
