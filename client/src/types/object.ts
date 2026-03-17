export type ObjectType =
  | 'item'
  | 'waypoint'
  | 'agent'
  | 'billboard'
  | 'rare'
  | 'epic'
  | 'legendary';

export interface LocusObject {
  id: string;
  objectType: ObjectType;
  h3Index: string;
  ownerPubkey: string;
  stakeAmount: number;
  contentHash: string;
  manifestHash?: string;
  parentTerritory: string;
  capabilities: string[];
  createdAt: number;
}

export interface ObjectDeployParams {
  objectType: ObjectType;
  h3Index: string;
  ownerPubkey: string;
  stakeAmount: number;
  contentHash: string;
  manifestHash?: string;
  parentTerritory: string;
  capabilities?: string[];
}

export interface ObjectDestroyParams {
  objectId: string;
  ownerPubkey: string;
  reason?: string;
}
