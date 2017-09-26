# PropCheck - Property based testing for Elixir

`PropCheck` is a testing library, that provides a wrapper around PropEr, an Erlang
based property testing framework in the spirit of QuickCheck. This project
is derived from ProperEx, but is mostly completely rewritten.

[![Build Status](https://travis-ci.org/alfert/propcheck.svg?branch=master)](https://travis-ci.org/alfert/propcheck)

## Installation
To use PropCheck with your project, add it as a dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:propcheck, "~> 1.0", only: :test}
  ]
end
```

## Basic Usage and Build Configuration
PropCheck allows to define properties, which automatically executed via `ExUnit`
when running `mix test`. Details about the `property` macro are found in
`PropCheck.Properties`,  details about how to specify the property conditions
are documented in `PropCheck`, the basic data generators are found in
`PropCheck.BasicTypes`.

For PropCheck, there is only one configuration option. All found counter examples
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
independent from the build environment.


## Links to other documentation

The guides for PropEr are an essential set of documents to make full use of `PropCheck`

* http://proper.softlab.ntua.gr/index.html
* http://proper.softlab.ntua.gr/Tutorials/

Elixir versions of most of PropEr's tutorial material can be found in the
test folder (https://github.com/alfert/propcheck/tree/master/test).

Jesper Andersen and Robert Aloi blog about their thoughts and experience on
using QuickCheck which are (mostly) directly transferable to PropCheck (with
the notable exception of concurrency and the new state machine DSL from
QuickCheck with the possibility to add requirement tags):

* [QuickCheck Advice](https://medium.com/@jlouis666/quickcheck-advice-c357efb4e7e6#.b9wpla7oi)
* [Breaking Erlang Maps (4 part series)](https://medium.com/@jlouis666/breaking-erlang-maps-4-4ebc3c64068c#.4d61kua92)
* http://roberto-aloi.com/erlang/notes-on-erlang-quickcheck/

## What is not available

PropCheck does not support PropEr's capability to derive automatically type
generators from type specifications. This is due to some shortcomings in PropEr,
where the specification analysis and the type server storing type definitions
circular dependency and at certain situation attempt to parse the Erlang source
code of the file with the type specification. Apparently, this fails if the
types are specified in an Elixir source file. Effectively this means, that to
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
(which is licensed under GPL 3). Since PropCheck is a testing framework, the
system under test is not infected by the CopyLeft of GPL, since PropCheck is only
a tool used temporarily during development of the system under test.
