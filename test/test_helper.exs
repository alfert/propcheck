ExUnit.start()
ExUnit.configure(exclude: [will_fail: true, unstable_test: true, manual: true,
                           not_implemented: true, concurrency_test: true])
