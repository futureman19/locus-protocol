import { TxContext } from './index';

export async function handleObjectDeploy(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const objectType = data['object_type'] as string;
  const location = (data['location'] as string) || (data['h3_index'] as string) || '';
  const ownerPubkey = data['owner_pubkey'] as string;
  const stakeAmount = data['stake_amount'] as number;
  const contentHash = (data['content_hash'] as string) || null;
  const manifestHash = (data['manifest_hash'] as string) || null;
  const parentTerritory = (data['parent_territory'] as string) || null;
  const capabilities = (data['capabilities'] as string[]) || [];

  const id = ctx.txid; // Objects are identified by their deploy txid

  await ctx.client.query(
    `INSERT INTO objects (id, object_type, h3_index, owner_pubkey, stake_amount, content_hash, manifest_hash, parent_territory, capabilities, deployed_block, deployed_txid)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     ON CONFLICT (id) DO NOTHING`,
    [id, objectType, location, ownerPubkey, stakeAmount, contentHash, manifestHash, parentTerritory, capabilities, ctx.blockHeight, ctx.txid]
  );

  ctx.logger.info({ id, objectType, owner: ownerPubkey }, 'Object deployed');
}

export async function handleObjectUpdate(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const objectId = data['object_id'] as string;
  if (!objectId) return;

  const updates: string[] = [];
  const params: unknown[] = [];
  let idx = 1;

  if (data['content_hash']) {
    updates.push(`content_hash = $${idx++}`);
    params.push(data['content_hash']);
  }
  if (data['manifest_hash']) {
    updates.push(`manifest_hash = $${idx++}`);
    params.push(data['manifest_hash']);
  }
  if (data['capabilities']) {
    updates.push(`capabilities = $${idx++}`);
    params.push(data['capabilities']);
  }

  if (updates.length > 0) {
    updates.push('updated_at = NOW()');
    params.push(objectId);
    await ctx.client.query(
      `UPDATE objects SET ${updates.join(', ')} WHERE id = $${idx} AND is_active = TRUE`,
      params
    );
  }
}

export async function handleObjectDestroy(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const objectId = data['object_id'] as string;
  if (!objectId) return;

  await ctx.client.query(
    `UPDATE objects SET is_active = FALSE, destroyed_block = $1, destroyed_txid = $2, updated_at = NOW()
     WHERE id = $3 AND is_active = TRUE`,
    [ctx.blockHeight, ctx.txid, objectId]
  );

  ctx.logger.info({ objectId }, 'Object destroyed');
}
