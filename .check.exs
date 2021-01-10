[
  tools: [
    {:compiler, env: %{"MIX_ENV" => "test"}},
    {:dialyzer, false},
    {:doctor, env: %{"MIX_ENV" => "test"}},
    {:ex_doc, env: %{"MIX_ENV" => "test"}},
    {:formatter, env: %{"MIX_ENV" => "test"}},
    {:sobelow, "mix sobelow --exit --skip"}
  ]
]
