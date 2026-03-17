/**
 * ObjectManager — deploy, update, destroy /1 objects (including ghosts).
 *
 * Per spec 01-territory-hierarchy.md:
 * Objects are the /1 level — the smallest unit in Geo-IPv6.
 * Types: item, waypoint, agent/ghost, billboard, rare, epic, legendary
 *
 * Ghosts are NOT the center — they're just one type of /1 Object.
 */

import { ObjectType, ObjectDeployParams } from '../types';
import { TransactionBuilder } from './transaction-builder';
import { stakeForObjectType } from '../utils/stakes';

export class ObjectManager {
  /** Build an OBJECT_DEPLOY transaction script. */
  static buildDeployTransaction(params: ObjectDeployParams): Buffer {
    return TransactionBuilder.buildObjectDeploy(params);
  }

  /** Build an OBJECT_UPDATE transaction script. */
  static buildUpdateTransaction(objectId: string, ownerPubkey: string, updates: Record<string, unknown>): Buffer {
    return TransactionBuilder.encode('object_update', {
      object_id: objectId,
      owner_pubkey: ownerPubkey,
      updates,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  /** Build an OBJECT_DESTROY transaction script. */
  static buildDestroyTransaction(objectId: string, ownerPubkey: string, reason?: string): Buffer {
    return TransactionBuilder.buildObjectDestroy(objectId, ownerPubkey, reason);
  }

  /** Build a GHOST_INVOKE transaction script. */
  static buildGhostInvokeTransaction(
    ghostId: string,
    invokerPubkey: string,
    invokerLocation: string,
    sessionId?: string,
  ): Buffer {
    return TransactionBuilder.encode('ghost_invoke', {
      ghost_id: ghostId,
      invoker_pubkey: invokerPubkey,
      location: invokerLocation,
      timestamp: Math.floor(Date.now() / 1000),
      session_id: sessionId || '',
    });
  }

  /** Returns the minimum stake for an object type. */
  static getMinStake(objectType: ObjectType): number {
    return stakeForObjectType(objectType);
  }
}
