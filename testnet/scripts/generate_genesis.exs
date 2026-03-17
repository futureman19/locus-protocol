{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [
      fixtures_dir: :string,
      output: :string,
      scenario_output: :string,
      validation_output: :string
    ]
  )

fixtures_dir =
  opts[:fixtures_dir] || Path.expand("../fixtures", Path.dirname(__ENV__.file))

script_dir = Path.dirname(__ENV__.file)
output = Path.expand(opts[:output] || "../runtime/genesis.json", script_dir)
scenario_output =
  Path.expand(opts[:scenario_output] || "../runtime/scenario.json", script_dir)

validation_output =
  Path.expand(opts[:validation_output] || "../runtime/validation.json", script_dir)

scenario = Locus.Testnet.build_scenario!(fixtures_dir: fixtures_dir)
genesis = Locus.Testnet.render_genesis_config(scenario)

Locus.Testnet.write_json!(scenario_output, scenario)
Locus.Testnet.write_json!(validation_output, scenario.validation)
Locus.Testnet.write_json!(output, genesis)

IO.puts(
  Jason.encode!(%{
    genesis_path: output,
    scenario_path: scenario_output,
    validation_path: validation_output,
    validation_passed: scenario.validation.passed
  })
)
