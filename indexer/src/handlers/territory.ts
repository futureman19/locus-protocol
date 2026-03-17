import { TxContext } from './index';

export async function handleTerritoryClaim(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const level = data['level'] as number;
  const location = (data['location'] as string) || (data['h3_index'] as string) || '';
  const ownerPubkey = data['owner_pubkey'] as string;
  const stakeAmount = data['stake_amount'] as number;
  const lockHeight = data['lock_height'] as number;
  const parentCity = (data['parent_city'] as string) || null;
  const metadata = data['metadata'] || null;

  const id = location || ctx.txid;

  await ctx.client.query(
    `INSERT INTO territories (id, level, h3_index, owner_pubkey, stake_amount, lock_height, parent_city, claimed_block, claimed_txid, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     ON CONFLICT (id) DO UPDATE SET
       owner_pubkey = $4, stake_amount = $5, lock_height = $6,
       is_active = TRUE, released_block = NULL, released_txid = NULL,
       metadata = COALESCE($10, territories.metadata), updated_at = NOW()`,
    [id, level, location, ownerPubkey, stakeAmount, lockHeight, parentCity, ctx.blockHeight, ctx.txid, metadata ? JSON.stringify(metadata) : null]
  );

  // Increment citizen's territory count
  if (ownerPubkey && parentCity) {
    await ctx.client.query(
      `UPDATE citizens SET territories_claimed = territories_claimed + 1, updated_at = NOW()
       WHERE pubkey = $1 AND city_id = $2`,
      [ownerPubkey, parentCity]
    );
  }

  ctx.logger.info({ id, level, owner: ownerPubkey, stake: stakeAmount }, 'Territory claimed');
}

export async function handleTerritoryRelease(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const territoryId = (data['territory_id'] as string) || (data['location'] as string) || '';
  if (!territoryId) return;

  const { rows } = await ctx.client.query(
    `UPDATE territories SET is_active = FALSE, released_block = $1, released_txid = $2, updated_at = NOW()
     WHERE id = $3 AND is_active = TRUE
     RETURNING owner_pubkey, parent_city`,
    [ctx.blockHeight, ctx.txid, territoryId]
  );

  if (rows.length > 0 && rows[0].parent_city) {
    await ctx.client.query(
      `UPDATE citizens SET territories_claimed = GREATEST(territories_claimed - 1, 0), updated_at = NOW()
       WHERE pubkey = $1 AND city_id = $2`,
      [rows[0].owner_pubkey, rows[0].parent_city]
    );
  }

  ctx.logger.info({ territoryId }, 'Territory released');
}

export async function handleTerritoryTransfer(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const territoryId = (data['territory_id'] as string) || (data['location'] as string) || '';
  const newOwner = data['new_owner_pubkey'] as string;
  if (!territoryId || !newOwner) return;

  const { rows } = await ctx.client.query(
    `UPDATE territories SET owner_pubkey = $1, updated_at = NOW()
     WHERE id = $2 AND is_active = TRUE
     RETURNING owner_pubkey, parent_city`,
    [newOwner, territoryId]
  );

  // Update territory counts for old and new owner
  if (rows.length > 0 && rows[0].parent_city) {
    const oldOwner = data['from_pubkey'] as string;
    if (oldOwner) {
      await ctx.client.query(
        `UPDATE citizens SET territories_claimed = GREATEST(territories_claimed - 1, 0), updated_at = NOW()
         WHERE pubkey = $1 AND city_id = $2`,
        [oldOwner, rows[0].parent_city]
      );
    }
    await ctx.client.query(
      `UPDATE citizens SET territories_claimed = territories_claimed + 1, updated_at = NOW()
       WHERE pubkey = $1 AND city_id = $2`,
      [newOwner, rows[0].parent_city]
    );
  }

  ctx.logger.info({ territoryId, newOwner }, 'Territory transferred');
}
