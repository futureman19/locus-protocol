"""
Tests for GovernanceManager.

Per spec 04-governance.md:
- Proposal types with different thresholds
- Proposal deposit: 0.1 BSV
- Discussion, voting, and execution periods
"""

import pytest

from locus import (
    GovernanceManager,
    ProposeParams,
    GOVERNANCE,
)


class TestGetThreshold:
    """Test GovernanceManager.get_threshold method."""

    def test_parameter_change_51_percent(self):
        assert GovernanceManager.get_threshold("parameter_change") == 0.51

    def test_contract_upgrade_66_percent(self):
        assert GovernanceManager.get_threshold("contract_upgrade") == 0.66

    def test_constitutional_75_percent(self):
        assert GovernanceManager.get_threshold("constitutional") == 0.75

    def test_emergency_58_3_percent(self):
        assert GovernanceManager.get_threshold("emergency") == 0.583

    def test_default_51_percent(self):
        assert GovernanceManager.get_threshold("treasury_spend") == 0.51


class TestGetQuorum:
    """Test GovernanceManager.get_quorum method."""

    def test_village_67_percent(self):
        assert GovernanceManager.get_quorum("village") == 0.67

    def test_town_60_percent(self):
        assert GovernanceManager.get_quorum("town") == 0.60

    def test_city_40_percent(self):
        assert GovernanceManager.get_quorum("city") == 0.40

    def test_metropolis_51_percent(self):
        assert GovernanceManager.get_quorum("metropolis") == 0.51


class TestIsGenesisEra:
    """Test GovernanceManager.is_genesis_era method."""

    def test_true_before_block_2100000(self):
        assert GovernanceManager.is_genesis_era(0) is True
        assert GovernanceManager.is_genesis_era(2_099_999) is True

    def test_false_at_after_block_2100000(self):
        assert GovernanceManager.is_genesis_era(2_100_000) is False
        assert GovernanceManager.is_genesis_era(3_000_000) is False


class TestTally:
    """Test GovernanceManager.tally method."""

    def test_passes_with_51_percent_for_parameter_change(self):
        # 8/(8+2) = 80% > 51%, quorum: 11/25 = 44% > 40%
        result = GovernanceManager.tally(8, 2, 1, 25, "city", "parameter_change")
        assert result == "passed"

    def test_rejects_when_below_threshold(self):
        # 3/11 = 27% < 51%
        result = GovernanceManager.tally(3, 8, 0, 25, "city", "parameter_change")
        assert result == "rejected"

    def test_pending_when_quorum_not_met(self):
        # 3/25 = 12% < 40% quorum
        result = GovernanceManager.tally(3, 0, 0, 25, "city", "parameter_change")
        assert result == "pending"

    def test_constitutional_requires_75_percent(self):
        # 7/11 = 63.6% < 75%
        result = GovernanceManager.tally(7, 4, 0, 25, "city", "constitutional")
        assert result == "rejected"

    def test_constitutional_passes_at_75_percent(self):
        # 9/11 = 81.8% > 75%
        result = GovernanceManager.tally(9, 2, 0, 25, "city", "constitutional")
        assert result == "passed"


class TestCanExecute:
    """Test GovernanceManager.can_execute method."""

    def test_requires_execution_delay_for_normal_proposals(self):
        assert GovernanceManager.can_execute(800_000, 800_100, "parameter_change") is False
        assert GovernanceManager.can_execute(800_000, 800_432, "parameter_change") is True

    def test_emergency_proposals_execute_without_delay(self):
        assert GovernanceManager.can_execute(800_000, 800_001, "emergency") is True


class TestGetProposalDeposit:
    """Test GovernanceManager.get_proposal_deposit method."""

    def test_returns_01_bsv(self):
        assert GovernanceManager.get_proposal_deposit() == 10_000_000


class TestGetDiscussionPeriod:
    """Test GovernanceManager.get_discussion_period method."""

    def test_returns_discussion_period_blocks(self):
        assert GovernanceManager.get_discussion_period() == GOVERNANCE["DISCUSSION_PERIOD_BLOCKS"]


class TestGetVotingPeriod:
    """Test GovernanceManager.get_voting_period method."""

    def test_returns_voting_period_blocks(self):
        assert GovernanceManager.get_voting_period() == GOVERNANCE["VOTING_PERIOD_BLOCKS"]


class TestGetExecutionDelay:
    """Test GovernanceManager.get_execution_delay method."""

    def test_returns_execution_delay_blocks(self):
        assert GovernanceManager.get_execution_delay() == GOVERNANCE["EXECUTION_DELAY_BLOCKS"]


class TestBuildProposeTransaction:
    """Test GovernanceManager.build_propose_transaction method."""

    def test_produces_valid_op_return_script(self):
        params = ProposeParams(
            proposal_type="parameter_change",
            title="Test Proposal",
            proposer_pubkey="proposer_key",
        )
        script = GovernanceManager.build_propose_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildVoteTransaction:
    """Test GovernanceManager.build_vote_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = GovernanceManager.build_vote_transaction("proposal_id", "voter_key", "yes")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildExecuteTransaction:
    """Test GovernanceManager.build_execute_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = GovernanceManager.build_execute_transaction("proposal_id", "executor_key")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN
