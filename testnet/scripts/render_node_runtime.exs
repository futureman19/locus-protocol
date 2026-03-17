{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [
      fixtures_dir: :string,
      genesis: :string,
      runtime_dir: :string
    ]
  )

fixtures_dir =
  opts[:fixtures_dir] || Path.expand("../fixtures", Path.dirname(__ENV__.file))

script_dir = Path.dirname(__ENV__.file)

runtime_dir =
  Path.expand(opts[:runtime_dir] || "../runtime/nodes", script_dir)

genesis_path =
  Path.expand(opts[:genesis] || "../runtime/genesis.json", script_dir)

load_json! = fn path ->
  path
  |> File.read!()
  |> Jason.decode!()
end

write_json! = fn path, payload ->
  path
  |> Path.dirname()
  |> File.mkdir_p!()

  File.write!(path, Jason.encode_to_iodata!(payload, pretty: true))
end

topology = load_json!.(Path.join(fixtures_dir, "topology.json"))
network = topology["network"] || "testnet"
arc_endpoint = topology["arc_endpoint"] || "https://arc.gorillapool.io"

nodes =
  Enum.map(topology["nodes"] || [], fn node ->
    node_dir = Path.join(runtime_dir, node["name"])
    File.mkdir_p!(node_dir)

    status_path = Path.join(node_dir, "status.json")
    pid_path = Path.join(node_dir, "node.pid")
    log_path = Path.join(node_dir, "node.log")

    env_lines = [
      "LOCUS_NODE_NAME=#{node["name"]}",
      "LOCUS_NETWORK=#{network}",
      "LOCUS_GENESIS_CONFIG=#{genesis_path}",
      "LOCUS_METRICS_OUTPUT=#{status_path}",
      "LOCUS_HTTP_PORT=#{node["metrics_port"] || 4100}",
      "ARC_ENDPOINT=#{node["arc_endpoint"] || arc_endpoint}"
    ]

    env_path = Path.join(node_dir, "node.env")
    File.write!(env_path, Enum.join(env_lines, "\n") <> "\n")

    metadata = %{
      name: node["name"],
      role: node["role"] || "validator",
      host: node["host"] || "127.0.0.1",
      distribution_name: node["distribution_name"] || node["name"],
      env_path: env_path,
      pid_path: pid_path,
      log_path: log_path,
      status_path: status_path
    }

    write_json!.(Path.join(node_dir, "metadata.json"), metadata)
    metadata
  end)

write_json!.(Path.join(runtime_dir, "nodes.json"), %{nodes: nodes})

IO.puts(Jason.encode!(%{runtime_dir: runtime_dir, nodes: Enum.map(nodes, & &1.name)}))
