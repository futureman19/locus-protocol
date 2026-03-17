export interface UBIInfo {
  dailyPerCitizen: number;
  monthlyCap: number;
  treasuryBalance: number;
  citizenCount: number;
  isActive: boolean;
  minTreasury: number;
}

export interface UBIClaimParams {
  cityId: string;
  citizenPubkey: string;
  claimPeriods: number;
}

export interface RedemptionInfo {
  rate: number;
  treasuryBsv: number;
  totalSupply: number;
}
