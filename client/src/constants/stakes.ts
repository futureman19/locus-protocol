// All values in satoshis (1 BSV = 100,000,000 sats)

// Territory stake requirements per spec 01-territory-hierarchy.md
export const TERRITORY_STAKES = {
  CITY: 3_200_000_000,           // /32 — 32 BSV
  BLOCK_PRIVATE: 800_000_000,    // /16 — 8 BSV
  BUILDING: 800_000_000,         // /8  — 8 BSV
  HOME: 400_000_000,             // /4  — 4 BSV
} as const;

// Object stake requirements per spec 01-territory-hierarchy.md
export const OBJECT_STAKES = {
  ITEM: 10_000,                  // 0.0001 BSV
  WAYPOINT_MIN: 50_000_000,      // 0.5 BSV
  WAYPOINT_MAX: 400_000_000,     // 4 BSV
  AGENT_MIN: 10_000_000,         // 0.1 BSV
  AGENT_MAX: 400_000_000,        // 4 BSV
  BILLBOARD_MIN: 1_000_000_000,  // 10 BSV
  BILLBOARD_MAX: 10_000_000_000, // 100 BSV
  RARE: 1_600_000_000,           // 16 BSV
  EPIC: 3_200_000_000,           // 32 BSV
  LEGENDARY: 6_400_000_000,      // 64 BSV
} as const;

// Token distribution per spec 03-staking-economics.md
export const TOKEN_DISTRIBUTION = {
  TOTAL_SUPPLY: 3_200_000,
  FOUNDER: 640_000,         // 20%
  TREASURY: 1_600_000,      // 50%
  PUBLIC_SALE: 800_000,      // 25%
  PROTOCOL_DEV: 160_000,    // 5%
  FOUNDER_VEST_MONTHS: 12,
  DEV_VEST_MONTHS: 24,
} as const;

// Lock period per spec 03-staking-economics.md
export const LOCK_PERIOD_BLOCKS = 21_600; // ~5 months

// Emergency unlock per spec 03-staking-economics.md
export const EMERGENCY_PENALTY_RATE = 0.10; // 10% to protocol treasury

// Fee distribution per spec 01-territory-hierarchy.md
export const FEE_DISTRIBUTION = {
  DEVELOPER: 0.50,   // 50%
  TERRITORY: 0.40,   // 40%
  PROTOCOL: 0.10,    // 10%
} as const;

// Territory sub-split (of the 40% territory share)
export const TERRITORY_FEE_SPLIT = {
  BUILDING: 0.50,    // 50% of territory share → building owner
  CITY: 0.30,        // 30% → city treasury
  BLOCK: 0.20,       // 20% → block owner
} as const;

// UBI parameters per spec 03-staking-economics.md
export const UBI = {
  RATE: 0.001,
  MONTHLY_CAP_RATE: 0.01,
  MIN_TREASURY_SATS: 10_000_000_000, // 100 BSV
  MIN_PHASE: 'city' as const,        // Phase 4 (21+ citizens)
} as const;

// Governance per spec 04-governance.md
export const GOVERNANCE = {
  PROPOSAL_DEPOSIT: 10_000_000,       // 0.1 BSV
  DISCUSSION_PERIOD_BLOCKS: 1_008,    // ~7 days
  VOTING_PERIOD_BLOCKS: 2_016,        // ~14 days
  EXECUTION_DELAY_BLOCKS: 432,        // ~3 days
  GENESIS_KEY_EXPIRY_BLOCK: 2_100_000,
} as const;

// Proposal thresholds per spec 04-governance.md
export const PROPOSAL_THRESHOLDS: Record<string, number> = {
  parameter_change: 0.51,
  contract_upgrade: 0.66,
  treasury_spend: 0.51,
  constitutional: 0.75,
  emergency: 0.583, // 7/12 Guardian
};

// Quorum per phase per spec 04-governance.md
export const QUORUM_BY_PHASE: Record<string, number> = {
  village: 0.67,
  town: 0.60,
  city: 0.40,
  metropolis: 0.51,
};

// Progressive property tax per spec 03-staking-economics.md
// cost = base * 2^(n-1)
export function progressiveTax(baseCost: number, propertyNumber: number): number {
  return baseCost * Math.pow(2, propertyNumber - 1);
}
