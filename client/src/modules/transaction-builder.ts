/**
 * OP_RETURN encoding and decoding for the territory-centric protocol.
 *
 * Per spec 07-transaction-formats.md:
 *   OP_RETURN "LOCUS" {version:1} {type:1} {msgpack payload}
 */

import {
  PROTOCOL_PREFIX,
  PROTOCOL_VERSION,
  OP_RETURN,
  OP_PUSHDATA1,
  OP_PUSHDATA2,
  TYPE_CODES,
  REVERSE_CODES,
  PROPOSAL_TYPE_CODES,
  VOTE_CODES,
} from '../constants/opcodes';
import { encode as msgpackEncode, decode as msgpackDecode } from '../utils/messagepack';
import {
  MessageTypeName,
  DecodedTransaction,
  CityFoundParams,
  TerritoryClaimParams,
  ObjectDeployParams,
  ProposeParams,
  VoteChoice,
  HeartbeatParams,
} from '../types';

export class TransactionBuilder {
  /**
   * Encode a protocol message into an OP_RETURN script.
   *
   * Returns the full script as a Buffer:
   *   OP_RETURN [pushdata] "LOCUS" version type msgpack_payload
   */
  static encode(type: MessageTypeName, payload: Record<string, unknown>): Buffer {
    const typeCode = TYPE_CODES[type];
    if (typeCode === undefined) {
      throw new Error(`Unknown message type: ${type}`);
    }

    const payloadBin = msgpackEncode(payload);

    // Protocol data: "LOCUS" + version + type + payload
    const prefix = Buffer.from(PROTOCOL_PREFIX, 'ascii');
    const protocolData = Buffer.concat([
      prefix,
      Buffer.from([PROTOCOL_VERSION, typeCode]),
      payloadBin,
    ]);

    const totalLen = protocolData.length;

    // OP_RETURN with appropriate pushdata opcode
    if (totalLen <= 0x4b) {
      return Buffer.concat([Buffer.from([OP_RETURN, totalLen]), protocolData]);
    } else if (totalLen <= 0xff) {
      return Buffer.concat([Buffer.from([OP_RETURN, OP_PUSHDATA1, totalLen]), protocolData]);
    } else {
      const lenBuf = Buffer.alloc(2);
      lenBuf.writeUInt16LE(totalLen);
      return Buffer.concat([Buffer.from([OP_RETURN, OP_PUSHDATA2]), lenBuf, protocolData]);
    }
  }

  /**
   * Decode an OP_RETURN script into protocol data.
   */
  static decode(script: Buffer): DecodedTransaction {
    const data = TransactionBuilder.extractPushdata(script);
    return TransactionBuilder.parseProtocolData(data);
  }

  // -- Payload builders matching Elixir reference --

  static buildCityFound(params: CityFoundParams): Buffer {
    return TransactionBuilder.encode('city_found', {
      name: params.name,
      description: params.description || '',
      location: {
        lat: params.lat,
        lng: params.lng,
        h3_res7: params.h3Res7,
      },
      founder_pubkey: params.founderPubkey,
      policies: params.policies || {},
      signature: '',
    });
  }

  static buildCitizenJoin(cityId: string, citizenPubkey: string): Buffer {
    return TransactionBuilder.encode('citizen_join', {
      city_id: cityId,
      citizen_pubkey: citizenPubkey,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  static buildTerritoryClaim(params: TerritoryClaimParams): Buffer {
    return TransactionBuilder.encode('territory_claim', {
      level: params.level,
      location: params.h3Index,
      owner_pubkey: params.ownerPubkey,
      stake_amount: params.stakeAmount,
      lock_height: params.lockHeight,
      parent_city: params.parentCity || '',
      metadata: params.metadata || {},
    });
  }

  static buildTerritoryTransfer(
    territoryId: string,
    fromPubkey: string,
    toPubkey: string,
    price = 0,
  ): Buffer {
    return TransactionBuilder.encode('territory_transfer', {
      territory_id: territoryId,
      from_pubkey: fromPubkey,
      to_pubkey: toPubkey,
      price,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  static buildObjectDeploy(params: ObjectDeployParams): Buffer {
    return TransactionBuilder.encode('object_deploy', {
      object_type: params.objectType,
      location: params.h3Index,
      owner_pubkey: params.ownerPubkey,
      stake_amount: params.stakeAmount,
      content_hash: params.contentHash,
      parent_territory: params.parentTerritory,
      capabilities: params.capabilities || [],
    });
  }

  static buildObjectDestroy(objectId: string, ownerPubkey: string, reason?: string): Buffer {
    return TransactionBuilder.encode('object_destroy', {
      object_id: objectId,
      owner_pubkey: ownerPubkey,
      reason: reason || '',
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  static buildGovPropose(params: ProposeParams): Buffer {
    const typeCode = PROPOSAL_TYPE_CODES[params.proposalType] ?? 0x00;
    return TransactionBuilder.encode('gov_propose', {
      proposal_type: typeCode,
      scope: params.scope ?? 1,
      title: params.title,
      description: params.description || '',
      actions: params.actions || [],
      deposit: params.deposit ?? 10_000_000,
      proposer_pubkey: params.proposerPubkey,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  static buildGovVote(proposalId: string, voterPubkey: string, vote: VoteChoice): Buffer {
    return TransactionBuilder.encode('gov_vote', {
      proposal_id: proposalId,
      voter_pubkey: voterPubkey,
      vote: VOTE_CODES[vote],
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  static buildGovExec(proposalId: string, executorPubkey: string): Buffer {
    return TransactionBuilder.encode('gov_exec', {
      proposal_id: proposalId,
      executor_pubkey: executorPubkey,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  static buildHeartbeat(params: HeartbeatParams): Buffer {
    return TransactionBuilder.encode('heartbeat', {
      heartbeat_type: params.heartbeatType,
      entity_id: params.entityId,
      entity_type: params.entityType,
      location: params.h3Index,
      timestamp: Math.floor(Date.now() / 1000),
      nonce: params.nonce ?? Math.floor(Math.random() * 0xffffffff),
    });
  }

  static buildUBIClaim(cityId: string, citizenPubkey: string, claimPeriods: number): Buffer {
    return TransactionBuilder.encode('ubi_claim', {
      city_id: cityId,
      citizen_pubkey: citizenPubkey,
      claim_periods: claimPeriods,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  // -- Private helpers --

  private static extractPushdata(script: Buffer): Buffer {
    if (script[0] !== OP_RETURN) {
      throw new Error('Not an OP_RETURN script');
    }

    let offset = 1;
    let len: number;

    if (script[offset] <= 0x4b) {
      len = script[offset];
      offset += 1;
    } else if (script[offset] === OP_PUSHDATA1) {
      len = script[offset + 1];
      offset += 2;
    } else if (script[offset] === OP_PUSHDATA2) {
      len = script.readUInt16LE(offset + 1);
      offset += 3;
    } else {
      throw new Error('Invalid pushdata opcode');
    }

    return script.subarray(offset, offset + len);
  }

  private static parseProtocolData(data: Buffer): DecodedTransaction {
    const prefix = data.subarray(0, 5).toString('ascii');
    if (prefix !== PROTOCOL_PREFIX) {
      throw new Error('Not a LOCUS protocol message');
    }

    const version = data[5];
    const typeCode = data[6];
    const typeName = REVERSE_CODES[typeCode];

    if (!typeName) {
      throw new Error(`Unknown type code: 0x${typeCode.toString(16)}`);
    }

    const payload = data.subarray(7);
    const decoded = msgpackDecode(payload) as Record<string, unknown>;

    return {
      type: typeName as MessageTypeName,
      version,
      data: decoded,
    };
  }
}
