# PropCheck - Property based testing for Elixir

`PropCheck` is a testing library, that provides a wrapper around PropEr, an Erlang
based property testing framework in the spirit of QuickCheck. This project
is derived from ProperEx, but is mostly completely rewritten.

[![Build Status](https://travis-ci.org/alfert/propcheck.svg?branch=master)](https://travis-ci.org/alfert/propcheck)
[![Hex.pm version](https://img.shields.io/hexpm/v/propcheck.svg)](https://hex.pm/packages/propcheck)

## Installation
To use PropCheck with your project, add it as a dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:propcheck, "~> 1.1", only: :test}
  ]
end
```

## Changes

Relevant changes are document in the [Changelog](CHANGELOG.html).

## Basic Usage and Build Configuration
PropCheck allows to define properties, which automatically executed via `ExUnit`
when running `mix test`. You find relevant information here:

* details about the `property` macro are found in `PropCheck.Properties`,  
* details about how to specify the property conditions are documented in
  `PropCheck`,
* the basic data generators are found in `PropCheck.BasicTypes`,
* for property testing of state-based systems take a loot at `PropCheck.StateM.DSL`
  for the new DSL (since Propcheck 1.1.0-rc1), which is a layer on top of
  `PropCheck.StateM`.

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
independent from the build environment, in the file `propcheck.ctex`.


## Links to other documentation

The guides for PropEr are an essential set of documents to make full use of `PropCheck`

* [PropEr Home Page](http://proper.softlab.ntua.gr/index.html)
* [PropEr Tutorials](http://proper.softlab.ntua.gr/Tutorials/)

Elixir versions of most of PropEr's tutorial material can be found in the
[test folder on GitHub](https://github.com/alfert/propcheck/tree/master/test).

Jesper Andersen and Robert Aloi blog about their thoughts and experience on
using QuickCheck which are (mostly) directly transferable to PropCheck (with
the notable exception of concurrency and the new state machine DSL from
QuickCheck with the possibility to add requirement tags):

* [Jesper Andersen's QuickCheck Advice](https://medium.com/@jlouis666/quickcheck-advice-c357efb4e7e6#.b9wpla7oi)
* [Jesper Andersen's Breaking Erlang Maps (4 part series)](https://medium.com/@jlouis666/breaking-erlang-maps-4-4ebc3c64068c#.4d61kua92)
* [Roberto Aloi's Notes on Erlang Quickcheck](http://roberto-aloi.com/erlang/notes-on-erlang-quickcheck)

A rather new introductory resource is

* [Fred Hebert's PropEr Testing](http://propertesting.com).

It is again concerned with
Erlang,  it is very well written and translates easily into Elixir (beside
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
