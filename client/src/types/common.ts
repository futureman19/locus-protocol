export type Network = 'mainnet' | 'testnet' | 'stn';

export interface LatLng {
  lat: number;
  lng: number;
}

export interface H3Location extends LatLng {
  h3Index: string;
}

export interface UTXO {
  txid: string;
  vout: number;
  satoshis: number;
  script: string;
}

export interface ARCConfig {
  endpoint: string;
  apiKey?: string;
}

export interface ARCBroadcastResult {
  txid: string;
  txStatus: string;
  blockHash?: string;
  blockHeight?: number;
}

export interface WalletInterface {
  getPublicKey(): Promise<string>;
  getAddress(): Promise<string>;
  signTransaction(tx: unknown): Promise<unknown>;
  getBalance(): Promise<number>;
  getUTXOs(): Promise<UTXO[]>;
}

export interface LocusClientConfig {
  network?: Network;
  arcEndpoint?: string;
  arcApiKey?: string;
  wallet?: WalletInterface;
}

export interface FeeDistribution {
  developer: number;
  territory: number;
  protocol: number;
}

export interface TerritoryFeeBreakdown {
  building: number;
  city: number;
  block: number;
}
