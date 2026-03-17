import { Router, Request, Response } from 'express';
import { query } from '../db/pool';

const router = Router();

/**
 * GET /api/v1/cities
 * List all cities with optional pagination.
 */
router.get('/', async (req: Request, res: Response) => {
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;
  const phase = req.query.phase as string;

  let sql = 'SELECT id, name, description, lat, lng, h3_index, founder_pubkey, phase, citizen_count, unlocked_blocks, governance_type, treasury_sats, founded_block FROM cities';
  const params: unknown[] = [];

  if (phase) {
    sql += ' WHERE phase = $1';
    params.push(phase);
  }

  sql += ` ORDER BY founded_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ cities: rows, limit, offset });
});

/**
 * GET /api/v1/cities/nearby?lat=X&lng=Y&radius=N
 * Find cities within radius (km) of a point using PostGIS.
 */
router.get('/nearby', async (req: Request, res: Response) => {
  const lat = parseFloat(req.query.lat as string);
  const lng = parseFloat(req.query.lng as string);
  const radiusKm = parseFloat(req.query.radius as string) || 50;

  if (isNaN(lat) || isNaN(lng)) {
    res.status(400).json({ error: 'lat and lng are required' });
    return;
  }

  const radiusMeters = radiusKm * 1000;

  const { rows } = await query(
    `SELECT id, name, description, lat, lng, h3_index, founder_pubkey, phase, citizen_count, governance_type, treasury_sats,
            ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance_m
     FROM cities
     WHERE ST_DWithin(geom::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
     ORDER BY distance_m
     LIMIT 50`,
    [lng, lat, radiusMeters]
  );

  res.json({
    cities: rows.map(r => ({
      ...r,
      distance_km: Math.round((r.distance_m as number) / 10) / 100,
    })),
    center: { lat, lng },
    radius_km: radiusKm,
  });
});

/**
 * GET /api/v1/cities/:id
 * Get city details by H3 index or ID.
 */
router.get('/:id', async (req: Request, res: Response) => {
  const { rows } = await query(
    `SELECT id, name, description, lat, lng, h3_index, founder_pubkey, phase, citizen_count,
            unlocked_blocks, governance_type, treasury_sats, token_supply, founded_block, founded_txid
     FROM cities WHERE id = $1`,
    [req.params.id]
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'City not found' });
    return;
  }

  res.json(rows[0]);
});

/**
 * GET /api/v1/cities/:id/citizens
 * List active citizens of a city.
 */
router.get('/:id/citizens', async (req: Request, res: Response) => {
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  const { rows } = await query(
    `SELECT pubkey, joined_block, joined_txid, last_heartbeat, territories_claimed
     FROM citizens
     WHERE city_id = $1 AND is_active = TRUE
     ORDER BY joined_block
     LIMIT $2 OFFSET $3`,
    [req.params.id, limit, offset]
  );

  res.json({ citizens: rows, city_id: req.params.id, limit, offset });
});

/**
 * GET /api/v1/cities/:id/territories
 * List active territories within a city.
 */
router.get('/:id/territories', async (req: Request, res: Response) => {
  const level = req.query.level ? parseInt(req.query.level as string) : null;
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  let sql = 'SELECT id, level, h3_index, owner_pubkey, stake_amount, lock_height, claimed_block FROM territories WHERE parent_city = $1 AND is_active = TRUE';
  const params: unknown[] = [req.params.id];

  if (level) {
    sql += ` AND level = $${params.length + 1}`;
    params.push(level);
  }

  sql += ` ORDER BY claimed_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ territories: rows, city_id: req.params.id, limit, offset });
});

/**
 * GET /api/v1/cities/:id/proposals
 * List governance proposals for a city.
 */
router.get('/:id/proposals', async (req: Request, res: Response) => {
  const status = req.query.status as string;
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  let sql = 'SELECT id, proposal_type, title, status, votes_for, votes_against, votes_abstain, proposer_pubkey, created_block, voting_ends_block FROM proposals WHERE city_id = $1';
  const params: unknown[] = [req.params.id];

  if (status) {
    sql += ` AND status = $${params.length + 1}`;
    params.push(status);
  }

  sql += ` ORDER BY created_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ proposals: rows, city_id: req.params.id, limit, offset });
});

/**
 * GET /api/v1/cities/:id/ubi
 * Get UBI info for a city.
 */
router.get('/:id/ubi', async (req: Request, res: Response) => {
  const { rows: cityRows } = await query(
    'SELECT phase, citizen_count, treasury_sats FROM cities WHERE id = $1',
    [req.params.id]
  );

  if (cityRows.length === 0) {
    res.status(404).json({ error: 'City not found' });
    return;
  }

  const city = cityRows[0];
  const isActive = city.phase === 'city' || city.phase === 'metropolis';
  const dailyPerCitizen = isActive && city.citizen_count > 0
    ? Math.floor((city.treasury_sats * 0.001) / city.citizen_count)
    : 0;
  const monthlyCap = Math.floor(city.treasury_sats * 0.01);

  // Recent claims
  const { rows: claims } = await query(
    `SELECT citizen_pubkey, claim_periods, amount_sats, block_height, txid, created_at
     FROM ubi_claims WHERE city_id = $1
     ORDER BY created_at DESC LIMIT 20`,
    [req.params.id]
  );

  res.json({
    city_id: req.params.id,
    is_active: isActive,
    phase: city.phase,
    citizen_count: city.citizen_count,
    treasury_sats: city.treasury_sats,
    daily_per_citizen: dailyPerCitizen,
    monthly_cap: monthlyCap,
    recent_claims: claims,
  });
});

export default router;
