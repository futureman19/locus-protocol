/**
 * ARC Broadcaster — broadcast transactions to BSV network via ARC.
 */

import { ARCConfig, ARCBroadcastResult, Network } from './types';
import { ARC_ENDPOINTS } from './constants/networks';

export class ARCBroadcaster {
  private config: ARCConfig;

  constructor(network: Network = 'testnet', apiKey?: string) {
    this.config = {
      endpoint: ARC_ENDPOINTS[network],
      apiKey,
    };
  }

  /** Broadcast a raw transaction hex to the network. */
  async broadcast(txHex: string): Promise<ARCBroadcastResult> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (this.config.apiKey) {
      headers['Authorization'] = `Bearer ${this.config.apiKey}`;
    }

    const response = await fetch(`${this.config.endpoint}/v1/tx`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ rawTx: txHex }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`ARC broadcast failed (${response.status}): ${error}`);
    }

    return response.json() as Promise<ARCBroadcastResult>;
  }

  /** Query transaction status. */
  async getStatus(txid: string): Promise<ARCBroadcastResult> {
    const headers: Record<string, string> = {};
    if (this.config.apiKey) {
      headers['Authorization'] = `Bearer ${this.config.apiKey}`;
    }

    const response = await fetch(`${this.config.endpoint}/v1/tx/${txid}`, {
      headers,
    });

    if (!response.ok) {
      throw new Error(`ARC status query failed (${response.status})`);
    }

    return response.json() as Promise<ARCBroadcastResult>;
  }
}
