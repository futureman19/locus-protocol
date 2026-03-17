import { Router, Request, Response } from 'express';
import { query } from '../db/pool';

const router = Router();

/**
 * GET /api/v1/objects/:id
 * Get object details by ID (deploy txid).
 */
router.get('/:id', async (req: Request, res: Response) => {
  const { rows } = await query(
    `SELECT id, object_type, h3_index, owner_pubkey, stake_amount, content_hash, manifest_hash,
            parent_territory, capabilities, deployed_block, deployed_txid, is_active, destroyed_block
     FROM objects WHERE id = $1`,
    [req.params.id]
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'Object not found' });
    return;
  }

  res.json(rows[0]);
});

/**
 * GET /api/v1/objects
 * List objects with optional filters.
 */
router.get('/', async (req: Request, res: Response) => {
  const owner = req.query.owner as string;
  const type = req.query.type as string;
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  let sql = 'SELECT id, object_type, h3_index, owner_pubkey, stake_amount, content_hash, parent_territory, deployed_block FROM objects WHERE is_active = TRUE';
  const params: unknown[] = [];

  if (owner) {
    sql += ` AND owner_pubkey = $${params.length + 1}`;
    params.push(owner);
  }
  if (type) {
    sql += ` AND object_type = $${params.length + 1}`;
    params.push(type);
  }

  sql += ` ORDER BY deployed_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ objects: rows, limit, offset });
});

export default router;
