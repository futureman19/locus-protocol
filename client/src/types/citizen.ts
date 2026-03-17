export interface Citizen {
  pubkey: string;
  cityId: string;
  joinedAt: number;
  tokenBalance: number;
  lastHeartbeat?: number;
  territoriesClaimed: number;
}
