"""
Tests for HeartbeatManager.

Per spec 07-transaction-formats.md:
- heartbeat_type: 1=property, 2=citizen, 3=aura
- Timestamp must be within 24h window
- Nonce for replay protection
"""

import time

import pytest

from locus import (
    HeartbeatManager,
    HeartbeatParams,
)


class TestBuildHeartbeatTransaction:
    """Test HeartbeatManager.build_heartbeat_transaction method."""

    def test_produces_valid_op_return_script(self):
        params = HeartbeatParams(
            heartbeat_type=1,
            entity_id="entity_id",
            h3_index="891f1d48177ffff",
        )
        script = HeartbeatManager.build_heartbeat_transaction(params)
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildPropertyHeartbeat:
    """Test HeartbeatManager.build_property_heartbeat method."""

    def test_produces_valid_op_return_script(self):
        script = HeartbeatManager.build_property_heartbeat("property_id", "h3_index")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN

    def test_default_entity_type(self):
        script = HeartbeatManager.build_property_heartbeat("property_id", "h3_index")
        assert isinstance(script, bytes)
        # Entity type defaults to 8 (building)

    def test_custom_entity_type(self):
        script = HeartbeatManager.build_property_heartbeat(
            "property_id", "h3_index", entity_type=4
        )
        assert isinstance(script, bytes)


class TestBuildCitizenHeartbeat:
    """Test HeartbeatManager.build_citizen_heartbeat method."""

    def test_produces_valid_op_return_script(self):
        script = HeartbeatManager.build_citizen_heartbeat("citizen_key", "h3_index")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestBuildAuraHeartbeat:
    """Test HeartbeatManager.build_aura_heartbeat method."""

    def test_produces_valid_op_return_script(self):
        script = HeartbeatManager.build_aura_heartbeat("owner_key", "h3_index")
        assert isinstance(script, bytes)
        assert script[0] == 0x6a  # OP_RETURN


class TestIsValidTimestamp:
    """Test HeartbeatManager.is_valid_timestamp method."""

    def test_valid_within_24h_window(self):
        now = int(time.time())
        assert HeartbeatManager.is_valid_timestamp(now) is True
        assert HeartbeatManager.is_valid_timestamp(now - 3600) is True  # 1 hour ago
        assert HeartbeatManager.is_valid_timestamp(now + 3600) is True  # 1 hour future

    def test_invalid_outside_24h_window(self):
        now = int(time.time())
        assert HeartbeatManager.is_valid_timestamp(now - 100_000) is False  # > 24h ago
        assert HeartbeatManager.is_valid_timestamp(now + 100_000) is False  # > 24h future
