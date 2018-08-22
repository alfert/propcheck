# PropCheck Changelog

## 1.1.2
* Proper v1.3.0 is supported (effectively, all 1.x versions are allowed
  as depedency)

## 1.1.1
* the weight callback for the DSL was incorrectly specified and documented. Thanks
  to https://github.com/adkron 

## 1.1.0
* New command oriented DSL for testing stateful systems, inspired by EQC and
  discussions about stateful testing in StreamData
* More details regarding licensing
* Rerun of properties fixed
* Better and corrected type specs, compatible with dialyxir 1.0.0(-rc*)
* Old modules for automatic type generators removed. They were never completed and
  since 2016 no longer part of the API (i.e. even before release 0.0.1).

## 1.0.6
* After a counter example is resolved, the entire property is run again to
  ensure that no other counter examples exist. Thanks to https://github.com/evnu
* tabs vs whitespace corrected for test cases, thanks to https://github.com/ryanwinchester
* added a hint about stored counterexamples for users, thanks to https://github.com/evnu
* Corrected formatting of markdown for documentation, thanks to https://github.com/zamith


## 1.0.5
* Allows to use `ExUnit` assertions as boolean conditions, thanks to https://github.com/evnu
* `let` and `let_shrink` allow more than two parameters, thanks to https://github.com/BinaryNoggin
* Errors, that aren't counter examples, are no longer stored as counter examples,  thanks to https://github.com/evnu
* new feature `sample_shrink`, thanks to https://github.com/evnu
* the examples for stateful testing use `GenServer.stop/0` for a reliable
  stopping of gen servers.
* several documentation issues

## 1.0.4
* `produce` has now a valid default parameter
* Removed several lazy compiler warnings
* Link in README corrected.

## 1.0.3
* Removed debug log output.

## 1.0.2
* only labeled, never released...

## 1.0.1
* Bugfix for Mix integration in Umbrella projects, thanks to https://github.com/evnu

## 1.0.0
* Counter examples are automatically stored and reapplied until the properties work
  or the counter examples are deleted. See https://github.com/alfert/propcheck/pull/18
* Mix configuration for counter examples file and for inspecting and cleaning
  counter examples.

## 0.0.2
* Fixed a lot of 1.5 (and 1.4) Elixir warnings thanks to https://github.com/evnu
* Readme additions regarding installation thanks to https://github.com/evnu
* Added more concurrency robustness for the ping pong tests
* Fixed a bug a in the movie server, which did not startup properly.

## 0.0.1
* Initial release
