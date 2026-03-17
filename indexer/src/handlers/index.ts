import { PoolClient } from 'pg';
import { ParsedTransaction } from '../scanner/parser';
import { handleCityFound, handleCityUpdate } from './city';
import { handleCitizenJoin, handleCitizenLeave } from './citizen';
import { handleTerritoryClaim, handleTerritoryRelease, handleTerritoryTransfer } from './territory';
import { handleObjectDeploy, handleObjectUpdate, handleObjectDestroy } from './object';
import { handleHeartbeat } from './heartbeat';
import { handleGovPropose, handleGovVote, handleGovExec } from './governance';
import { handleUBIClaim } from './ubi';
import { Logger } from 'pino';

export interface TxContext {
  txid: string;
  blockHeight: number;
  blockHash: string;
  blockTime: number;
  client: PoolClient;
  logger: Logger;
}

/**
 * Dispatch a parsed LOCUS transaction to the appropriate handler.
 */
export async function dispatch(ctx: TxContext, parsed: ParsedTransaction): Promise<void> {
  // Log the raw transaction first
  await ctx.client.query(
    `INSERT INTO transactions (txid, message_type, message_type_name, block_height, block_hash, block_time, payload)
     VALUES ($1, $2, $3, $4, $5, to_timestamp($6), $7)
     ON CONFLICT (txid) DO NOTHING`,
    [ctx.txid, parsed.type, parsed.typeName, ctx.blockHeight, ctx.blockHash, ctx.blockTime, JSON.stringify(parsed.data)]
  );

  switch (parsed.type) {
    case 0x01: return handleCityFound(ctx, parsed.data);
    case 0x02: return handleCityUpdate(ctx, parsed.data);
    case 0x03: return handleCitizenJoin(ctx, parsed.data);
    case 0x04: return handleCitizenLeave(ctx, parsed.data);
    case 0x10: return handleTerritoryClaim(ctx, parsed.data);
    case 0x11: return handleTerritoryRelease(ctx, parsed.data);
    case 0x12: return handleTerritoryTransfer(ctx, parsed.data);
    case 0x20: return handleObjectDeploy(ctx, parsed.data);
    case 0x21: return handleObjectUpdate(ctx, parsed.data);
    case 0x22: return handleObjectDestroy(ctx, parsed.data);
    case 0x30: return handleHeartbeat(ctx, parsed.data);
    case 0x50: return handleGovPropose(ctx, parsed.data);
    case 0x51: return handleGovVote(ctx, parsed.data);
    case 0x52: return handleGovExec(ctx, parsed.data);
    case 0x60: return handleUBIClaim(ctx, parsed.data);
    default:
      ctx.logger.warn({ type: parsed.type, typeName: parsed.typeName }, 'Unhandled message type');
  }
}
