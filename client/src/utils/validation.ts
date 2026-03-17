import { CityPhase, ObjectType, ProposalType } from '../types';
import { TERRITORY_STAKES, OBJECT_STAKES } from '../constants/stakes';

const VALID_PHASES: CityPhase[] = ['genesis', 'settlement', 'village', 'town', 'city', 'metropolis'];

const VALID_OBJECT_TYPES: ObjectType[] = [
  'item', 'waypoint', 'agent', 'billboard', 'rare', 'epic', 'legendary',
];

const VALID_PROPOSAL_TYPES: ProposalType[] = [
  'parameter_change', 'contract_upgrade', 'treasury_spend', 'constitutional', 'emergency',
];

export function isValidPhase(phase: string): phase is CityPhase {
  return VALID_PHASES.includes(phase as CityPhase);
}

export function isValidObjectType(type: string): type is ObjectType {
  return VALID_OBJECT_TYPES.includes(type as ObjectType);
}

export function isValidProposalType(type: string): type is ProposalType {
  return VALID_PROPOSAL_TYPES.includes(type as ProposalType);
}

export function isValidCityName(name: string): boolean {
  return name.length > 0 && name.length <= 50;
}

export function isValidDescription(description: string): boolean {
  return description.length <= 500;
}

export function isValidPubkey(pubkey: string): boolean {
  return /^[0-9a-fA-F]{66}$/.test(pubkey) || pubkey.length > 0;
}

export function isValidStakeForCity(amount: number): boolean {
  return amount >= TERRITORY_STAKES.CITY;
}

export function isValidStakeForBuilding(amount: number): boolean {
  return amount >= TERRITORY_STAKES.BUILDING;
}

export function isValidStakeForHome(amount: number): boolean {
  return amount >= TERRITORY_STAKES.HOME;
}

export function isValidObjectStake(objectType: ObjectType, amount: number): boolean {
  switch (objectType) {
    case 'item':      return amount >= OBJECT_STAKES.ITEM;
    case 'waypoint':  return amount >= OBJECT_STAKES.WAYPOINT_MIN;
    case 'agent':     return amount >= OBJECT_STAKES.AGENT_MIN;
    case 'billboard': return amount >= OBJECT_STAKES.BILLBOARD_MIN;
    case 'rare':      return amount >= OBJECT_STAKES.RARE;
    case 'epic':      return amount >= OBJECT_STAKES.EPIC;
    case 'legendary': return amount >= OBJECT_STAKES.LEGENDARY;
  }
}
