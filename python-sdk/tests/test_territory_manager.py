"""
Tests for TerritoryManager.

Per spec 01-territory-hierarchy.md:
/128 Continent → /64 Country → /32 City → /16 Block → /8 Building → /4 Home → /2 Aura → /1 Object
"""

import pytest

from locus import (
    TerritoryManager,
    TerritoryClaimParams,
    LOCK_PERIOD_BLOCKS,
)


class TestGetStakeForLevel:
    """Test TerritoryManager.get_stake_for_level method."""

    def test_returns_correct_stakes_per_spec(self):
        assert TerritoryManager.get_stake_for_level(32) == 3_200_000_000  # 32 BSV
        assert TerritoryManager.get_stake_for_level(16) == 800_000_000    # 8 BSV
        assert TerritoryManager.get_stake_for_level(8) == 800_000_000     # 8 BSV
        assert TerritoryManager.get_stake_for_level(4) == 400_000_000     # 4 BSV


class TestGetProgressiveTax:
    """Test TerritoryManager.get_progressive_tax method."""

    def test_doubles_per_additional_property(self):
        # Building at 8 BSV
        assert TerritoryManager.get_progressive_tax(8, 1) == 800_000_000
        assert TerritoryManager.get_progressive_tax(8, 2) == 1_600_000_000
        assert TerritoryManager.get_progressive_tax(8, 3) == 3_200_000_000

    def test_city_founding_progressive_tax(self):
        assert TerritoryManager.get_progressive_tax(32, 1) == 3_200_000_000
        assert TerritoryManager.get_progressive_tax(32, 2) == 6_400_000_000


class TestDistributeFees:
    """Test TerritoryManager.distribute_fees method."""

    def test_splits_50_40_10_per_spec(self):
        fees = TerritoryManager.distribute_fees(10_000)
        assert fees.developer == 5_000   # 50%
        assert fees.territory == 4_000   # 40%
        assert fees.protocol == 1_000    # 10%

    def test_handles_uneven_splits(self):
        fees = TerritoryManager.distribute_fees(10)
        # Integer division may cause slight variance
        assert fees.developer + fees.territory + fees.protocol <= 10


class TestDistributeTerritoryFees:
    """Test TerritoryManager.distribute_territory_fees method."""

    def test_splits_territory_share_50_30_20(self):
        breakdown = TerritoryManager.distribute_territory_fees(4_000)
        assert breakdown.building == 2_000  # 50% of territory
        assert breakdown.city == 1_200       # 30% of territory
        assert breakdown.block == 800        # 20% of territory


class TestGetLockHeight:
    """Test TerritoryManager.get_lock_height method."""

    def test_adds_21600_blocks(self):
        assert TerritoryManager.get_lock_height(800_000) == 821_600

    def test_uses_lock_period_constant(self):
        assert TerritoryManager.get_lock_height(0) == LOCK_PERIOD_BLOCKS


class TestBuildClaimTransaction:
    """Test TerritoryManager.build_claim_transaction method."""

    def test_produces_valid_op_return_script(self):
        params = TerritoryClaimParams(
            level=8,
            h3_index="891f1d48177ffff",
            owner_pubkey="owner_key_hex",
            stake_amount=800_000_000,
            lock_height=821_600,
        )
        script = TerritoryManager.build_claim_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_with_parent_city(self):
        params = TerritoryClaimParams(
            level=16,
            h3_index="8f283080dcb019d",
            owner_pubkey="owner_key",
            stake_amount=800_000_000,
            lock_height=821_600,
            parent_city="city123",
            metadata={"name": "Block 1"},
        )
        script = TerritoryManager.build_claim_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildReleaseTransaction:
    """Test TerritoryManager.build_release_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = TerritoryManager.build_release_transaction("territory123", "owner_pubkey")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildTransferTransaction:
    """Test TerritoryManager.build_transfer_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = TerritoryManager.build_transfer_transaction(
            "territory123",
            "from_pubkey",
            "to_pubkey",
            1_000_000,
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_default_price_zero(self):
        script = TerritoryManager.build_transfer_transaction(
            "territory123",
            "from_pubkey",
            "to_pubkey",
        )
        assert isinstance(script, bytes)
