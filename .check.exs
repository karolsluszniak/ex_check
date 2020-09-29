[
  tools: [
    {:compiler, env: %{"MIX_ENV" => "test"}},
    {:dialyzer, false},
    {:ex_doc, env: %{"MIX_ENV" => "test"}},
    {:formatter, env: %{"MIX_ENV" => "test"}},
    {:sobelow, "mix sobelow --exit --skip"}
  ]
]
