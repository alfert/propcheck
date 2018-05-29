# PropCheck Changelog

## 1.06
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
