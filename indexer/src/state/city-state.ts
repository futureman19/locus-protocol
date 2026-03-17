export type CityPhase = 'none' | 'genesis' | 'settlement' | 'village' | 'town' | 'city' | 'metropolis';
export type GovernanceType = 'founder' | 'tribal_council' | 'republic' | 'direct_democracy' | 'senate';

/**
 * How many /16 blocks are unlocked for a given citizen count.
 * Mirrors client/src/utils/fibonacci.ts → blocksForCitizens
 *
 * Per spec 02-city-lifecycle.md:
 * | Citizens | Blocks |
 * |----------|--------|
 * | 1-3      | 2      |
 * | 4-8      | 5      |
 * | 9-20     | 8      |
 * | 21-50    | 16     |
 * | 51+      | 24     |
 */
export function blocksForCitizens(citizens: number): number {
  if (citizens >= 51) return 24;
  if (citizens >= 21) return 16;
  if (citizens >= 9) return 8;
  if (citizens >= 4) return 5;
  if (citizens >= 1) return 2;
  return 0;
}

/**
 * Determine city phase from citizen count.
 */
export function phaseForCitizens(citizens: number): CityPhase {
  if (citizens <= 0) return 'none';
  if (citizens <= 1) return 'genesis';
  if (citizens <= 3) return 'settlement';
  if (citizens <= 8) return 'village';
  if (citizens <= 20) return 'town';
  if (citizens <= 50) return 'city';
  return 'metropolis';
}

/**
 * Governance type for a given phase.
 */
export function governanceForPhase(phase: CityPhase): GovernanceType {
  switch (phase) {
    case 'genesis':
    case 'settlement':
      return 'founder';
    case 'village':
      return 'tribal_council';
    case 'town':
      return 'republic';
    case 'city':
      return 'direct_democracy';
    case 'metropolis':
      return 'senate';
    default:
      return 'founder';
  }
}

/**
 * Whether UBI is active for a given phase.
 */
export function isUBIActive(phase: CityPhase): boolean {
  return phase === 'city' || phase === 'metropolis';
}

/**
 * Calculate daily UBI per citizen in satoshis.
 */
export function calculateDailyUBI(treasurySats: number, citizenCount: number): number {
  if (citizenCount <= 0) return 0;
  return Math.floor((treasurySats * 0.001) / citizenCount);
}
