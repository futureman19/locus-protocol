import Config

config :locus,
  network: :testnet,
  arc_endpoint: "https://arc.gorillapool.io",
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
