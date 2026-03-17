import { H3Location } from './common';

export type CityPhase =
  | 'genesis'
  | 'settlement'
  | 'village'
  | 'town'
  | 'city'
  | 'metropolis';

export type GovernanceType =
  | 'founder'
  | 'tribal_council'
  | 'republic'
  | 'direct_democracy'
  | 'senate';

export interface City {
  id: string;
  name: string;
  description: string;
  location: H3Location;
  founderPubkey: string;
  foundedAt: number;
  phase: CityPhase;
  citizens: string[];
  citizenCount: number;
  treasuryBsv: number;
  tokenSupply: number;
  treasuryTokens: number;
  founderTokensTotal: number;
  policies: CityPolicies;
}

export interface CityPolicies {
  blockAuctionPeriod?: number;
  blockStartingBid?: number;
  immigrationPolicy?: string;
}

export interface CityFoundParams {
  name: string;
  description?: string;
  lat: number;
  lng: number;
  h3Res7: string;
  founderPubkey: string;
  policies?: CityPolicies;
}

export interface CitizenJoinParams {
  cityId: string;
  citizenPubkey: string;
}

export interface TokenDistribution {
  founder: number;
  treasury: number;
  publicSale: number;
  protocolDev: number;
  total: number;
}
