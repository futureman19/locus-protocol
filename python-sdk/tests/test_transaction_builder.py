"""
Tests for TransactionBuilder.

Per spec 07-transaction-formats.md:
OP_RETURN "LOCUS" {version:1} {type:1} {msgpack payload}
"""

import pytest
from hypothesis import given, strategies as st

from locus import (
    TransactionBuilder,
    PROTOCOL_PREFIX,
    PROTOCOL_VERSION,
    TYPE_CODES,
    REVERSE_CODES,
    CityFoundParams,
    TerritoryClaimParams,
    ObjectDeployParams,
    ProposeParams,
    HeartbeatParams,
    ProposalAction,
)


class TestEncodeDecodeRoundtrip:
    """Test encode/decode roundtrip."""

    def test_round_trips_city_found_message(self):
        payload = {"name": "Neo-Tokyo", "stake": 3_200_000_000}
        script = TransactionBuilder.encode("city_found", payload)

        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "city_found"
        assert decoded.version == PROTOCOL_VERSION
        assert decoded.data["name"] == "Neo-Tokyo"
        assert decoded.data["stake"] == 3_200_000_000

    def test_round_trips_territory_claim_message(self):
        payload = {"level": 8, "location": "891f1d48177ffff"}
        script = TransactionBuilder.encode("territory_claim", payload)
        decoded = TransactionBuilder.decode(script)

        assert decoded.type == "territory_claim"
        assert decoded.data["level"] == 8

    def test_round_trips_gov_vote_message(self):
        payload = {"proposal_id": "abc123", "vote": 1}
        script = TransactionBuilder.encode("gov_vote", payload)
        decoded = TransactionBuilder.decode(script)

        assert decoded.type == "gov_vote"
        assert decoded.data["vote"] == 1

    def test_round_trips_ubi_claim_message(self):
        payload = {"city_id": "city1", "claim_periods": 7}
        script = TransactionBuilder.encode("ubi_claim", payload)
        decoded = TransactionBuilder.decode(script)

        assert decoded.type == "ubi_claim"
        assert decoded.data["claim_periods"] == 7


class TestEncodeErrors:
    """Test encode error handling."""

    def test_rejects_unknown_type(self):
        with pytest.raises(ValueError, match="Unknown message type"):
            TransactionBuilder.encode("bogus", {})  # type: ignore


class TestDecodeErrors:
    """Test decode error handling."""

    def test_rejects_non_op_return_data(self):
        with pytest.raises(ValueError):
            TransactionBuilder.decode(bytes([0x00, 0x01, 0x02]))

    def test_rejects_invalid_protocol_prefix(self):
        # Valid OP_RETURN but invalid protocol
        script = bytes([0x6a, 0x05]) + b"OTHER"
        with pytest.raises(ValueError, match="Not a LOCUS protocol message"):
            TransactionBuilder.decode(script)


class TestTypeCodes:
    """Test type codes match spec 07."""

    def test_has_all_17_territory_protocol_types(self):
        assert len(TYPE_CODES) == 17

    def test_city_found_0x01(self):
        assert TYPE_CODES["city_found"] == 0x01

    def test_citizen_join_0x03(self):
        assert TYPE_CODES["citizen_join"] == 0x03

    def test_territory_claim_0x10(self):
        assert TYPE_CODES["territory_claim"] == 0x10

    def test_object_deploy_0x20(self):
        assert TYPE_CODES["object_deploy"] == 0x20

    def test_heartbeat_0x30(self):
        assert TYPE_CODES["heartbeat"] == 0x30

    def test_ghost_invoke_0x40(self):
        assert TYPE_CODES["ghost_invoke"] == 0x40

    def test_gov_propose_0x50(self):
        assert TYPE_CODES["gov_propose"] == 0x50

    def test_ubi_claim_0x60(self):
        assert TYPE_CODES["ubi_claim"] == 0x60


class TestPayloadBuilders:
    """Test payload builder methods."""

    def test_build_city_found(self):
        params = CityFoundParams(
            name="TestCity",
            description="A test city",
            lat=35.6762,
            lng=139.6503,
            h3_res7="8f283080dcb019d",
            founder_pubkey="pubkey_data",
        )
        script = TransactionBuilder.build_city_found(params)

        decoded = TransactionBuilder.decode(script)
        assert decoded.data["name"] == "TestCity"
        assert decoded.data["location"]["h3_res7"] == "8f283080dcb019d"

    def test_build_territory_claim(self):
        params = TerritoryClaimParams(
            level=8,
            h3_index="891f1d48177ffff",
            owner_pubkey="owner_key",
            stake_amount=800_000_000,
            lock_height=821_600,
        )
        script = TransactionBuilder.build_territory_claim(params)

        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "territory_claim"
        assert decoded.data["stake_amount"] == 800_000_000

    def test_build_gov_vote(self):
        script = TransactionBuilder.build_gov_vote("proposal_id", "voter_key", "yes")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "gov_vote"
        assert decoded.data["vote"] == 1

    def test_build_gov_vote_no(self):
        script = TransactionBuilder.build_gov_vote("proposal_id", "voter_key", "no")
        decoded = TransactionBuilder.decode(script)
        assert decoded.data["vote"] == 0

    def test_build_gov_vote_abstain(self):
        script = TransactionBuilder.build_gov_vote("proposal_id", "voter_key", "abstain")
        decoded = TransactionBuilder.decode(script)
        assert decoded.data["vote"] == 2

    def test_build_ubi_claim(self):
        script = TransactionBuilder.build_ubi_claim("city_id", "citizen_key", 7)
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "ubi_claim"
        assert decoded.data["claim_periods"] == 7

    def test_build_heartbeat(self):
        params = HeartbeatParams(
            heartbeat_type=2,
            entity_id="citizen_pubkey",
            h3_index="891f1d48177ffff",
        )
        script = TransactionBuilder.build_heartbeat(params)

        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "heartbeat"
        assert decoded.data["heartbeat_type"] == 2

    def test_build_object_deploy(self):
        params = ObjectDeployParams(
            object_type="agent",
            h3_index="891f1d48177ffff",
            owner_pubkey="owner_key",
            stake_amount=10_000_000,
            content_hash="abc123",
            parent_territory="parent_hex",
        )
        script = TransactionBuilder.build_object_deploy(params)

        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "object_deploy"
        assert decoded.data["object_type"] == "agent"

    def test_build_object_destroy(self):
        script = TransactionBuilder.build_object_destroy("object_id", "owner_key", "no longer needed")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "object_destroy"
        assert decoded.data["reason"] == "no longer needed"

    def test_build_ghost_invoke(self):
        script = TransactionBuilder.build_ghost_invoke("ghost_id", "invoker_key", "h3_index", "session_1")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "ghost_invoke"
        assert decoded.data["ghost_id"] == "ghost_id"
        assert decoded.data["session_id"] == "session_1"

    def test_build_ghost_payment(self):
        script = TransactionBuilder.build_ghost_payment("ghost_id", "payer_key", 1_000_000, "service_1")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "ghost_payment"
        assert decoded.data["amount"] == 1_000_000

    def test_build_gov_propose(self):
        params = ProposeParams(
            proposal_type="parameter_change",
            title="Test Proposal",
            proposer_pubkey="proposer_key",
            description="A test proposal",
            actions=[ProposalAction("update", "param1", "value1")],
        )
        script = TransactionBuilder.build_gov_propose(params)
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "gov_propose"
        assert decoded.data["title"] == "Test Proposal"

    def test_build_gov_exec(self):
        script = TransactionBuilder.build_gov_exec("proposal_id", "executor_key")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "gov_exec"
        assert decoded.data["proposal_id"] == "proposal_id"

    def test_build_citizen_join(self):
        script = TransactionBuilder.build_citizen_join("city_id", "citizen_key")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "citizen_join"
        assert decoded.data["city_id"] == "city_id"

    def test_build_citizen_leave(self):
        script = TransactionBuilder.build_citizen_leave("city_id", "citizen_key")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "citizen_leave"
        assert decoded.data["citizen_pubkey"] == "citizen_key"

    def test_build_territory_transfer(self):
        script = TransactionBuilder.build_territory_transfer("territory_id", "from_key", "to_key", 1_000_000)
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "territory_transfer"
        assert decoded.data["price"] == 1_000_000

    def test_build_territory_release(self):
        script = TransactionBuilder.build_territory_release("territory_id", "owner_key")
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "territory_release"
        assert decoded.data["territory_id"] == "territory_id"

    def test_build_object_update(self):
        script = TransactionBuilder.build_object_update("object_id", "owner_key", {"name": "New Name"})
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "object_update"
        assert decoded.data["updates"]["name"] == "New Name"

    def test_build_city_update(self):
        script = TransactionBuilder.build_city_update("city_id", "updater_key", {"description": "Updated"})
        decoded = TransactionBuilder.decode(script)
        assert decoded.type == "city_update"
        assert decoded.data["updates"]["description"] == "Updated"
