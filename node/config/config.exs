import Config

config :locus,
  network: :testnet,
  node_name: "locus-testnet-node",
  genesis_config_path: "",
  metrics_output_path: "",
  http_enabled: true,
  http_host: "0.0.0.0",
  http_port: 4100,
  arc_endpoint: "https://arc.gorillapool.io",
  arc_api_key: "",
  # SECURITY: Network whitelist for peer connections
  # Comma-separated list of IP addresses or CIDR ranges
  # Empty string allows all (dev mode)
  network_whitelist: System.get_env("LOCUS_NETWORK_WHITELIST", ""),
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
