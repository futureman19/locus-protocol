"""
Tests for ObjectManager.

Per spec 01-territory-hierarchy.md:
Objects are the /1 level — the smallest unit in Geo-IPv6.
Types: item, waypoint, agent/ghost, billboard, rare, epic, legendary
"""

import pytest

from locus import (
    ObjectManager,
    ObjectDeployParams,
    OBJECT_STAKES,
)


class TestGetMinStake:
    """Test ObjectManager.get_min_stake method."""

    def test_item_stake(self):
        assert ObjectManager.get_min_stake("item") == OBJECT_STAKES["ITEM"]

    def test_waypoint_stake(self):
        assert ObjectManager.get_min_stake("waypoint") == OBJECT_STAKES["WAYPOINT_MIN"]

    def test_agent_stake(self):
        assert ObjectManager.get_min_stake("agent") == OBJECT_STAKES["AGENT_MIN"]

    def test_billboard_stake(self):
        assert ObjectManager.get_min_stake("billboard") == OBJECT_STAKES["BILLBOARD_MIN"]

    def test_rare_stake(self):
        assert ObjectManager.get_min_stake("rare") == OBJECT_STAKES["RARE"]

    def test_epic_stake(self):
        assert ObjectManager.get_min_stake("epic") == OBJECT_STAKES["EPIC"]

    def test_legendary_stake(self):
        assert ObjectManager.get_min_stake("legendary") == OBJECT_STAKES["LEGENDARY"]


class TestBuildDeployTransaction:
    """Test ObjectManager.build_deploy_transaction method."""

    def test_produces_valid_op_return_script(self):
        params = ObjectDeployParams(
            object_type="agent",
            h3_index="891f1d48177ffff",
            owner_pubkey="owner_key",
            stake_amount=10_000_000,
            content_hash="abc123",
            parent_territory="parent_hex",
        )
        script = ObjectManager.build_deploy_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_with_capabilities(self):
        params = ObjectDeployParams(
            object_type="agent",
            h3_index="891f1d48177ffff",
            owner_pubkey="owner_key",
            stake_amount=10_000_000,
            content_hash="abc123",
            parent_territory="parent_hex",
            capabilities=["ghost", "oracle"],
        )
        script = ObjectManager.build_deploy_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildUpdateTransaction:
    """Test ObjectManager.build_update_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = ObjectManager.build_update_transaction(
            "object_id",
            "owner_key",
            {"name": "New Name", "status": "active"},
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildDestroyTransaction:
    """Test ObjectManager.build_destroy_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = ObjectManager.build_destroy_transaction("object_id", "owner_key")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_with_reason(self):
        script = ObjectManager.build_destroy_transaction(
            "object_id",
            "owner_key",
            "no longer needed",
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildGhostInvokeTransaction:
    """Test ObjectManager.build_ghost_invoke_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = ObjectManager.build_ghost_invoke_transaction(
            "ghost_id",
            "invoker_key",
            "h3_index",
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_with_session_id(self):
        script = ObjectManager.build_ghost_invoke_transaction(
            "ghost_id",
            "invoker_key",
            "h3_index",
            "session_123",
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildGhostPaymentTransaction:
    """Test ObjectManager.build_ghost_payment_transaction method."""

    def test_produces_valid_op_return_script(self):
        script = ObjectManager.build_ghost_payment_transaction(
            "ghost_id",
            "payer_key",
            1_000_000,
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_with_service_id(self):
        script = ObjectManager.build_ghost_payment_transaction(
            "ghost_id",
            "payer_key",
            5_000_000,
            "service_456",
        )
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN
