/**
 * ARC broadcaster for transaction submission
 */

import {
  Transaction,
  ARC
} from '@bsv/sdk';

import {
  Network,
  ARCConfig,
  ARCBroadcastResult
} from './types';

import {
  ARC_ENDPOINTS
} from './constants';

export class ARCBroadcaster {
  private config: ARCConfig;
  private arc: ARC;

  constructor(config: Partial<ARCConfig> = {}) {
    this.config = {
      endpoint: config.endpoint || ARC_ENDPOINTS.TESTNET,
      apiKey: config.apiKey
    };

    this.arc = new ARC(this.config.endpoint, this.config.apiKey);
  }

  /**
   * Broadcast a transaction to the BSV network
   */
  async broadcast(tx: Transaction): Promise<ARCBroadcastResult> {
    try {
      const txHex = tx.toString();
      
      const response = await this.arc.broadcast({
        rawTx: txHex,
        waitForStatus: 'MINED' // or 'SENT' for faster response
      });

      return {
        txid: response.txid || '',
        txStatus: response.status || 'UNKNOWN',
        blockHash: response.blockHash,
        blockHeight: response.blockHeight
      };
    } catch (error) {
      throw new Error(`Broadcast failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * Get transaction status
   */
  async getStatus(txid: string): Promise<ARCBroadcastResult> {
    try {
      const response = await this.arc.getTxStatus(txid);

      return {
        txid,
        txStatus: response.status || 'UNKNOWN',
        blockHash: response.blockHash,
        blockHeight: response.blockHeight
      };
    } catch (error) {
      throw new Error(`Status check failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * Get current blockchain height
   */
  async getHeight(): Promise<number> {
    try {
      // Query ARC for chain tip
      const response = await fetch(`${this.config.endpoint}/v1/chain/height`, {
        headers: this.config.apiKey ? { 'Authorization': `Bearer ${this.config.apiKey}` } : {}
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();
      return data.height || 0;
    } catch (error) {
      console.warn('Failed to get height from ARC:', error);
      return 0;
    }
  }
}
