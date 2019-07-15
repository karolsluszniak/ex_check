%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"]
      },
      strict: true,
      color: true,
      checks: [
        {Credo.Check.Readability.MaxLineLength, [max_length: 100]}
      ]
    }
  ]
}
