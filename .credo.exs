%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"]
      },
      strict: true,
      color: true,
      tools: [
        {Credo.Check.Readability.MaxLineLength, [max_length: 100]}
      ]
    }
  ]
}
