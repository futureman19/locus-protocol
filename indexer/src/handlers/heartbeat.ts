import { TxContext } from './index';

export async function handleHeartbeat(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const heartbeatType = data['heartbeat_type'] as number;
  const entityId = data['entity_id'] as string;
  const entityType = (data['entity_type'] as number) || null;
  const location = (data['location'] as string) || (data['h3_index'] as string) || '';
  const timestamp = data['timestamp'] as number;
  const nonce = data['nonce'] as number;

  await ctx.client.query(
    `INSERT INTO heartbeats (heartbeat_type, entity_id, entity_type, h3_index, timestamp_unix, nonce, block_height, txid)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (entity_id, nonce) DO NOTHING`,
    [heartbeatType, entityId, entityType, location, timestamp, nonce, ctx.blockHeight, ctx.txid]
  );

  // Update last_heartbeat on citizen record for citizen heartbeats (type 2)
  if (heartbeatType === 2 && entityId) {
    await ctx.client.query(
      `UPDATE citizens SET last_heartbeat = to_timestamp($1), updated_at = NOW()
       WHERE pubkey = $2 AND is_active = TRUE`,
      [timestamp, entityId]
    );
  }
}
