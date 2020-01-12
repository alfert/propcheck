[
  ~r/\:contract_(supertype|subtype|diff)/,
  {"test/support/sequential_cache.ex", :race_condition},
  ~r/lib\/statem_dsl\.ex\:476\:invalid_contract/,
  {"lib/statem_dsl.ex", :pattern_match}
]
