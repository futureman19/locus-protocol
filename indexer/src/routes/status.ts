import { Router, Request, Response } from 'express';
import { query } from '../db/pool';

const router = Router();

/**
 * GET /api/v1/status
 * Indexer sync status and protocol statistics.
 */
router.get('/', async (req: Request, res: Response) => {
  const [syncResult, statsResult] = await Promise.all([
    query('SELECT last_block_height, last_block_hash, updated_at FROM sync_state WHERE id = 1'),
    query(`
      SELECT
        (SELECT COUNT(*) FROM cities) AS city_count,
        (SELECT COUNT(*) FROM citizens WHERE is_active = TRUE) AS citizen_count,
        (SELECT COUNT(*) FROM territories WHERE is_active = TRUE) AS territory_count,
        (SELECT COUNT(*) FROM objects WHERE is_active = TRUE) AS object_count,
        (SELECT COUNT(*) FROM proposals) AS proposal_count,
        (SELECT COUNT(*) FROM transactions) AS transaction_count
    `),
  ]);

  const sync = syncResult.rows[0] || { last_block_height: 0, last_block_hash: null, updated_at: null };
  const stats = statsResult.rows[0];

  res.json({
    sync: {
      last_block_height: sync.last_block_height,
      last_block_hash: sync.last_block_hash,
      updated_at: sync.updated_at,
    },
    stats: {
      cities: parseInt(stats.city_count),
      citizens: parseInt(stats.citizen_count),
      territories: parseInt(stats.territory_count),
      objects: parseInt(stats.object_count),
      proposals: parseInt(stats.proposal_count),
      transactions: parseInt(stats.transaction_count),
    },
  });
});

/**
 * GET /api/v1/transactions/:txid
 * Get indexed transaction by txid.
 */
router.get('/transactions/:txid', async (req: Request, res: Response) => {
  const { rows } = await query(
    'SELECT txid, message_type, message_type_name, block_height, block_hash, block_time, payload FROM transactions WHERE txid = $1',
    [req.params.txid]
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'Transaction not found' });
    return;
  }

  res.json(rows[0]);
});

export default router;
