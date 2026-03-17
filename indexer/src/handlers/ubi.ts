import { TxContext } from './index';
import { calculateDailyUBI, isUBIActive, phaseForCitizens } from '../state/city-state';

export async function handleUBIClaim(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const cityId = data['city_id'] as string;
  const citizenPubkey = data['citizen_pubkey'] as string;
  const claimPeriods = (data['claim_periods'] as number) || 1;
  if (!cityId || !citizenPubkey) return;

  // Look up city to calculate UBI amount
  const { rows } = await ctx.client.query(
    'SELECT citizen_count, treasury_sats, phase FROM cities WHERE id = $1',
    [cityId]
  );

  if (rows.length === 0) {
    ctx.logger.warn({ cityId }, 'UBI claim for unknown city');
    return;
  }

  const city = rows[0];
  if (!isUBIActive(city.phase)) {
    ctx.logger.warn({ cityId, phase: city.phase }, 'UBI claim for inactive city');
  }

  const dailyUBI = calculateDailyUBI(city.treasury_sats, city.citizen_count);
  const totalAmount = dailyUBI * claimPeriods;

  await ctx.client.query(
    `INSERT INTO ubi_claims (city_id, citizen_pubkey, claim_periods, amount_sats, block_height, txid)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [cityId, citizenPubkey, claimPeriods, totalAmount, ctx.blockHeight, ctx.txid]
  );

  // Deduct from city treasury
  await ctx.client.query(
    `UPDATE cities SET treasury_sats = GREATEST(treasury_sats - $1, 0), updated_at = NOW() WHERE id = $2`,
    [totalAmount, cityId]
  );

  ctx.logger.info({ cityId, citizen: citizenPubkey, periods: claimPeriods, amount: totalAmount }, 'UBI claimed');
}
