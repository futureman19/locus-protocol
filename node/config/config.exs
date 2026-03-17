import Config

network =
  case System.get_env("LOCUS_NETWORK", "testnet") do
    "mainnet" -> :mainnet
    "testnet" -> :testnet
    other -> String.to_atom(other)
  end

config :locus,
  network: network,
  node_name: System.get_env("LOCUS_NODE_NAME", "locus-testnet-node"),
  genesis_config_path: System.get_env("LOCUS_GENESIS_CONFIG", ""),
  metrics_output_path: System.get_env("LOCUS_METRICS_OUTPUT", ""),
  arc_endpoint: System.get_env("ARC_ENDPOINT", "https://arc.gorillapool.io"),
  arc_api_key: System.get_env("ARC_API_KEY", ""),
  min_stake_greeter: 1_000_000,
  min_stake_oracle: 10_000_000,
  min_stake_guardian: 50_000_000,
  min_stake_merchant: 10_000_000,
  min_stake_custom: 100_000_000,
  lock_period_blocks: 21_600,
  heartbeat_min_interval: 86_400,
  heartbeat_max_interval: 172_800,
  challenge_window: 259_200,
  challenger_stake: 10_000

config :logger,
  level: :info,
  backends: [:console]
