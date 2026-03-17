/**
 * LocusClient — main entry point for the territory-centric Locus Protocol SDK.
 *
 * Cities are the core primitive. Ghosts are just one type of /1 Object.
 */

import { LocusClientConfig, Network } from './types';
import { CityManager } from './modules/city-manager';
import { TerritoryManager } from './modules/territory-manager';
import { ObjectManager } from './modules/object-manager';
import { TreasuryManager } from './modules/treasury-manager';
import { GovernanceManager } from './modules/governance-manager';
import { HeartbeatManager } from './modules/heartbeat-manager';
import { TransactionBuilder } from './modules/transaction-builder';
import { ARCBroadcaster } from './broadcaster';

export class LocusClient {
  readonly network: Network;
  readonly broadcaster: ARCBroadcaster;

  // Manager modules (static, exposed for convenience)
  readonly city = CityManager;
  readonly territory = TerritoryManager;
  readonly objects = ObjectManager;
  readonly treasury = TreasuryManager;
  readonly governance = GovernanceManager;
  readonly heartbeat = HeartbeatManager;
  readonly tx = TransactionBuilder;

  constructor(config: LocusClientConfig = {}) {
    this.network = config.network ?? 'testnet';
    this.broadcaster = new ARCBroadcaster(this.network, config.arcApiKey);
  }

  /** Broadcast a raw transaction hex to the BSV network. */
  async broadcast(txHex: string) {
    return this.broadcaster.broadcast(txHex);
  }

  /** Query transaction status from ARC. */
  async getTransactionStatus(txid: string) {
    return this.broadcaster.getStatus(txid);
  }
}
