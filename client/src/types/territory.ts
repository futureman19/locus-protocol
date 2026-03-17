export type TerritoryLevel = 128 | 64 | 32 | 16 | 8 | 4 | 2 | 1;

export interface Territory {
  id: string;
  level: TerritoryLevel;
  h3Index: string;
  ownerPubkey: string;
  stakeAmount: number;
  lockHeight: number;
  parentCity?: string;
  metadata?: Record<string, unknown>;
  claimedAt: number;
}

export interface TerritoryClaimParams {
  level: TerritoryLevel;
  h3Index: string;
  ownerPubkey: string;
  stakeAmount: number;
  lockHeight: number;
  parentCity?: string;
  metadata?: Record<string, unknown>;
}

export interface TerritoryTransferParams {
  territoryId: string;
  fromPubkey: string;
  toPubkey: string;
  price?: number;
}
