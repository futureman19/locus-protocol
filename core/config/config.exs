import Config

config :locus_core,
  network: :testnet,
  arc_endpoint: "https://arc.gorillapool.io",
  arc_api_key: System.get_env("ARC_API_KEY", ""),

  # Staking (per spec 03-staking-economics.md)
  lock_period_blocks: 21_600,
  emergency_penalty_rate: 0.10,

  # Governance (per spec 04-governance.md)
  proposal_deposit: 10_000_000,
  genesis_key_expiry_block: 2_100_000,
  discussion_period_blocks: 1_008,
  voting_period_blocks: 2_016,
  execution_delay_blocks: 432,

  # UBI (per spec 03-staking-economics.md)
  ubi_rate: 0.001,
  ubi_monthly_cap_rate: 0.01,
  min_treasury_for_ubi: 10_000_000_000,

  # Fee distribution (per spec 01-territory-hierarchy.md)
  fee_developer: 0.50,
  fee_territory: 0.40,
  fee_protocol: 0.10

config :logger,
  level: :info,
  backends: [:console]
