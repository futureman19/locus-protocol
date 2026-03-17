export type ProposalType =
  | 'parameter_change'
  | 'contract_upgrade'
  | 'treasury_spend'
  | 'constitutional'
  | 'emergency';

export type ProposalStatus =
  | 'active'
  | 'passed'
  | 'rejected'
  | 'executed'
  | 'expired';

export type VoteChoice = 'yes' | 'no' | 'abstain';

export interface Proposal {
  id: string;
  proposalType: ProposalType;
  scope: number;
  title: string;
  description: string;
  actions: ProposalAction[];
  deposit: number;
  proposerPubkey: string;
  status: ProposalStatus;
  votesFor: number;
  votesAgainst: number;
  votesAbstain: number;
  voters: string[];
  createdAt: number;
  votingEndsAt: number;
  executionTxid?: string;
}

export interface ProposalAction {
  type: string;
  target: string;
  data: string;
}

export interface ProposeParams {
  proposalType: ProposalType;
  scope?: number;
  title: string;
  description?: string;
  actions?: ProposalAction[];
  deposit?: number;
  proposerPubkey: string;
}

export interface VoteParams {
  proposalId: string;
  voterPubkey: string;
  vote: VoteChoice;
  weight?: number;
}
