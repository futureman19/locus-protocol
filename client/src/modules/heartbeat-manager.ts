/**
 * HeartbeatManager — proof of presence for properties and citizens.
 *
 * Per spec 07-transaction-formats.md:
 * - heartbeat_type: 1=property, 2=citizen, 3=aura
 * - Timestamp must be within 24h window
 * - Nonce for replay protection
 */

import { HeartbeatParams } from '../types';
import { TransactionBuilder } from './transaction-builder';

export class HeartbeatManager {
  /** Build a HEARTBEAT transaction script. */
  static buildHeartbeatTransaction(params: HeartbeatParams): Buffer {
    return TransactionBuilder.buildHeartbeat(params);
  }

  /** Build a property heartbeat (type=1). */
  static buildPropertyHeartbeat(entityId: string, h3Index: string, entityType = 8): Buffer {
    return TransactionBuilder.buildHeartbeat({
      heartbeatType: 1,
      entityId,
      entityType,
      h3Index,
    });
  }

  /** Build a citizen heartbeat (type=2). */
  static buildCitizenHeartbeat(citizenPubkey: string, h3Index: string): Buffer {
    return TransactionBuilder.buildHeartbeat({
      heartbeatType: 2,
      entityId: citizenPubkey,
      h3Index,
    });
  }

  /** Build an aura heartbeat (type=3). */
  static buildAuraHeartbeat(ownerPubkey: string, h3Index: string): Buffer {
    return TransactionBuilder.buildHeartbeat({
      heartbeatType: 3,
      entityId: ownerPubkey,
      h3Index,
    });
  }

  /** Validate heartbeat timestamp (within 24h window). */
  static isValidTimestamp(timestampSecs: number): boolean {
    const now = Math.floor(Date.now() / 1000);
    return Math.abs(now - timestampSecs) < 86400;
  }
}
