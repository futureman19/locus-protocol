/**
 * Transaction builder for Locus Protocol
 */

import {
  PrivateKey,
  PublicKey,
  Transaction,
  Script,
  Address
} from '@bsv/sdk';

import * as msgpack from 'msgpack5';

import {
  Network,
  GhostRegistrationParams,
  HeartbeatParams,
  InvocationParams,
  ChallengeParams,
  UTXO,
  GhostRegisterPayload,
  HeartbeatPayload,
  InvocationPayload,
  ChallengePayload,
  GeoLocation
} from './types';

import {
  PROTOCOL_PREFIX,
  PROTOCOL_VERSION,
  TransactionType,
  GhostType,
  LOCK_PERIOD_BLOCKS,
  CHALLENGER_STAKE,
  DUST_LIMIT,
  DEFAULT_FEE_RATE
} from './constants';

const msgpackEncode = msgpack();

export class TransactionBuilder {
  private network: Network;

  constructor(network: Network) {
    this.network = network;
  }

  /**
   * Build a GHOST_REGISTER transaction
   */
  async buildGhostRegister(
    params: GhostRegistrationParams,
    fundingUtxo: UTXO,
    ownerKey: PrivateKey,
    currentHeight: number
  ): Promise<{ tx: Transaction; redeemScript: Script }> {
    const ownerPubKey = PublicKey.fromPrivateKey(ownerKey);
    const ownerPubKeyHash = ownerPubKey.toHash();
    const ownerPubKeyHex = ownerPubKey.toString();

    // Calculate lock height
    const lockHeight = currentHeight + LOCK_PERIOD_BLOCKS;

    // Build CLTV redeem script
    const redeemScript = this.buildCLTVScript(lockHeight, ownerPubKeyHex);

    // Create P2SH address
    const p2shAddress = Address.fromScript(redeemScript, this.network);

    // Build H3 index
    const h3Index = this.latLngToH3(params.lat, params.lng);

    // Encode ghost type
    const typeCode = typeof params.type === 'string'
      ? GhostType[params.type.toUpperCase() as keyof typeof GhostType]
      : params.type;

    // Build payload
    const payload: GhostRegisterPayload = {
      name: params.name,
      type: typeCode,
      lat: Math.round(params.lat * 1_000_000),
      lng: Math.round(params.lng * 1_000_000),
      h3: h3Index,
      stake_amt: params.stakeAmount,
      lock_blocks: LOCK_PERIOD_BLOCKS,
      unlock_h: lockHeight,
      owner_pk: ownerPubKeyHex,
      code_hash: params.codeHash,
      code_uri: params.codeUri,
      base_fee: params.baseFee || 1000,
      timeout: params.timeout || 30,
      meta: params.meta || {}
    };

    // Build OP_RETURN script
    const opReturnScript = this.buildOpReturnScript(
      TransactionType.GHOST_REGISTER,
      payload
    );

    // Calculate fee
    const estimatedSize = 200; // bytes
    const fee = Math.ceil(estimatedSize * DEFAULT_FEE_RATE);

    // Build outputs
    const outputs = [
      // Stake output (P2SH)
      {
        satoshis: params.stakeAmount,
        script: p2shAddress.toScript().toHex()
      },
      // OP_RETURN output
      {
        satoshis: 0,
        script: opReturnScript.toHex()
      }
    ];

    // Add change output if needed
    const changeAmount = fundingUtxo.satoshis - params.stakeAmount - fee;
    if (changeAmount > DUST_LIMIT) {
      outputs.push({
        satoshis: changeAmount,
        script: Script.buildPublicKeyHashOut(ownerPubKeyHash).toHex()
      });
    }

    // Build transaction
    const tx = new Transaction({
      version: 1,
      inputs: [{
        prevTxId: fundingUtxo.txid,
        outputIndex: fundingUtxo.vout,
        script: '',
        sequence: 0xFFFFFFFF
      }],
      outputs: outputs.map(o => ({
        satoshis: o.satoshis,
        script: Script.fromHex(o.script)
      }))
    });

    return { tx, redeemScript };
  }

  /**
   * Build a HEARTBEAT transaction
   */
  async buildHeartbeat(
    params: HeartbeatParams,
    fundingUtxo: UTXO,
    ownerKey: PrivateKey
  ): Promise<Transaction> {
    const ownerPubKey = PublicKey.fromPrivateKey(ownerKey);
    const ownerPubKeyHash = ownerPubKey.toHash();

    const payload: HeartbeatPayload = {
      ghost_id: params.ghostId,
      seq: params.sequence,
      h3: params.location.h3Index,
      lat: Math.round(params.location.lat * 1_000_000),
      lng: Math.round(params.location.lng * 1_000_000),
      ts: params.timestamp || Math.floor(Date.now() / 1000)
    };

    const opReturnScript = this.buildOpReturnScript(
      TransactionType.HEARTBEAT,
      payload
    );

    const fee = Math.ceil(150 * DEFAULT_FEE_RATE);
    const changeAmount = fundingUtxo.satoshis - fee;

    const outputs = [{
      satoshis: 0,
      script: opReturnScript.toHex()
    }];

    if (changeAmount > DUST_LIMIT) {
      outputs.push({
        satoshis: changeAmount,
        script: Script.buildPublicKeyHashOut(ownerPubKeyHash).toHex()
      });
    }

    return new Transaction({
      version: 1,
      inputs: [{
        prevTxId: fundingUtxo.txid,
        outputIndex: fundingUtxo.vout,
        script: '',
        sequence: 0xFFFFFFFF
      }],
      outputs: outputs.map(o => ({
        satoshis: o.satoshis,
        script: Script.fromHex(o.script)
      }))
    });
  }

  /**
   * Build an INVOCATION transaction
   */
  async buildInvocation(
    params: InvocationParams,
    feeAmount: number,
    fundingUtxo: UTXO,
    invokerKey: PrivateKey
  ): Promise<{ tx: Transaction; invocationId: string }> {
    const invokerPubKey = PublicKey.fromPrivateKey(invokerKey);
    const invokerPubKeyHash = invokerPubKey.toHash();

    const nonce = params.nonce || this.generateNonce();

    const payload: InvocationPayload = {
      ghost_id: params.ghostId,
      params: params.params,
      nonce,
      ts: params.timestamp || Math.floor(Date.now() / 1000)
    };

    const opReturnScript = this.buildOpReturnScript(
      TransactionType.INVOCATION,
      payload
    );

    const fee = Math.ceil(200 * DEFAULT_FEE_RATE);
    const changeAmount = fundingUtxo.satoshis - feeAmount - fee;

    const outputs = [
      // Fee output (will be claimed by ghost)
      {
        satoshis: feeAmount,
        script: Script.buildPublicKeyHashOut(invokerPubKeyHash).toHex()
      },
      // OP_RETURN
      {
        satoshis: 0,
        script: opReturnScript.toHex()
      }
    ];

    if (changeAmount > DUST_LIMIT) {
      outputs.push({
        satoshis: changeAmount,
        script: Script.buildPublicKeyHashOut(invokerPubKeyHash).toHex()
      });
    }

    const tx = new Transaction({
      version: 1,
      inputs: [{
        prevTxId: fundingUtxo.txid,
        outputIndex: fundingUtxo.vout,
        script: '',
        sequence: 0xFFFFFFFF
      }],
      outputs: outputs.map(o => ({
        satoshis: o.satoshis,
        script: Script.fromHex(o.script)
      }))
    });

    const invocationId = this.generateInvocationId(params.ghostId, payload);

    return { tx, invocationId };
  }

  /**
   * Build a CHALLENGE transaction
   */
  async buildChallenge(
    params: ChallengeParams,
    fundingUtxo: UTXO,
    challengerKey: PrivateKey
  ): Promise<{ tx: Transaction; challengeId: string }> {
    const challengerPubKey = PublicKey.fromPrivateKey(challengerKey);
    const challengerPubKeyHash = challengerPubKey.toHash();
    const challengerPubKeyHex = challengerPubKey.toString();

    const typeCode = typeof params.type === 'string'
      ? ({ no_show: 1, fraud: 2, malfunction: 3, timeout: 4 })[params.type]
      : params.type;

    const payload: ChallengePayload = {
      ghost_id: params.ghostId,
      type: typeCode,
      evidence: params.evidence,
      challenger: challengerPubKeyHex,
      ts: params.timestamp || Math.floor(Date.now() / 1000)
    };

    const opReturnScript = this.buildOpReturnScript(
      TransactionType.CHALLENGE,
      payload
    );

    const fee = Math.ceil(180 * DEFAULT_FEE_RATE);
    const changeAmount = fundingUtxo.satoshis - CHALLENGER_STAKE - fee;

    const outputs = [
      // Challenger stake
      {
        satoshis: CHALLENGER_STAKE,
        script: Script.buildPublicKeyHashOut(challengerPubKeyHash).toHex()
      },
      // OP_RETURN
      {
        satoshis: 0,
        script: opReturnScript.toHex()
      }
    ];

    if (changeAmount > DUST_LIMIT) {
      outputs.push({
        satoshis: changeAmount,
        script: Script.buildPublicKeyHashOut(challengerPubKeyHash).toHex()
      });
    }

    const tx = new Transaction({
      version: 1,
      inputs: [{
        prevTxId: fundingUtxo.txid,
        outputIndex: fundingUtxo.vout,
        script: '',
        sequence: 0xFFFFFFFF
      }],
      outputs: outputs.map(o => ({
        satoshis: o.satoshis,
        script: Script.fromHex(o.script)
      }))
    });

    const challengeId = this.generateChallengeId(params.ghostId, payload);

    return { tx, challengeId };
  }

  // ==========================================================================
  // Private Methods
  // ==========================================================================

  private buildCLTVScript(lockHeight: number, ownerPubKeyHex: string): Script {
    // Script: <lockHeight> OP_CHECKLOCKTIMEVERIFY OP_DROP <pubKey> OP_CHECKSIG
    const script = new Script();
    script.add(Buffer.from([lockHeight & 0xFF, (lockHeight >> 8) & 0xFF]));
    script.add(Buffer.from('b1', 'hex')); // OP_CHECKLOCKTIMEVERIFY
    script.add(Buffer.from('75', 'hex')); // OP_DROP
    script.add(Buffer.from(ownerPubKeyHex, 'hex'));
    script.add(Buffer.from('ac', 'hex')); // OP_CHECKSIG
    return script;
  }

  private buildOpReturnScript(type: TransactionType, payload: unknown): Script {
    const encodedPayload = msgpackEncode.encode(payload);
    const payloadLen = encodedPayload.length;

    const data = Buffer.concat([
      Buffer.from(PROTOCOL_PREFIX),
      Buffer.from(PROTOCOL_VERSION),
      Buffer.from([type]),
      Buffer.from([(payloadLen >> 8) & 0xFF, payloadLen & 0xFF]), // Big-endian
      encodedPayload
    ]);

    return Script.buildDataOut(data.toString('hex'));
  }

  private latLngToH3(lat: number, lng: number): string {
    const data = `${lat}:${lng}`;
    const hash = require('crypto').createHash('sha256').update(data).digest('hex');
    return hash.substring(0, 16);
  }

  private generateNonce(): string {
    return require('crypto').randomBytes(8).toString('hex');
  }

  private generateInvocationId(ghostId: string, payload: InvocationPayload): string {
    const data = JSON.stringify({ ghostId, payload });
    return require('crypto').createHash('sha256').update(data).digest('hex');
  }

  private generateChallengeId(ghostId: string, payload: ChallengePayload): string {
    const data = JSON.stringify({ ghostId, payload });
    return require('crypto').createHash('sha256').update(data).digest('hex');
  }
}
