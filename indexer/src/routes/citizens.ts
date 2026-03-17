import { Router, Request, Response } from 'express';
import { query } from '../db/pool';

const router = Router();

/**
 * GET /api/v1/citizens/:pubkey
 * Get citizen info across all cities.
 */
router.get('/:pubkey', async (req: Request, res: Response) => {
  const { rows } = await query(
    `SELECT c.pubkey, c.city_id, c.joined_block, c.joined_txid, c.last_heartbeat,
            c.territories_claimed, c.is_active, c.left_block,
            ci.name AS city_name, ci.phase AS city_phase
     FROM citizens c
     LEFT JOIN cities ci ON c.city_id = ci.id
     WHERE c.pubkey = $1
     ORDER BY c.is_active DESC, c.joined_block DESC`,
    [req.params.pubkey]
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'Citizen not found' });
    return;
  }

  // Return citizen with all city memberships
  res.json({
    pubkey: req.params.pubkey,
    memberships: rows,
    active_cities: rows.filter(r => r.is_active).length,
  });
});

/**
 * GET /api/v1/citizens/:pubkey/territories
 * List territories owned by a citizen.
 */
router.get('/:pubkey/territories', async (req: Request, res: Response) => {
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  const { rows } = await query(
    `SELECT id, level, h3_index, stake_amount, lock_height, parent_city, claimed_block
     FROM territories
     WHERE owner_pubkey = $1 AND is_active = TRUE
     ORDER BY claimed_block DESC
     LIMIT $2 OFFSET $3`,
    [req.params.pubkey, limit, offset]
  );

  res.json({ territories: rows, pubkey: req.params.pubkey, limit, offset });
});

/**
 * GET /api/v1/citizens/:pubkey/objects
 * List objects owned by a citizen.
 */
router.get('/:pubkey/objects', async (req: Request, res: Response) => {
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  const { rows } = await query(
    `SELECT id, object_type, h3_index, stake_amount, content_hash, parent_territory, deployed_block
     FROM objects
     WHERE owner_pubkey = $1 AND is_active = TRUE
     ORDER BY deployed_block DESC
     LIMIT $2 OFFSET $3`,
    [req.params.pubkey, limit, offset]
  );

  res.json({ objects: rows, pubkey: req.params.pubkey, limit, offset });
});

export default router;
