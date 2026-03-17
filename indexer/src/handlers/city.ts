import { TxContext } from './index';
import { phaseForCitizens, governanceForPhase, blocksForCitizens } from '../state/city-state';

export async function handleCityFound(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const name = data['name'] as string;
  const description = (data['description'] as string) || '';
  const location = data['location'] as Record<string, unknown> | undefined;
  const lat = location ? (location['lat'] as number) : (data['lat'] as number) || 0;
  const lng = location ? (location['lng'] as number) : (data['lng'] as number) || 0;
  const h3Index = location ? (location['h3_res7'] as string) : (data['h3_res7'] as string) || '';
  const founderPubkey = data['founder_pubkey'] as string;

  const cityId = h3Index || ctx.txid;

  await ctx.client.query(
    `INSERT INTO cities (id, name, description, lat, lng, geom, h3_index, founder_pubkey, founded_block, founded_txid, phase, citizen_count, unlocked_blocks, governance_type)
     VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($5, $4), 4326), $6, $7, $8, $9, 'genesis', 1, 2, 'founder')
     ON CONFLICT (id) DO NOTHING`,
    [cityId, name, description, lat, lng, h3Index, founderPubkey, ctx.blockHeight, ctx.txid]
  );

  // Founder is the first citizen
  await ctx.client.query(
    `INSERT INTO citizens (pubkey, city_id, joined_block, joined_txid)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (pubkey, city_id) DO NOTHING`,
    [founderPubkey, cityId, ctx.blockHeight, ctx.txid]
  );

  ctx.logger.info({ city: name, h3: h3Index, founder: founderPubkey }, 'City founded');
}

export async function handleCityUpdate(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const cityId = data['city_id'] as string;
  if (!cityId) return;

  const updates: string[] = [];
  const params: unknown[] = [];
  let paramIdx = 1;

  if (data['name']) {
    updates.push(`name = $${paramIdx++}`);
    params.push(data['name']);
  }
  if (data['description']) {
    updates.push(`description = $${paramIdx++}`);
    params.push(data['description']);
  }
  if (data['policies']) {
    // Policies stored as part of city metadata — could extend schema
    ctx.logger.debug({ cityId, policies: data['policies'] }, 'City policies update');
  }

  if (updates.length > 0) {
    updates.push(`updated_at = NOW()`);
    params.push(cityId);
    await ctx.client.query(
      `UPDATE cities SET ${updates.join(', ')} WHERE id = $${paramIdx}`,
      params
    );
  }
}

/**
 * Recalculate city phase, governance, and unlocked blocks after citizen count change.
 */
export async function recalculateCityState(ctx: TxContext, cityId: string): Promise<void> {
  const { rows } = await ctx.client.query(
    'SELECT citizen_count FROM cities WHERE id = $1',
    [cityId]
  );
  if (rows.length === 0) return;

  const count = rows[0].citizen_count as number;
  const phase = phaseForCitizens(count);
  const governance = governanceForPhase(phase);
  const blocks = blocksForCitizens(count);

  await ctx.client.query(
    `UPDATE cities SET phase = $1, governance_type = $2, unlocked_blocks = $3, updated_at = NOW()
     WHERE id = $4`,
    [phase, governance, blocks, cityId]
  );
}
