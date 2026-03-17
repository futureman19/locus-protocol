import { Router, Request, Response } from 'express';
import { query } from '../db/pool';

const router = Router();

/**
 * GET /api/v1/territories/:id
 * Get territory details by H3 index.
 */
router.get('/:id', async (req: Request, res: Response) => {
  const { rows } = await query(
    `SELECT id, level, h3_index, owner_pubkey, stake_amount, lock_height, parent_city,
            claimed_block, claimed_txid, is_active, released_block, metadata
     FROM territories WHERE id = $1`,
    [req.params.id]
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'Territory not found' });
    return;
  }

  res.json(rows[0]);
});

/**
 * GET /api/v1/territories/:id/objects
 * List objects deployed within a territory.
 */
router.get('/:id/objects', async (req: Request, res: Response) => {
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;
  const objectType = req.query.type as string;

  let sql = 'SELECT id, object_type, h3_index, owner_pubkey, stake_amount, content_hash, capabilities, deployed_block FROM objects WHERE parent_territory = $1 AND is_active = TRUE';
  const params: unknown[] = [req.params.id];

  if (objectType) {
    sql += ` AND object_type = $${params.length + 1}`;
    params.push(objectType);
  }

  sql += ` ORDER BY deployed_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ objects: rows, territory_id: req.params.id, limit, offset });
});

/**
 * GET /api/v1/territories
 * List territories with optional filters.
 */
router.get('/', async (req: Request, res: Response) => {
  const owner = req.query.owner as string;
  const level = req.query.level ? parseInt(req.query.level as string) : null;
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  let sql = 'SELECT id, level, h3_index, owner_pubkey, stake_amount, lock_height, parent_city, claimed_block FROM territories WHERE is_active = TRUE';
  const params: unknown[] = [];

  if (owner) {
    sql += ` AND owner_pubkey = $${params.length + 1}`;
    params.push(owner);
  }
  if (level) {
    sql += ` AND level = $${params.length + 1}`;
    params.push(level);
  }

  sql += ` ORDER BY claimed_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ territories: rows, limit, offset });
});

export default router;
