/**
 * H3 hex utilities for territory addressing.
 *
 * Uses h3-js for hexagonal hierarchical spatial index.
 * H3 resolutions used per spec 01-territory-hierarchy.md:
 *   /32 City     → H3 Res 7  (~5.1 km²)
 *   /8  Building → H3 Res 9  (~0.1 km²)
 *   /4  Home     → H3 Res 10 (~0.015 km²)
 *   /1  Object   → H3 Res 12 (~0.003 km²)
 */

import { TerritoryLevel } from '../types';

/** Returns the H3 resolution for a given territory level. */
export function h3ResolutionForLevel(level: TerritoryLevel): number {
  switch (level) {
    case 32: return 7;
    case 16: return 8;
    case 8:  return 9;
    case 4:  return 10;
    case 2:  return 11;
    case 1:  return 12;
    default: return 7;
  }
}

/** Validates an H3 index string (basic format check). */
export function isValidH3Index(h3Index: string): boolean {
  return /^[0-9a-fA-F]{15,16}$/.test(h3Index);
}
