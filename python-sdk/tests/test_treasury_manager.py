"""
Tests for TreasuryManager.

Per spec 03-staking-economics.md:
- UBI formula and eligibility
- Token redemption calculations
- Founder vesting schedule
"""

import pytest

from locus import (
    TreasuryManager,
    TOKEN_DISTRIBUTION,
    UBI,
)


class TestCalculateDailyUBI:
    """Test TreasuryManager.calculate_daily_ubi method."""

    def test_follows_formula(self):
        # 1000 BSV treasury, 25 citizens
        treasury = 100_000_000_000  # 1000 BSV in sats
        daily = TreasuryManager.calculate_daily_ubi(treasury, 25)
        assert daily == 4_000_000  # 0.04 BSV per citizen

    def test_returns_0_for_0_citizens(self):
        assert TreasuryManager.calculate_daily_ubi(100_000_000_000, 0) == 0

    def test_returns_0_for_negative_citizens(self):
        assert TreasuryManager.calculate_daily_ubi(100_000_000_000, -5) == 0


class TestCalculateMonthlyCap:
    """Test TreasuryManager.calculate_monthly_cap method."""

    def test_caps_at_1_percent_of_treasury(self):
        treasury = 100_000_000_000  # 1000 BSV
        assert TreasuryManager.calculate_monthly_cap(treasury) == 1_000_000_000  # 10 BSV


class TestIsUBIEligible:
    """Test TreasuryManager.is_ubi_eligible method."""

    def test_requires_city_phase_and_min_treasury(self):
        # Below min treasury
        assert TreasuryManager.is_ubi_eligible("city", 5_000_000_000) is False

        # Wrong phase
        assert TreasuryManager.is_ubi_eligible("town", 100_000_000_000) is False

        # Both correct
        assert TreasuryManager.is_ubi_eligible("city", 100_000_000_000) is True
        assert TreasuryManager.is_ubi_eligible("metropolis", 100_000_000_000) is True


class TestGetUBIInfo:
    """Test TreasuryManager.get_ubi_info method."""

    def test_returns_complete_ubi_info_when_active(self):
        info = TreasuryManager.get_ubi_info("city", 100_000_000_000, 25)
        assert info.is_active is True
        assert info.daily_per_citizen == 4_000_000
        assert info.citizen_count == 25
        assert info.min_treasury == UBI["MIN_TREASURY_SATS"]

    def test_returns_inactive_ubi_for_early_phases(self):
        info = TreasuryManager.get_ubi_info("village", 100_000_000_000, 5)
        assert info.is_active is False
        assert info.daily_per_citizen == 0


class TestRedemptionRate:
    """Test TreasuryManager.redemption_rate method."""

    def test_rate_equals_treasury_divided_by_supply(self):
        rate = TreasuryManager.redemption_rate(100_000_000_000, 3_200_000)
        assert rate == pytest.approx(31250, 0)  # 100B sats / 3.2M tokens

    def test_default_total_supply(self):
        rate1 = TreasuryManager.redemption_rate(100_000_000_000)
        rate2 = TreasuryManager.redemption_rate(100_000_000_000, TOKEN_DISTRIBUTION["TOTAL_SUPPLY"])
        assert rate1 == rate2


class TestRedeemTokens:
    """Test TreasuryManager.redeem_tokens method."""

    def test_calculates_bsv_for_token_redemption(self):
        bsv = TreasuryManager.redeem_tokens(1000, 100_000_000_000, 3_200_000)
        assert bsv == 31_250_000  # 1000 * (100B / 3.2M) = 31.25M sats


class TestVestedFounderTokens:
    """Test TreasuryManager.vested_founder_tokens method."""

    def test_matches_city_manager_vesting(self):
        assert TreasuryManager.vested_founder_tokens(0) == 0
        assert TreasuryManager.vested_founder_tokens(6) == 320_000
        assert TreasuryManager.vested_founder_tokens(12) == 640_000


class TestBuildClaimTransaction:
    """Test TreasuryManager.build_claim_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = TreasuryManager.build_claim_transaction("city_id", "citizen_key", 7)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN
