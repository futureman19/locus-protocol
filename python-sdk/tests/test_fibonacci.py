"""
Tests for Fibonacci sequence calculations.

Per spec 02-city-lifecycle.md:
- Blocks unlock based on CITIZEN COUNT
- Sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34...
"""

import pytest
from hypothesis import given, strategies as st

from locus import (
    fibonacci_sequence,
    fibonacci_sum,
    blocks_for_citizens,
    phase_for_citizens,
    governance_for_phase,
    phase_number,
)


class TestFibonacciSequence:
    """Test fibonacci_sequence function."""

    def test_returns_empty_for_0(self):
        assert fibonacci_sequence(0) == []

    def test_returns_1_for_1(self):
        assert fibonacci_sequence(1) == [1]

    def test_returns_1_1_for_2(self):
        assert fibonacci_sequence(2) == [1, 1]

    def test_returns_first_5_fibonacci_numbers(self):
        assert fibonacci_sequence(5) == [1, 1, 2, 3, 5]

    def test_returns_first_10_fibonacci_numbers(self):
        assert fibonacci_sequence(10) == [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]

    @given(st.integers(min_value=3, max_value=50))
    def test_each_number_is_sum_of_previous_two(self, n):
        result = fibonacci_sequence(n)
        for i in range(2, len(result)):
            assert result[i] == result[i - 1] + result[i - 2]


class TestFibonacciSum:
    """Test fibonacci_sum function."""

    def test_sum_of_first_1(self):
        assert fibonacci_sum(1) == 1

    def test_sum_of_first_5(self):
        assert fibonacci_sum(5) == 12  # 1+1+2+3+5

    def test_sum_of_first_10(self):
        assert fibonacci_sum(10) == 143

    @given(st.integers(min_value=1, max_value=100))
    def test_sum_matches_sequence(self, n):
        assert fibonacci_sum(n) == sum(fibonacci_sequence(n))


class TestBlocksForCitizens:
    """Test blocks_for_citizens function per spec 02 table."""

    def test_0_citizens_0_blocks(self):
        assert blocks_for_citizens(0) == 0

    def test_1_citizen_2_blocks_genesis(self):
        assert blocks_for_citizens(1) == 2

    def test_2_3_citizens_2_blocks_settlement(self):
        assert blocks_for_citizens(2) == 2
        assert blocks_for_citizens(3) == 2

    def test_4_8_citizens_5_blocks_village(self):
        assert blocks_for_citizens(4) == 5
        assert blocks_for_citizens(8) == 5

    def test_9_20_citizens_8_blocks_town(self):
        assert blocks_for_citizens(9) == 8
        assert blocks_for_citizens(20) == 8

    def test_21_50_citizens_16_blocks_city(self):
        assert blocks_for_citizens(21) == 16
        assert blocks_for_citizens(50) == 16

    def test_51_plus_citizens_24_blocks_metropolis(self):
        assert blocks_for_citizens(51) == 24
        assert blocks_for_citizens(100) == 24
        assert blocks_for_citizens(1000) == 24

    @given(st.integers(min_value=0, max_value=10000))
    def test_returns_non_negative(self, n):
        assert blocks_for_citizens(n) >= 0


class TestPhaseForCitizens:
    """Test phase_for_citizens function."""

    def test_0_citizens_none(self):
        assert phase_for_citizens(0) == "none"

    def test_1_citizen_genesis(self):
        assert phase_for_citizens(1) == "genesis"

    def test_2_3_citizens_settlement(self):
        assert phase_for_citizens(2) == "settlement"
        assert phase_for_citizens(3) == "settlement"

    def test_4_8_citizens_village(self):
        assert phase_for_citizens(4) == "village"
        assert phase_for_citizens(8) == "village"

    def test_9_20_citizens_town(self):
        assert phase_for_citizens(9) == "town"
        assert phase_for_citizens(20) == "town"

    def test_21_50_citizens_city(self):
        assert phase_for_citizens(21) == "city"
        assert phase_for_citizens(50) == "city"

    def test_51_plus_citizens_metropolis(self):
        assert phase_for_citizens(51) == "metropolis"
        assert phase_for_citizens(200) == "metropolis"


class TestGovernanceForPhase:
    """Test governance_for_phase function."""

    def test_genesis_settlement_founder(self):
        assert governance_for_phase("genesis") == "founder"
        assert governance_for_phase("settlement") == "founder"

    def test_village_tribal_council(self):
        assert governance_for_phase("village") == "tribal_council"

    def test_town_republic(self):
        assert governance_for_phase("town") == "republic"

    def test_city_direct_democracy(self):
        assert governance_for_phase("city") == "direct_democracy"

    def test_metropolis_senate(self):
        assert governance_for_phase("metropolis") == "senate"


class TestPhaseNumber:
    """Test phase_number function."""

    def test_returns_correct_phase_numbers(self):
        assert phase_number("genesis") == 0
        assert phase_number("settlement") == 1
        assert phase_number("village") == 2
        assert phase_number("town") == 3
        assert phase_number("city") == 4
        assert phase_number("metropolis") == 5
