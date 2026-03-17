import { CityPhase, GovernanceType } from '../types';

/**
 * Fibonacci sequence calculations for city block unlocking.
 *
 * Per spec 02-city-lifecycle.md:
 * - Blocks unlock based on CITIZEN COUNT
 * - Sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34...
 */

/** Returns the first n Fibonacci numbers. */
export function sequence(n: number): number[] {
  if (n <= 0) return [];
  if (n === 1) return [1];
  if (n === 2) return [1, 1];

  const result = [1, 1];
  for (let i = 2; i < n; i++) {
    result.push(result[i - 1] + result[i - 2]);
  }
  return result;
}

/** Returns the sum of the first n Fibonacci numbers. */
export function sumUpTo(n: number): number {
  return sequence(n).reduce((a, b) => a + b, 0);
}

/**
 * Returns the number of /16 blocks unlocked for a given citizen count.
 *
 * Per spec 02-city-lifecycle.md:
 * | Citizens | Blocks | Phase       |
 * |----------|--------|-------------|
 * | 1        | 2      | Genesis     |
 * | 2-3      | 2      | Settlement  |
 * | 4-8      | 5      | Village     |
 * | 9-20     | 8      | Town        |
 * | 21-50    | 16     | City        |
 * | 51+      | 24     | Metropolis  |
 */
export function blocksForCitizens(citizenCount: number): number {
  if (citizenCount >= 51) return 24;
  if (citizenCount >= 21) return 16;
  if (citizenCount >= 9) return 8;
  if (citizenCount >= 4) return 5;
  if (citizenCount >= 1) return 2;
  return 0;
}

/**
 * Returns the city phase based on citizen count.
 *
 * Per spec 02-city-lifecycle.md:
 * - Phase 0 Genesis:    1 citizen
 * - Phase 1 Settlement: 2-3 citizens
 * - Phase 2 Village:    4-8 citizens
 * - Phase 3 Town:       9-20 citizens
 * - Phase 4 City:       21-50 citizens
 * - Phase 5 Metropolis: 51+ citizens
 */
export function phaseForCitizens(citizenCount: number): CityPhase | 'none' {
  if (citizenCount >= 51) return 'metropolis';
  if (citizenCount >= 21) return 'city';
  if (citizenCount >= 9) return 'town';
  if (citizenCount >= 4) return 'village';
  if (citizenCount >= 2) return 'settlement';
  if (citizenCount >= 1) return 'genesis';
  return 'none';
}

/**
 * Returns the governance type for a given phase.
 *
 * Per spec 02-city-lifecycle.md:
 * - Genesis/Settlement: Founder
 * - Village:            Tribal Council
 * - Town:               Republic
 * - City:               Direct Democracy
 * - Metropolis:          Senate
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
  }
}

/** Returns the phase number (0-5) for a phase name. */
export function phaseNumber(phase: CityPhase): number {
  const phases: CityPhase[] = ['genesis', 'settlement', 'village', 'town', 'city', 'metropolis'];
  return phases.indexOf(phase);
}
