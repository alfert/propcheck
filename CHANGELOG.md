# PropCheck Changelog

## Current Development
* Using OTP 23 with stacktrace by depending on `:proper` from `:master`. Thanks to [@flowerett](https://github.com/flowerett)
## 1.3.0-Development
* Upgrade to Elixir 1.7 as lowest Elixir version, since `get_stacktrace()` is deprecated in Elixir 1.11. Thanks to [@flowerett](https://github.com/flowerett)
* `:iex` is now an extra-application. Thanks to [@ahamez](https://github.com/ahamez) 
* Support for parallel testing of state machines started. Requires also PRs in the upstream 
  PropEr. An upgrade to (the future) PropEr 1.4 will result in better reports. 
## 1.2.2-Development
* Fixes to statemachine reported by [@aherranz](https://github.com/aherranz) and [@devonestes](https://github.com/devonestes) 
* Fixes to the Readme linking by [@oo6](https://github.com/oo6)

## 1.2.1
* Support for Elixir 1.10 in tests
* Refactorings of the statemachine implementation to be closer to PropEr. Thanks to [https://github.com/x4lldux](https://github.com/x4lldux). 
* `property/1 `for marking properties to be implemented in the future. 
   Thanks to [https://github.com/evnu](https://github.com/evnu)
* Prevent crashing if no counter examples was returned in a failing property. 
  Thanks to [https://github.com/evnu](https://github.com/evnu)
* Consistent reporting of Erlang terms in Elixir syntax. Thanks to [https://github.com/x4lldux](https://github.com/x4lldux).
* Enhanced handling and reporting of exception. Thanks to [https://github.com/evnu](https://github.com/evnu)
* Include `credo` in the build. Thanks to [https://github.com/evnu](https://github.com/evnu)
* Fix `PROPCHECK_VERBOSE` to work with `property`
* Allow `PROPCHECK_VERBOSE=0` to make all properties quiet
* GitHub Actions are the new CI environemnt.  Thanks to [https://github.com/evnu](https://github.com/evnu)
* Pinning of variables in `let` allows easier re-use of variables. Thanks to [https://github.com/Ecialo](https://github.com/Ecialo)

## 1.2.0
* Handling of tags corrected. This changes slighty existing the behavior and gives
  reason to introduce a new minor version. 
  Thanks to [https://github.com/evnu](https://github.com/evnu)
* Verbose settings can be configured at the command line via environment variable
  `PROPCHECK_VERBOSE`. Thanks to [https://github.com/evnu](https://github.com/evnu)
* Setting default options to `forall` on module or describe level.
  Thanks to [https://github.com/x4lldux](https://github.com/x4lldux).
* Support for Elixir 1.9 in tests. Thanks to [https://github.com/evnu](https://github.com/evnu)
* Moving back from CircleCI to TravisCI. Thanks to [https://github.com/evnu](https://github.com/evnu)

## 1.1.5
* `:verbose` option is propagated from the property directly to `forall`. 
    Thanks to [https://github.com/evnu](https://github.com/evnu)
* Storing of counter-examples can excluded by tag `:store_counter_example`
    Thanks to [https://github.com/evnu](https://github.com/evnu)
* Improved documentation for longer statemachine runs. Thanks
  to [https://github.com/adkron](https://github.com/adkron)
* Improved error message for missing command in `StateM.DSL`. 
  Thanks to [https://github.com/devonestes](https://github.com/devonestes)
* Introduction of linter `credo` and CircleCi as new CI tool. 
  Thanks to [https://github.com/evnu](https://github.com/evnu)
* `let` syntax is the same now as `forall`.
  Thanks to [https://github.com/evnu](https://github.com/evnu)

## 1.1.4
* Fixes an issue with the setup of regular and targeted properties rendering 1.1.3 unusable
* Enhanced documentation for targeted properties

## 1.1.3
* Better command generator with improved shrinking for complex argument generations.
* Support for map-generator, thanks to [https://github.com/IRog](https://github.com/IRog)
* Support for targeted properties, a new feature of Proper 1.3
* Requires at least Elixir 1.5

## 1.1.2
* Proper v1.3.0 is supported (effectively, all 1.x versions are allowed
  as dependency)

## 1.1.1
* the weight callback for the DSL was incorrectly specified and documented. Thanks
  to [https://github.com/adkron](https://github.com/adkron)

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
  ensure that no other counter examples exist. Thanks to [https://github.com/evnu](https://github.com/evnu)
* tabs vs whitespace corrected for test cases, thanks to [https://github.com/ryanwinchester](https://github.com/ryanwinchester)
* added a hint about stored counterexamples for users, thanks to [https://github.com/evnu](https://github.com/evnu)
* Corrected formatting of markdown for documentation, thanks to https://github.com/zamith


## 1.0.5
* Allows to use `ExUnit` assertions as boolean conditions, thanks to [https://github.com/evnu](https://github.com/evnu)
* `let` and `let_shrink` allow more than two parameters, thanks to [https://github.com/BinaryNoggin](https://github.com/BinaryNoggin)
* Errors, that aren't counter examples, are no longer stored as counter examples,  thanks to [https://github.com/evnu](https://github.com/evnu)
* new feature `sample_shrink`, thanks to [https://github.com/evnu](https://github.com/evnu)
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
* Bugfix for Mix integration in Umbrella projects, thanks to [https://github.com/evnu](https://github.com/evnu)

## 1.0.0
* Counter examples are automatically stored and reapplied until the properties work
  or the counter examples are deleted. See [https://github.com/alfert/propcheck/pull/18](https://github.com/alfert/propcheck/pull/18)
* Mix configuration for counter examples file and for inspecting and cleaning
  counter examples.

## 0.0.2
* Fixed a lot of 1.5 (and 1.4) Elixir warnings thanks to [https://github.com/evnu](https://github.com/evnu)
* Readme additions regarding installation thanks to [https://github.com/evnu](https://github.com/evnu)
* Added more concurrency robustness for the ping pong tests
* Fixed a bug a in the movie server, which did not startup properly.

## 0.0.1
* Initial release
