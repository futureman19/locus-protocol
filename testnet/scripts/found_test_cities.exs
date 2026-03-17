{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [
      fixtures_dir: :string,
      output: :string,
      validation_output: :string
    ]
  )

fixtures_dir =
  opts[:fixtures_dir] || Path.expand("../fixtures", Path.dirname(__ENV__.file))

scenario = Locus.Testnet.build_scenario!(fixtures_dir: fixtures_dir)

if output = opts[:output] do
  Locus.Testnet.write_json!(Path.expand(output), scenario)
end

if validation_output = opts[:validation_output] do
  Locus.Testnet.write_json!(Path.expand(validation_output), scenario.validation)
end

IO.puts(
  Jason.encode!(%{
    cities: Enum.map(scenario.cities, & &1.slug),
    validation_passed: scenario.validation.passed,
    join_plans: Enum.map(scenario.join_plan_results, & &1.id)
  })
)
