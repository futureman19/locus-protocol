/**
 * GovernanceManager — proposals, voting, execution.
 *
 * Per spec 04-governance.md:
 * - Proposal types: parameter_change(51%), contract_upgrade(66%),
 *   treasury_spend(51%), constitutional(75%), emergency(7/12)
 * - Proposal deposit: 0.1 BSV (10,000,000 sats)
 * - Discussion period: 1,008 blocks (~7 days)
 * - Voting period: 2,016 blocks (~14 days)
 * - Execution delay: 432 blocks (~3 days)
 * - Genesis Key expires at block 2,100,000 (~Year 10)
 */

import { ProposalType, VoteChoice, CityPhase, ProposeParams } from '../types';
import { TransactionBuilder } from './transaction-builder';
import {
  GOVERNANCE,
  PROPOSAL_THRESHOLDS,
  QUORUM_BY_PHASE,
} from '../constants/stakes';

export class GovernanceManager {
  /** Build a GOV_PROPOSE transaction script. */
  static buildProposeTransaction(params: ProposeParams): Buffer {
    return TransactionBuilder.buildGovPropose(params);
  }

  /** Build a GOV_VOTE transaction script. */
  static buildVoteTransaction(proposalId: string, voterPubkey: string, vote: VoteChoice): Buffer {
    return TransactionBuilder.buildGovVote(proposalId, voterPubkey, vote);
  }

  /** Build a GOV_EXEC transaction script. */
  static buildExecuteTransaction(proposalId: string, executorPubkey: string): Buffer {
    return TransactionBuilder.buildGovExec(proposalId, executorPubkey);
  }

  /** Returns the vote threshold for a proposal type. */
  static getThreshold(proposalType: ProposalType): number {
    return PROPOSAL_THRESHOLDS[proposalType] ?? 0.51;
  }

  /** Returns the quorum requirement for a phase. */
  static getQuorum(phase: CityPhase): number {
    return QUORUM_BY_PHASE[phase] ?? 0;
  }

  /** Returns the proposal deposit in satoshis. */
  static getProposalDeposit(): number {
    return GOVERNANCE.PROPOSAL_DEPOSIT;
  }

  /** Check if we're in the Genesis Era (before block 2,100,000). */
  static isGenesisEra(currentBlockHeight: number): boolean {
    return currentBlockHeight < GOVERNANCE.GENESIS_KEY_EXPIRY_BLOCK;
  }

  /** Returns the discussion period in blocks. */
  static getDiscussionPeriod(): number {
    return GOVERNANCE.DISCUSSION_PERIOD_BLOCKS;
  }

  /** Returns the voting period in blocks. */
  static getVotingPeriod(): number {
    return GOVERNANCE.VOTING_PERIOD_BLOCKS;
  }

  /** Returns the execution delay in blocks. */
  static getExecutionDelay(): number {
    return GOVERNANCE.EXECUTION_DELAY_BLOCKS;
  }

  /**
   * Tally votes and determine outcome.
   *
   * Returns 'passed' | 'rejected' | 'pending' based on:
   * - Quorum: enough total votes relative to citizen count
   * - Threshold: enough yes votes relative to total votes cast
   */
  static tally(
    votesFor: number,
    votesAgainst: number,
    votesAbstain: number,
    citizenCount: number,
    phase: CityPhase,
    proposalType: ProposalType,
  ): 'passed' | 'rejected' | 'pending' {
    const totalVotes = votesFor + votesAgainst + votesAbstain;
    const quorum = GovernanceManager.getQuorum(phase);
    const threshold = GovernanceManager.getThreshold(proposalType);

    // Check quorum
    if (quorum > 0 && totalVotes < Math.ceil(citizenCount * quorum)) {
      return 'pending';
    }

    // Check threshold
    const totalCast = votesFor + votesAgainst;
    if (totalCast === 0) return 'pending';

    if (votesFor / totalCast >= threshold) {
      return 'passed';
    }

    return 'rejected';
  }

  /** Check if execution delay has been met. */
  static canExecute(
    votingEndsAt: number,
    currentBlockHeight: number,
    proposalType: ProposalType,
  ): boolean {
    // Emergency proposals execute without delay
    if (proposalType === 'emergency') return true;
    return currentBlockHeight >= votingEndsAt + GOVERNANCE.EXECUTION_DELAY_BLOCKS;
  }
}
