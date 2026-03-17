import { TxContext } from './index';

const VOTING_PERIOD_BLOCKS = 2016;

export async function handleGovPropose(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const proposalType = data['proposal_type'] as string | number;
  const scope = (data['scope'] as number) || 0;
  const title = data['title'] as string;
  const description = (data['description'] as string) || '';
  const actions = data['actions'] || [];
  const deposit = data['deposit'] as number;
  const proposerPubkey = data['proposer_pubkey'] as string;
  const cityId = (data['city_id'] as string) || null;

  // Resolve proposal type name from code if numeric
  const typeNames: Record<number, string> = {
    1: 'parameter_change', 2: 'contract_upgrade', 3: 'treasury_spend',
    4: 'constitutional', 5: 'emergency',
  };
  const typeName = typeof proposalType === 'number'
    ? (typeNames[proposalType] || 'unknown')
    : proposalType;

  const votingEndsBlock = ctx.blockHeight + VOTING_PERIOD_BLOCKS;

  await ctx.client.query(
    `INSERT INTO proposals (id, proposal_type, scope, title, description, actions, deposit, proposer_pubkey, created_block, created_txid, voting_ends_block, city_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     ON CONFLICT (id) DO NOTHING`,
    [ctx.txid, typeName, scope, title, description, JSON.stringify(actions), deposit, proposerPubkey, ctx.blockHeight, ctx.txid, votingEndsBlock, cityId]
  );

  ctx.logger.info({ proposalId: ctx.txid, type: typeName, title }, 'Proposal created');
}

export async function handleGovVote(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const proposalId = data['proposal_id'] as string;
  const voterPubkey = data['voter_pubkey'] as string;
  const vote = data['vote'] as number; // 0=no, 1=yes, 2=abstain
  if (!proposalId || !voterPubkey) return;

  await ctx.client.query(
    `INSERT INTO votes (proposal_id, voter_pubkey, vote, block_height, txid)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (proposal_id, voter_pubkey) DO UPDATE SET vote = $3, block_height = $4, txid = $5`,
    [proposalId, voterPubkey, vote, ctx.blockHeight, ctx.txid]
  );

  // Update vote tallies
  const voteColumn = vote === 1 ? 'votes_for' : vote === 0 ? 'votes_against' : 'votes_abstain';
  await ctx.client.query(
    `UPDATE proposals SET ${voteColumn} = ${voteColumn} + 1, updated_at = NOW() WHERE id = $1`,
    [proposalId]
  );

  ctx.logger.info({ proposalId, voter: voterPubkey, vote }, 'Vote recorded');
}

export async function handleGovExec(ctx: TxContext, data: Record<string, unknown>): Promise<void> {
  const proposalId = data['proposal_id'] as string;
  if (!proposalId) return;

  await ctx.client.query(
    `UPDATE proposals SET status = 'executed', execution_txid = $1, updated_at = NOW() WHERE id = $2`,
    [ctx.txid, proposalId]
  );

  ctx.logger.info({ proposalId, executionTxid: ctx.txid }, 'Proposal executed');
}
