import Config

config :locus_core,
  network: :testnet,
  arc_endpoint: "https://arc.gorillapool.io",
  arc_api_key: System.get_env("ARC_API_KEY", ""),

  # Territory
  territory_levels: [:world, :continent, :country, :region, :city, :district, :block],

  # Staking
  lock_period_blocks: 21_600,
  min_founding_stake: 1_000_000,
  emergency_unlock_penalty: 0.50,

  # Fibonacci base multiplier (blocks per Fibonacci unit)
  fibonacci_base_blocks: 144,

  # UBI
  ubi_rate: 0.001,

  # Governance
  proposal_duration_blocks: 4_320,
  federal_transition_citizens: 21,
  quorum_percentage: 0.51

config :logger,
  level: :info,
  backends: [:console]
