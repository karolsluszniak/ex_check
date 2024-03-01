ex_doc_config =
  if Version.match?(System.version(), "< 1.10.0") do
    false
  else
    [env: %{"MIX_ENV" => "test"}]
  end

[
  tools: [
    {:compiler, env: %{"MIX_ENV" => "test"}},
    {:dialyzer, false},
    {:doctor, env: %{"MIX_ENV" => "test"}},
    {:ex_doc, ex_doc_config},
    {:formatter, env: %{"MIX_ENV" => "test"}},
    {:mix_audit, env: %{"MIX_ENV" => "test"}},
    {:sobelow, "mix sobelow --exit --skip"},
    {:gettext, false}
  ]
]
