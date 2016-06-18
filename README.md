# PropCheck - Property based testing for Elixir

`PropCheck` is a testing library, that provides a wrapper around PropEr, an Erlang
based property testing framework in the spirit of QuickCheck. This project
is derived from ProperEx, but is mostly completely rewritten.

## Links to other documentation

The guides for PropEr are an essential set of documents to make use of `PropCheck`

* http://proper.softlab.ntua.gr/index.html
* http://proper.softlab.ntua.gr/Tutorials/

Elixir versions of most of PropEr's tutorial material can be found in the
test folder (https://github.com/alfert/propcheck/tree/master/test).

Jesper Andersen and Robert Aloi blog about their thoughts and experience on
using QuickCheck which are directly transferable to PropCheck:  

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
is not that bad.

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
