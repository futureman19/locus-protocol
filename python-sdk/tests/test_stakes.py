"""
Tests for stake calculations.

Per spec 03-staking-economics.md:
- Progressive property tax: cost = base * 2^(n-1)
- Emergency unlock penalty: 10%
"""

import pytest
from hypothesis import given, strategies as st

from locus import (
    stake_for_level,
    stake_for_object_type,
    calculate_lock_height,
    calculate_penalty,
    calculate_emergency_return,
    progressive_tax,
    LOCK_PERIOD_BLOCKS,
    EMERGENCY_PENALTY_RATE,
)


class TestStakeForLevel:
    """Test stake_for_level function."""

    def test_32_city_32_bsv(self):
        assert stake_for_level(32) == 3_200_000_000

    def test_16_block_8_bsv(self):
        assert stake_for_level(16) == 800_000_000

    def test_8_building_8_bsv(self):
        assert stake_for_level(8) == 800_000_000

    def test_4_home_4_bsv(self):
        assert stake_for_level(4) == 400_000_000

    def test_other_levels_return_0(self):
        assert stake_for_level(128) == 0
        assert stake_for_level(64) == 0
        assert stake_for_level(2) == 0
        assert stake_for_level(1) == 0


class TestStakeForObjectType:
    """Test stake_for_object_type function."""

    def test_item_00001_bsv(self):
        assert stake_for_object_type("item") == 10_000

    def test_waypoint_05_bsv_min(self):
        assert stake_for_object_type("waypoint") == 50_000_000

    def test_agent_01_bsv_min(self):
        assert stake_for_object_type("agent") == 10_000_000

    def test_billboard_10_bsv_min(self):
        assert stake_for_object_type("billboard") == 1_000_000_000

    def test_rare_16_bsv(self):
        assert stake_for_object_type("rare") == 1_600_000_000

    def test_epic_32_bsv(self):
        assert stake_for_object_type("epic") == 3_200_000_000

    def test_legendary_64_bsv(self):
        assert stake_for_object_type("legendary") == 6_400_000_000


class TestCalculateLockHeight:
    """Test calculate_lock_height function."""

    def test_adds_21600_blocks(self):
        assert calculate_lock_height(800_000) == 821_600

    def test_adds_lock_period(self):
        assert calculate_lock_height(0) == LOCK_PERIOD_BLOCKS
        assert calculate_lock_height(1_000_000) == 1_000_000 + LOCK_PERIOD_BLOCKS


class TestCalculatePenalty:
    """Test calculate_penalty function."""

    def test_10_percent_penalty_per_spec(self):
        stake = 3_200_000_000  # 32 BSV
        assert calculate_penalty(stake) == 320_000_000  # 3.2 BSV

    def test_small_stake(self):
        assert calculate_penalty(1_000) == 100  # 10% of 1000

    def test_uses_emergency_penalty_rate(self):
        stake = 10_000_000
        expected = int(stake * EMERGENCY_PENALTY_RATE)
        assert calculate_penalty(stake) == expected


class TestCalculateEmergencyReturn:
    """Test calculate_emergency_return function."""

    def test_returns_90_percent_of_stake(self):
        stake = 3_200_000_000
        assert calculate_emergency_return(stake) == 2_880_000_000  # 28.8 BSV

    def test_penalty_plus_return_equals_original(self):
        stake = 3_200_000_000
        penalty = calculate_penalty(stake)
        returned = calculate_emergency_return(stake)
        assert penalty + returned == stake

    @given(st.integers(min_value=1, max_value=1_000_000_000_000))
    def test_penalty_plus_return_always_equals_stake(self, stake):
        penalty = calculate_penalty(stake)
        returned = calculate_emergency_return(stake)
        assert penalty + returned == stake


class TestProgressiveTax:
    """Test progressive_tax function."""

    def test_progressive_doubling_per_spec(self):
        base = 800_000_000  # 8 BSV for building
        assert progressive_tax(base, 1) == 800_000_000
        assert progressive_tax(base, 2) == 1_600_000_000
        assert progressive_tax(base, 3) == 3_200_000_000
        assert progressive_tax(base, 4) == 6_400_000_000

    def test_city_founding_progressive_tax(self):
        base = 3_200_000_000  # 32 BSV for city
        assert progressive_tax(base, 1) == 3_200_000_000   # 32 BSV
        assert progressive_tax(base, 2) == 6_400_000_000   # 64 BSV
        assert progressive_tax(base, 3) == 12_800_000_000  # 128 BSV
        assert progressive_tax(base, 5) == 51_200_000_000  # 512 BSV

    @given(
        st.integers(min_value=1, max_value=1_000_000_000),
        st.integers(min_value=1, max_value=20),
    )
    def test_progressive_tax_formula(self, base, n):
        expected = base * (2 ** (n - 1))
        assert progressive_tax(base, n) == expected
