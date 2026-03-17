import { Network, ARCConfig } from '../types';

export const ARC_ENDPOINTS: Record<Network, string> = {
  mainnet: 'https://arc.taal.com',
  testnet: 'https://arc.gorillapool.io',
  stn: 'https://arc.stn.gorillapool.io',
};

export function getARCConfig(network: Network, apiKey?: string): ARCConfig {
  return {
    endpoint: ARC_ENDPOINTS[network],
    apiKey,
  };
}
