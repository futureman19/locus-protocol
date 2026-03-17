import { Router, Request, Response } from 'express';
import { query } from '../db/pool';

const router = Router();

/**
 * GET /api/v1/proposals/:id
 * Get proposal details.
 */
router.get('/:id', async (req: Request, res: Response) => {
  const { rows } = await query(
    `SELECT id, proposal_type, scope, title, description, actions, deposit, proposer_pubkey,
            status, votes_for, votes_against, votes_abstain, created_block, created_txid,
            voting_ends_block, execution_txid, city_id
     FROM proposals WHERE id = $1`,
    [req.params.id]
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'Proposal not found' });
    return;
  }

  res.json(rows[0]);
});

/**
 * GET /api/v1/proposals/:id/votes
 * List votes on a proposal.
 */
router.get('/:id/votes', async (req: Request, res: Response) => {
  const { rows } = await query(
    `SELECT voter_pubkey, vote, block_height, txid
     FROM votes
     WHERE proposal_id = $1
     ORDER BY block_height`,
    [req.params.id]
  );

  const voteLabels = { 0: 'no', 1: 'yes', 2: 'abstain' };
  res.json({
    proposal_id: req.params.id,
    votes: rows.map(r => ({
      ...r,
      vote_label: voteLabels[r.vote as keyof typeof voteLabels] || 'unknown',
    })),
  });
});

/**
 * GET /api/v1/proposals
 * List proposals with optional filters.
 */
router.get('/', async (req: Request, res: Response) => {
  const status = req.query.status as string;
  const type = req.query.type as string;
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const offset = parseInt(req.query.offset as string) || 0;

  let sql = 'SELECT id, proposal_type, title, status, votes_for, votes_against, votes_abstain, proposer_pubkey, created_block, voting_ends_block, city_id FROM proposals WHERE 1=1';
  const params: unknown[] = [];

  if (status) {
    sql += ` AND status = $${params.length + 1}`;
    params.push(status);
  }
  if (type) {
    sql += ` AND proposal_type = $${params.length + 1}`;
    params.push(type);
  }

  sql += ` ORDER BY created_block DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limit, offset);

  const { rows } = await query(sql, params);
  res.json({ proposals: rows, limit, offset });
});

export default router;
