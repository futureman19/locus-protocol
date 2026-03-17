import { TxContext } from './index';
import { recalculateCityState } from './city';

export async function handleCitizenJoin(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const cityId = data['city_id'] as string;
  const pubkey = data['citizen_pubkey'] as string;
  if (!cityId || !pubkey) return;

  await ctx.client.query(
    `INSERT INTO citizens (pubkey, city_id, joined_block, joined_txid)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (pubkey, city_id) DO UPDATE SET is_active = TRUE, left_block = NULL, left_txid = NULL, updated_at = NOW()`,
    [pubkey, cityId, ctx.blockHeight, ctx.txid]
  );

  await ctx.client.query(
    `UPDATE cities SET citizen_count = citizen_count + 1, updated_at = NOW() WHERE id = $1`,
    [cityId]
  );

  await recalculateCityState(ctx, cityId);

  ctx.logger.info({ pubkey, cityId }, 'Citizen joined');
}

export async function handleCitizenLeave(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const cityId = data['city_id'] as string;
  const pubkey = data['citizen_pubkey'] as string;
  if (!cityId || !pubkey) return;

  await ctx.client.query(
    `UPDATE citizens SET is_active = FALSE, left_block = $1, left_txid = $2, updated_at = NOW()
     WHERE pubkey = $3 AND city_id = $4 AND is_active = TRUE`,
    [ctx.blockHeight, ctx.txid, pubkey, cityId]
  );

  await ctx.client.query(
    `UPDATE cities SET citizen_count = GREATEST(citizen_count - 1, 0), updated_at = NOW() WHERE id = $1`,
    [cityId]
  );

  await recalculateCityState(ctx, cityId);

  ctx.logger.info({ pubkey, cityId }, 'Citizen left');
}
