/**
 * CLTV (CheckLockTimeVerify) script utilities.
 *
 * Per spec 03-staking-economics.md / 07-transaction-formats.md:
 *
 * OP_IF
 *   <locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP
 *   <owner_pubkey> OP_CHECKSIG
 * OP_ELSE
 *   OP_10 OP_CHECKSEQUENCEVERIFY OP_DROP
 *   <penalty_address> OP_DUP OP_HASH160 <penalty_hash160> OP_EQUALVERIFY
 *   <owner_pubkey> OP_CHECKSIG
 * OP_ENDIF
 */

import { LOCK_PERIOD_BLOCKS, EMERGENCY_PENALTY_RATE } from '../constants/stakes';

export interface CLTVParams {
  lockHeight: number;
  ownerPubkey: string;
  penaltyAddress?: string;
}

/** Builds a descriptive CLTV lock config (not raw script — use bsv_sdk for actual scripts). */
export function buildLockConfig(currentHeight: number, ownerPubkey: string, penaltyAddress?: string): CLTVParams {
  return {
    lockHeight: currentHeight + LOCK_PERIOD_BLOCKS,
    ownerPubkey,
    penaltyAddress,
  };
}

/** Checks if a CLTV lock has expired. */
export function isLockExpired(lockHeight: number, currentHeight: number): boolean {
  return currentHeight >= lockHeight;
}

/** Calculates emergency unlock outputs. */
export function emergencyUnlockOutputs(stakeAmount: number): { penalty: number; returned: number } {
  const penalty = Math.floor(stakeAmount * EMERGENCY_PENALTY_RATE);
  return {
    penalty,
    returned: stakeAmount - penalty,
  };
}
