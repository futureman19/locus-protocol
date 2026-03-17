"""
Tests for CityManager.

Per spec 02-city-lifecycle.md:
- Cities are the core /32 primitive
- 6 phases driven by citizen count
- 32 BSV founding stake with 21,600-block CLTV lock
"""

import pytest

from locus import (
    CityManager,
    CityFoundParams,
    CityPolicies,
    TOKEN_DISTRIBUTION,
    LOCK_PERIOD_BLOCKS,
)


class TestGetPhase:
    """Test CityManager.get_phase method."""

    def test_returns_correct_phases(self):
        assert CityManager.get_phase(0) == "none"
        assert CityManager.get_phase(1) == "genesis"
        assert CityManager.get_phase(3) == "settlement"
        assert CityManager.get_phase(5) == "village"
        assert CityManager.get_phase(15) == "town"
        assert CityManager.get_phase(25) == "city"
        assert CityManager.get_phase(100) == "metropolis"


class TestGetGovernanceType:
    """Test CityManager.get_governance_type method."""

    def test_genesis_founder(self):
        assert CityManager.get_governance_type("genesis") == "founder"

    def test_settlement_founder(self):
        assert CityManager.get_governance_type("settlement") == "founder"

    def test_city_direct_democracy(self):
        assert CityManager.get_governance_type("city") == "direct_democracy"

    def test_metropolis_senate(self):
        assert CityManager.get_governance_type("metropolis") == "senate"


class TestGetUnlockedBlocks:
    """Test CityManager.get_unlocked_blocks method."""

    def test_matches_spec_02_table(self):
        assert CityManager.get_unlocked_blocks(1) == 2
        assert CityManager.get_unlocked_blocks(4) == 5
        assert CityManager.get_unlocked_blocks(9) == 8
        assert CityManager.get_unlocked_blocks(21) == 16
        assert CityManager.get_unlocked_blocks(51) == 24


class TestGetFoundingStake:
    """Test CityManager.get_founding_stake method."""

    def test_returns_32_bsv(self):
        assert CityManager.get_founding_stake() == 3_200_000_000


class TestGetLockHeight:
    """Test CityManager.get_lock_height method."""

    def test_adds_21600_blocks(self):
        assert CityManager.get_lock_height(800_000) == 821_600

    def test_uses_lock_period_constant(self):
        assert CityManager.get_lock_height(0) == LOCK_PERIOD_BLOCKS


class TestGetTokenDistribution:
    """Test CityManager.get_token_distribution method."""

    def test_totals_3_2m_tokens(self):
        dist = CityManager.get_token_distribution()
        assert dist.total == 3_200_000
        assert dist.founder == 640_000      # 20%
        assert dist.treasury == 1_600_000   # 50%
        assert dist.public_sale == 800_000  # 25%
        assert dist.protocol_dev == 160_000  # 5%
        assert dist.founder + dist.treasury + dist.public_sale + dist.protocol_dev == dist.total


class TestFounderVestedTokens:
    """Test CityManager.founder_vested_tokens method."""

    def test_0_months_0_tokens(self):
        assert CityManager.founder_vested_tokens(0) == 0

    def test_6_months_50_percent_vested(self):
        assert CityManager.founder_vested_tokens(6) == 320_000

    def test_12_months_fully_vested(self):
        assert CityManager.founder_vested_tokens(12) == 640_000

    def test_24_months_still_only_640000_capped(self):
        assert CityManager.founder_vested_tokens(24) == 640_000

    def test_negative_months_zero(self):
        assert CityManager.founder_vested_tokens(-5) == 0


class TestIsUBIActive:
    """Test CityManager.is_ubi_active method."""

    def test_inactive_in_early_phases(self):
        assert CityManager.is_ubi_active("genesis") is False
        assert CityManager.is_ubi_active("settlement") is False
        assert CityManager.is_ubi_active("village") is False
        assert CityManager.is_ubi_active("town") is False

    def test_active_in_city_and_metropolis(self):
        assert CityManager.is_ubi_active("city") is True
        assert CityManager.is_ubi_active("metropolis") is True


class TestGetLockPeriod:
    """Test CityManager.get_lock_period method."""

    def test_returns_lock_period_blocks(self):
        assert CityManager.get_lock_period() == LOCK_PERIOD_BLOCKS


class TestBuildFoundTransaction:
    """Test CityManager.build_found_transaction method."""

    def test_produces_valid_op_return_script(self):
        params = CityFoundParams(
            name="Neo-Tokyo",
            description="A cyberpunk city",
            lat=35.6762,
            lng=139.6503,
            h3_res7="8f283080dcb019d",
            founder_pubkey="abcdef1234567890",
        )
        script = CityManager.build_found_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_with_policies(self):
        params = CityFoundParams(
            name="TestCity",
            lat=0.0,
            lng=0.0,
            h3_res7="8f283080dcb019d",
            founder_pubkey="pubkey",
            policies=CityPolicies(
                block_auction_period=86400,
                block_starting_bid=1_000_000,
                immigration_policy="open",
            ),
        )
        script = CityManager.build_found_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildJoinTransaction:
    """Test CityManager.build_join_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = CityManager.build_join_transaction("city123", "citizen_pubkey")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildLeaveTransaction:
    """Test CityManager.build_leave_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = CityManager.build_leave_transaction("city123", "citizen_pubkey")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN
