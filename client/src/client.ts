/**
 * Main Locus Protocol client
 */

import {
  PrivateKey,
  PublicKey,
  Transaction,
  Script,
  ARC,
  WalletClient
} from '@bsv/sdk';

import {
  Network,
  LocusClientConfig,
  Ghost,
  GhostRegistrationParams,
  GhostUpdateParams,
  HeartbeatParams,
  InvocationParams,
  ChallengeParams,
  UTXO,
  WalletInterface,
  LatLng
} from './types';

import {
  ARC_ENDPOINTS,
  GHOST_TYPES,
  GhostType,
  MIN_STAKE_AMOUNTS,
  LOCK_PERIOD_BLOCKS,
  CHALLENGER_STAKE
} from './constants';

import { TransactionBuilder } from './transaction-builder';
import { GhostRegistry } from './registry';
import { ARCBroadcaster } from './broadcaster';

export class LocusClient {
  private network: Network;
  private broadcaster: ARCBroadcaster;
  private registry: GhostRegistry;
  private builder: TransactionBuilder;
  private wallet: WalletInterface | null = null;

  /**
   * Create a new Locus Protocol client
   */
  constructor(config: LocusClientConfig = {}) {
    this.network = config.network || 'testnet';
    
    const arcEndpoint = config.arcEndpoint || ARC_ENDPOINTS[this.network.toUpperCase() as keyof typeof ARC_ENDPOINTS];
    
    this.broadcaster = new ARCBroadcaster({
      endpoint: arcEndpoint,
      apiKey: config.arcApiKey
    });

    this.registry = new GhostRegistry(this.network);
    this.builder = new TransactionBuilder(this.network);
  }

  /**
   * Connect a wallet to the client
   */
  setWallet(wallet: WalletInterface): void {
    this.wallet = wallet;
  }

  /**
   * Get the minimum stake amount for a ghost type
   */
  getMinStakeAmount(type: GhostType | keyof typeof GhostType): number {
    const typeCode = typeof type === 'string' 
      ? GhostType[type.toUpperCase() as keyof typeof GhostType]
      : type;
    return MIN_STAKE_AMOUNTS[typeCode];
  }

  /**
   * Register a new ghost
   * 
   * @returns The created ghost and stake information
   */
  async registerGhost(
    params: GhostRegistrationParams,
    fundingUtxo: UTXO,
    ownerKey: PrivateKey
  ): Promise<{ ghost: Ghost; stakeInfo: { txid: string; lockHeight: number } }> {
    // Validate stake amount
    const typeCode = typeof params.type === 'string'
      ? GhostType[params.type.toUpperCase() as keyof typeof GhostType]
      : params.type;
    
    const minStake = MIN_STAKE_AMOUNTS[typeCode];
    if (params.stakeAmount < minStake) {
      throw new Error(`Stake amount below minimum. Required: ${minStake} sats`);
    }

    // Get current height (in production, query from API)
    const currentHeight = await this.getCurrentHeight();
    const lockHeight = currentHeight + LOCK_PERIOD_BLOCKS;

    // Build transaction
    const { tx, redeemScript } = await this.builder.buildGhostRegister(
      params,
      fundingUtxo,
      ownerKey,
      currentHeight
    );

    // Sign transaction
    const signedTx = await this.signTransaction(tx, ownerKey);

    // Broadcast
    const result = await this.broadcaster.broadcast(signedTx);

    // Derive ghost ID
    const ghostId = this.deriveGhostId(result.txid, 0);

    // Create ghost object
    const ownerPubKey = PublicKey.fromPrivateKey(ownerKey);
    const ghost: Ghost = {
      id: ghostId,
      name: params.name,
      type: typeCode,
      location: {
        lat: params.lat,
        lng: params.lng,
        h3Index: this.latLngToH3(params.lat, params.lng)
      },
      stakeAmount: params.stakeAmount,
      lockHeight,
      ownerPubKey: ownerPubKey.toString(),
      codeHash: params.codeHash,
      codeUri: params.codeUri,
      baseFee: params.baseFee || 1000,
      timeout: params.timeout || 30,
      meta: params.meta,
      state: 'pending',
      heartbeatSeq: 0,
      createdAt: new Date()
    };

    return {
      ghost,
      stakeInfo: {
        txid: result.txid,
        lockHeight
      }
    };
  }

  /**
   * Send a heartbeat for a ghost
   */
  async sendHeartbeat(
    params: HeartbeatParams,
    fundingUtxo: UTXO,
    ownerKey: PrivateKey
  ): Promise<{ txid: string; sequence: number }> {
    const tx = await this.builder.buildHeartbeat(
      params,
      fundingUtxo,
      ownerKey
    );

    const signedTx = await this.signTransaction(tx, ownerKey);
    const result = await this.broadcaster.broadcast(signedTx);

    return {
      txid: result.txid,
      sequence: params.sequence
    };
  }

  /**
   * Invoke a ghost
   */
  async invokeGhost(
    params: InvocationParams,
    feeAmount: number,
    fundingUtxo: UTXO,
    invokerKey: PrivateKey
  ): Promise<{ txid: string; invocationId: string }> {
    const { tx, invocationId } = await this.builder.buildInvocation(
      params,
      feeAmount,
      fundingUtxo,
      invokerKey
    );

    const signedTx = await this.signTransaction(tx, invokerKey);
    const result = await this.broadcaster.broadcast(signedTx);

    return {
      txid: result.txid,
      invocationId
    };
  }

  /**
   * Challenge a ghost
   */
  async challengeGhost(
    params: ChallengeParams,
    fundingUtxo: UTXO,
    challengerKey: PrivateKey
  ): Promise<{ txid: string; challengeId: string }> {
    const { tx, challengeId } = await this.builder.buildChallenge(
      params,
      fundingUtxo,
      challengerKey
    );

    const signedTx = await this.signTransaction(tx, challengerKey);
    const result = await this.broadcaster.broadcast(signedTx);

    return {
      txid: result.txid,
      challengeId
    };
  }

  /**
   * Find ghosts by location
   */
  async findGhostsByLocation(
    location: LatLng,
    radius: number
  ): Promise<Ghost[]> {
    return this.registry.findByLocation(location, radius);
  }

  /**
   * Get ghost by ID
   */
  async getGhost(ghostId: string): Promise<Ghost | null> {
    return this.registry.getGhost(ghostId);
  }

  /**
   * Get ghosts by owner
   */
  async getGhostsByOwner(ownerPubKey: string): Promise<Ghost[]> {
    return this.registry.findByOwner(ownerPubKey);
  }

  // ==========================================================================
  // Private Methods
  // ==========================================================================

  private async signTransaction(
    tx: Transaction,
    key: PrivateKey
  ): Promise<Transaction> {
    // Sign each input with the provided key
    for (let i = 0; i < tx.inputs.length; i++) {
      const input = tx.inputs[i];
      const sighash = tx.sighash(i, Script.fromHex(input.outputScript || ''), input.satoshis || 0);
      const signature = key.sign(sighash);
      input.script = Script.buildPublicKeyHashIn(
        key.toPublicKey().toString(),
        signature.toString()
      );
    }

    return tx;
  }

  private deriveGhostId(txid: string, outputIndex: number): string {
    const data = Buffer.alloc(36);
    data.write(txid.replace(/ /g, ''), 0, 32, 'hex');
    data.writeUInt32LE(outputIndex, 32);
    
    const hash = require('crypto').createHash('sha256').update(data).digest();
    return hash.toString('hex');
  }

  private latLngToH3(lat: number, lng: number): string {
    // Placeholder - in production use actual H3 library
    const data = `${lat}:${lng}`;
    const hash = require('crypto').createHash('sha256').update(data).digest('hex');
    return hash.substring(0, 16);
  }

  private async getCurrentHeight(): Promise<number> {
    // In production, query from API
    // For now, return a placeholder
    return 0;
  }
}
