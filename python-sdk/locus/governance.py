"""
Governance Manager

Proposals, voting, execution.

Per spec 04-governance.md:
- Proposal types: parameter_change(51%), contract_upgrade(66%),
  treasury_spend(51%), constitutional(75%), emergency(7/12)
- Proposal deposit: 0.1 BSV (10,000,000 sats)
- Discussion period: 1,008 blocks (~7 days)
- Voting period: 2,016 blocks (~14 days)
- Execution delay: 432 blocks (~3 days)
- Genesis Key expires at block 2,100,000 (~Year 10)
"""

from typing import Literal

from .transaction import TransactionBuilder
from .types import (
    ProposalType,
    VoteChoice,
    CityPhase,
    ProposeParams,
)
from .constants import GOVERNANCE, PROPOSAL_THRESHOLDS, QUORUM_BY_PHASE


class GovernanceManager:
    """
    Manages governance operations including proposals, voting, and execution.
    
    Provides methods for creating proposals, tallying votes, and
    checking execution eligibility based on governance rules.
    """

    @staticmethod
    def build_propose_transaction(params: ProposeParams) -> bytes:
        """
        Build a GOV_PROPOSE transaction script.
        
        Args:
            params: Proposal parameters
            
        Returns:
            OP_RETURN script bytes
            
        Example:
            >>> script = GovernanceManager.build_propose_transaction(ProposeParams(
            ...     proposal_type='parameter_change',
            ...     title='Reduce block auction period',
            ...     proposer_pubkey='pubkey',
            ... ))
        """
        return TransactionBuilder.build_gov_propose(params)

    @staticmethod
    def build_vote_transaction(
        proposal_id: str,
        voter_pubkey: str,
        vote: VoteChoice,
    ) -> bytes:
        """
        Build a GOV_VOTE transaction script.
        
        Args:
            proposal_id: Proposal identifier
            voter_pubkey: Voter's public key
            vote: Vote choice (yes/no/abstain)
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_gov_vote(proposal_id, voter_pubkey, vote)

    @staticmethod
    def build_execute_transaction(proposal_id: str, executor_pubkey: str) -> bytes:
        """
        Build a GOV_EXEC transaction script.
        
        Args:
            proposal_id: Proposal identifier
            executor_pubkey: Executor's public key
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_gov_exec(proposal_id, executor_pubkey)

    @staticmethod
    def get_threshold(proposal_type: ProposalType) -> float:
        """
        Returns the vote threshold for a proposal type.
        
        Args:
            proposal_type: Type of proposal
            
        Returns:
            Required yes vote ratio (0.0-1.0)
            
        Example:
            >>> GovernanceManager.get_threshold('constitutional')
            0.75
        """
        return PROPOSAL_THRESHOLDS.get(proposal_type, 0.51)

    @staticmethod
    def get_quorum(phase: CityPhase) -> float:
        """
        Returns the quorum requirement for a phase.
        
        Args:
            phase: City phase
            
        Returns:
            Required voter participation ratio (0.0-1.0)
            
        Example:
            >>> GovernanceManager.get_quorum('city')
            0.4
        """
        return QUORUM_BY_PHASE.get(phase, 0.0)

    @staticmethod
    def get_proposal_deposit() -> int:
        """
        Returns the proposal deposit in satoshis.
        
        Returns:
            Deposit amount (0.1 BSV = 10,000,000 sats)
        """
        return GOVERNANCE["PROPOSAL_DEPOSIT"]

    @staticmethod
    def is_genesis_era(current_block_height: int) -> bool:
        """
        Check if we're in the Genesis Era (before block 2,100,000).
        
        Args:
            current_block_height: Current blockchain height
            
        Returns:
            True if still in Genesis Era
            
        Example:
            >>> GovernanceManager.is_genesis_era(1_000_000)
            True
            >>> GovernanceManager.is_genesis_era(2_500_000)
            False
        """
        return current_block_height < GOVERNANCE["GENESIS_KEY_EXPIRY_BLOCK"]

    @staticmethod
    def get_discussion_period() -> int:
        """
        Returns the discussion period in blocks.
        
        Returns:
            Discussion period (~1,008 blocks = ~7 days)
        """
        return GOVERNANCE["DISCUSSION_PERIOD_BLOCKS"]

    @staticmethod
    def get_voting_period() -> int:
        """
        Returns the voting period in blocks.
        
        Returns:
            Voting period (~2,016 blocks = ~14 days)
        """
        return GOVERNANCE["VOTING_PERIOD_BLOCKS"]

    @staticmethod
    def get_execution_delay() -> int:
        """
        Returns the execution delay in blocks.
        
        Returns:
            Execution delay (~432 blocks = ~3 days)
        """
        return GOVERNANCE["EXECUTION_DELAY_BLOCKS"]

    @staticmethod
    def tally(
        votes_for: int,
        votes_against: int,
        votes_abstain: int,
        citizen_count: int,
        phase: CityPhase,
        proposal_type: ProposalType,
    ) -> Literal["passed", "rejected", "pending"]:
        """
        Tally votes and determine outcome.
        
        Returns 'passed' | 'rejected' | 'pending' based on:
        - Quorum: enough total votes relative to citizen count
        - Threshold: enough yes votes relative to total votes cast
        
        Args:
            votes_for: Number of yes votes
            votes_against: Number of no votes
            votes_abstain: Number of abstain votes
            citizen_count: Total citizens eligible to vote
            phase: Current city phase
            proposal_type: Type of proposal
            
        Returns:
            Proposal status: 'passed', 'rejected', or 'pending'
            
        Example:
            >>> GovernanceManager.tally(8, 2, 1, 25, 'city', 'parameter_change')
            'passed'
        """
        total_votes = votes_for + votes_against + votes_abstain
        quorum = GovernanceManager.get_quorum(phase)
        threshold = GovernanceManager.get_threshold(proposal_type)

        # Check quorum
        if quorum > 0 and total_votes < (citizen_count * quorum):
            return "pending"

        # Check threshold
        total_cast = votes_for + votes_against
        if total_cast == 0:
            return "pending"

        if votes_for / total_cast >= threshold:
            return "passed"

        return "rejected"

    @staticmethod
    def can_execute(
        voting_ends_at: int,
        current_block_height: int,
        proposal_type: ProposalType,
    ) -> bool:
        """
        Check if execution delay has been met.
        
        Args:
            voting_ends_at: Block height when voting ended
            current_block_height: Current blockchain height
            proposal_type: Type of proposal
            
        Returns:
            True if proposal can be executed
            
        Example:
            >>> GovernanceManager.can_execute(800_000, 800_500, 'parameter_change')
            True
        """
        # Emergency proposals execute without delay
        if proposal_type == "emergency":
            return True
        return current_block_height >= voting_ends_at + GOVERNANCE["EXECUTION_DELAY_BLOCKS"]
