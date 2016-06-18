# PropCheck - Property based testing for Elixir

`PropCheck` is a testing library, that provides a wrapper around PropEr, an Erlang
based property testing framework in the spirit of QuickCheck. This project
is derived from ProperEx, but is mostly completely rewritten.

## Links to other documentation

The guides for PropEr are an essential set of documents to make use of `PropCheck`

* http://proper.softlab.ntua.gr/index.html
* http://proper.softlab.ntua.gr/Tutorials/

Elixir versions of most of the tutorial material can be found in the test folder.

Jesper Andersen and Robert Aloi blog about their thoughts and experience on
using QuickCheck which are directly transferable to PropCheck:  

* QuickCheck Advice:  (https://medium.com/@jlouis666/quickcheck-advice-c357efb4e7e6#.b9wpla7oi)
* Breaking Erlang Maps (4 part series):  (https://medium.com/@jlouis666/breaking-erlang-maps-4-4ebc3c64068c#.4d61kua92)
* http://roberto-aloi.com/erlang/notes-on-erlang-quickcheck/


## Contributing

Please use the GitHub issue tracker for

* bug reports and for
* submitting pull requests

## License

PropCheck is provided under the GPL 3 License due to its intimate use of PropEr
(which is licensed under GPL 3). Since PropCheck is a testing framework, the
system under test is not infected by the CopyLeft of GPL, since PropCheck is only
a tool used temporarily during development of the system under test.
