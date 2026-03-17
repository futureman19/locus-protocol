import Config

to_bool = fn
  nil, default -> default
  value, _default -> String.downcase(value) in ["1", "true", "yes", "on"]
end

to_int = fn
  nil, default -> default
  value, default ->
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> default
    end
end

network =
  case System.get_env("LOCUS_NETWORK") do
    nil -> Application.get_env(:locus, :network, :testnet)
    "mainnet" -> :mainnet
    "testnet" -> :testnet
    other -> String.to_atom(other)
  end

config :locus,
  network: network,
  node_name: System.get_env("LOCUS_NODE_NAME", "locus-testnet-node"),
  genesis_config_path: System.get_env("LOCUS_GENESIS_CONFIG", ""),
  metrics_output_path: System.get_env("LOCUS_METRICS_OUTPUT", ""),
  http_enabled: to_bool.(System.get_env("LOCUS_HTTP_ENABLED"), true),
  http_host: System.get_env("LOCUS_HTTP_HOST", "0.0.0.0"),
  http_port: to_int.(System.get_env("LOCUS_HTTP_PORT"), 4100),
  arc_endpoint: System.get_env("ARC_ENDPOINT", "https://arc.gorillapool.io"),
  arc_api_key: System.get_env("ARC_API_KEY", "")

if log_level = System.get_env("LOCUS_LOG_LEVEL") || System.get_env("LOG_LEVEL") do
  normalized_level =
    case String.downcase(log_level) do
      "debug" -> :debug
      "info" -> :info
      "warning" -> :warning
      "error" -> :error
      _ -> :info
    end

  config :logger, level: normalized_level
end
