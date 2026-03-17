"""
Tests for constants.

Verifies all protocol constants match specifications.
"""

import pytest

from locus import (
    PROTOCOL_PREFIX,
    PROTOCOL_VERSION,
    TYPE_CODES,
    PROPOSAL_TYPE_CODES,
    VOTE_CODES,
    TERRITORY_STAKES,
    OBJECT_STAKES,
    TOKEN_DISTRIBUTION,
    LOCK_PERIOD_BLOCKS,
    EMERGENCY_PENALTY_RATE,
    FEE_DISTRIBUTION,
    TERRITORY_FEE_SPLIT,
    UBI,
    GOVERNANCE,
    PROPOSAL_THRESHOLDS,
    QUORUM_BY_PHASE,
    DUST_LIMIT,
    DEFAULT_FEE_RATE,
    ARC_ENDPOINTS,
)


class TestProtocolConstants:
    """Test protocol identification constants."""

    def test_protocol_prefix_is_locus(self):
        assert PROTOCOL_PREFIX == "LOCUS"

    def test_protocol_version_is_1(self):
        assert PROTOCOL_VERSION == 0x01


class TestTypeCodes:
    """Test transaction type codes."""

    def test_all_17_types_defined(self):
        assert len(TYPE_CODES) == 17

    def test_city_codes_sequential(self):
        assert TYPE_CODES["city_found"] == 0x01
        assert TYPE_CODES["city_update"] == 0x02
        assert TYPE_CODES["citizen_join"] == 0x03
        assert TYPE_CODES["citizen_leave"] == 0x04

    def test_territory_codes_start_at_0x10(self):
        assert TYPE_CODES["territory_claim"] == 0x10
        assert TYPE_CODES["territory_release"] == 0x11
        assert TYPE_CODES["territory_transfer"] == 0x12

    def test_object_codes_start_at_0x20(self):
        assert TYPE_CODES["object_deploy"] == 0x20
        assert TYPE_CODES["object_update"] == 0x21
        assert TYPE_CODES["object_destroy"] == 0x22

    def test_heartbeat_at_0x30(self):
        assert TYPE_CODES["heartbeat"] == 0x30

    def test_ghost_codes_at_0x40(self):
        assert TYPE_CODES["ghost_invoke"] == 0x40
        assert TYPE_CODES["ghost_payment"] == 0x41

    def test_governance_codes_at_0x50(self):
        assert TYPE_CODES["gov_propose"] == 0x50
        assert TYPE_CODES["gov_vote"] == 0x51
        assert TYPE_CODES["gov_exec"] == 0x52

    def test_ubi_at_0x60(self):
        assert TYPE_CODES["ubi_claim"] == 0x60


class TestProposalTypeCodes:
    """Test proposal type codes."""

    def test_parameter_change_0x01(self):
        assert PROPOSAL_TYPE_CODES["parameter_change"] == 0x01

    def test_contract_upgrade_0x02(self):
        assert PROPOSAL_TYPE_CODES["contract_upgrade"] == 0x02

    def test_treasury_spend_0x03(self):
        assert PROPOSAL_TYPE_CODES["treasury_spend"] == 0x03

    def test_constitutional_0x04(self):
        assert PROPOSAL_TYPE_CODES["constitutional"] == 0x04

    def test_emergency_0x05(self):
        assert PROPOSAL_TYPE_CODES["emergency"] == 0x05


class TestVoteCodes:
    """Test vote value codes."""

    def test_no_is_0(self):
        assert VOTE_CODES["no"] == 0

    def test_yes_is_1(self):
        assert VOTE_CODES["yes"] == 1

    def test_abstain_is_2(self):
        assert VOTE_CODES["abstain"] == 2


class TestTerritoryStakes:
    """Test territory stake amounts (in satoshis)."""

    def test_city_32_bsv(self):
        assert TERRITORY_STAKES["CITY"] == 3_200_000_000

    def test_block_private_8_bsv(self):
        assert TERRITORY_STAKES["BLOCK_PRIVATE"] == 800_000_000

    def test_building_8_bsv(self):
        assert TERRITORY_STAKES["BUILDING"] == 800_000_000

    def test_home_4_bsv(self):
        assert TERRITORY_STAKES["HOME"] == 400_000_000


class TestObjectStakes:
    """Test object stake amounts (in satoshis)."""

    def test_item_00001_bsv(self):
        assert OBJECT_STAKES["ITEM"] == 10_000

    def test_waypoint_min_05_bsv(self):
        assert OBJECT_STAKES["WAYPOINT_MIN"] == 50_000_000

    def test_waypoint_max_4_bsv(self):
        assert OBJECT_STAKES["WAYPOINT_MAX"] == 400_000_000

    def test_agent_min_01_bsv(self):
        assert OBJECT_STAKES["AGENT_MIN"] == 10_000_000

    def test_billboard_min_10_bsv(self):
        assert OBJECT_STAKES["BILLBOARD_MIN"] == 1_000_000_000

    def test_rare_16_bsv(self):
        assert OBJECT_STAKES["RARE"] == 1_600_000_000

    def test_epic_32_bsv(self):
        assert OBJECT_STAKES["EPIC"] == 3_200_000_000

    def test_legendary_64_bsv(self):
        assert OBJECT_STAKES["LEGENDARY"] == 6_400_000_000


class TestTokenDistribution:
    """Test token distribution constants."""

    def test_total_supply_3_2m(self):
        assert TOKEN_DISTRIBUTION["TOTAL_SUPPLY"] == 3_200_000

    def test_founder_20_percent(self):
        assert TOKEN_DISTRIBUTION["FOUNDER"] == 640_000

    def test_treasury_50_percent(self):
        assert TOKEN_DISTRIBUTION["TREASURY"] == 1_600_000

    def test_public_sale_25_percent(self):
        assert TOKEN_DISTRIBUTION["PUBLIC_SALE"] == 800_000

    def test_protocol_dev_5_percent(self):
        assert TOKEN_DISTRIBUTION["PROTOCOL_DEV"] == 160_000

    def test_percentages_sum_to_100(self):
        total = (
            TOKEN_DISTRIBUTION["FOUNDER"]
            + TOKEN_DISTRIBUTION["TREASURY"]
            + TOKEN_DISTRIBUTION["PUBLIC_SALE"]
            + TOKEN_DISTRIBUTION["PROTOCOL_DEV"]
        )
        assert total == TOKEN_DISTRIBUTION["TOTAL_SUPPLY"]

    def test_founder_vest_months(self):
        assert TOKEN_DISTRIBUTION["FOUNDER_VEST_MONTHS"] == 12

    def test_dev_vest_months(self):
        assert TOKEN_DISTRIBUTION["DEV_VEST_MONTHS"] == 24


class TestLockPeriod:
    """Test lock period constants."""

    def test_lock_period_21600_blocks(self):
        assert LOCK_PERIOD_BLOCKS == 21_600

    def test_emergency_penalty_10_percent(self):
        assert EMERGENCY_PENALTY_RATE == 0.10


class TestFeeDistribution:
    """Test fee distribution percentages."""

    def test_developer_50_percent(self):
        assert FEE_DISTRIBUTION["DEVELOPER"] == 0.50

    def test_territory_40_percent(self):
        assert FEE_DISTRIBUTION["TERRITORY"] == 0.40

    def test_protocol_10_percent(self):
        assert FEE_DISTRIBUTION["PROTOCOL"] == 0.10

    def test_percentages_sum_to_100(self):
        assert FEE_DISTRIBUTION["DEVELOPER"] + FEE_DISTRIBUTION["TERRITORY"] + FEE_DISTRIBUTION["PROTOCOL"] == 1.0


class TestTerritoryFeeSplit:
    """Test territory fee split percentages."""

    def test_building_50_percent(self):
        assert TERRITORY_FEE_SPLIT["BUILDING"] == 0.50

    def test_city_30_percent(self):
        assert TERRITORY_FEE_SPLIT["CITY"] == 0.30

    def test_block_20_percent(self):
        assert TERRITORY_FEE_SPLIT["BLOCK"] == 0.20

    def test_percentages_sum_to_100(self):
        assert TERRITORY_FEE_SPLIT["BUILDING"] + TERRITORY_FEE_SPLIT["CITY"] + TERRITORY_FEE_SPLIT["BLOCK"] == 1.0


class TestUBI:
    """Test UBI constants."""

    def test_rate_0_1_percent(self):
        assert UBI["RATE"] == 0.001

    def test_monthly_cap_1_percent(self):
        assert UBI["MONTHLY_CAP_RATE"] == 0.01

    def test_min_treasury_100_bsv(self):
        assert UBI["MIN_TREASURY_SATS"] == 10_000_000_000


class TestGovernance:
    """Test governance constants."""

    def test_proposal_deposit_01_bsv(self):
        assert GOVERNANCE["PROPOSAL_DEPOSIT"] == 10_000_000

    def test_discussion_period_1008_blocks(self):
        assert GOVERNANCE["DISCUSSION_PERIOD_BLOCKS"] == 1_008

    def test_voting_period_2016_blocks(self):
        assert GOVERNANCE["VOTING_PERIOD_BLOCKS"] == 2_016

    def test_execution_delay_432_blocks(self):
        assert GOVERNANCE["EXECUTION_DELAY_BLOCKS"] == 432

    def test_genesis_key_expiry_2100000(self):
        assert GOVERNANCE["GENESIS_KEY_EXPIRY_BLOCK"] == 2_100_000


class TestProposalThresholds:
    """Test proposal threshold percentages."""

    def test_parameter_change_51_percent(self):
        assert PROPOSAL_THRESHOLDS["parameter_change"] == 0.51

    def test_contract_upgrade_66_percent(self):
        assert PROPOSAL_THRESHOLDS["contract_upgrade"] == 0.66

    def test_treasury_spend_51_percent(self):
        assert PROPOSAL_THRESHOLDS["treasury_spend"] == 0.51

    def test_constitutional_75_percent(self):
        assert PROPOSAL_THRESHOLDS["constitutional"] == 0.75

    def test_emergency_58_3_percent(self):
        assert PROPOSAL_THRESHOLDS["emergency"] == 0.583


class TestQuorumByPhase:
    """Test quorum requirements by phase."""

    def test_village_67_percent(self):
        assert QUORUM_BY_PHASE["village"] == 0.67

    def test_town_60_percent(self):
        assert QUORUM_BY_PHASE["town"] == 0.60

    def test_city_40_percent(self):
        assert QUORUM_BY_PHASE["city"] == 0.40

    def test_metropolis_51_percent(self):
        assert QUORUM_BY_PHASE["metropolis"] == 0.51


class TestNetworkConstants:
    """Test network-related constants."""

    def test_dust_limit_546(self):
        assert DUST_LIMIT == 546

    def test_default_fee_rate_05(self):
        assert DEFAULT_FEE_RATE == 0.5


class TestARCEndpoints:
    """Test ARC endpoint URLs."""

    def test_mainnet_endpoint(self):
        assert ARC_ENDPOINTS["mainnet"] == "https://arc.taal.com"

    def test_testnet_endpoint(self):
        assert ARC_ENDPOINTS["testnet"] == "https://arc.gorillapool.io"

    def test_stn_endpoint(self):
        assert ARC_ENDPOINTS["stn"] == "https://arc.stn.gorillapool.io"
