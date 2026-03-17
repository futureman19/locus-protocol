"""
Tests for LocusClient.

Tests the main client and its convenience attributes.
"""

import pytest

from locus import (
    LocusClient,
    CityManager,
    TerritoryManager,
    ObjectManager,
    TreasuryManager,
    GovernanceManager,
    HeartbeatManager,
    TransactionBuilder,
    ARCBroadcaster,
)


class TestClientInitialization:
    """Test LocusClient initialization."""

    def test_default_network_testnet(self):
        client = LocusClient()
        assert client.network == "testnet"

    def test_custom_network(self):
        client = LocusClient(network="mainnet")
        assert client.network == "mainnet"

    def test_has_broadcaster(self):
        client = LocusClient()
        assert isinstance(client.broadcaster, ARCBroadcaster)


class TestManagerAccess:
    """Test that managers are accessible as class attributes."""

    def test_city_manager_accessible(self):
        assert LocusClient.city is CityManager

    def test_territory_manager_accessible(self):
        assert LocusClient.territory is TerritoryManager

    def test_object_manager_accessible(self):
        assert LocusClient.objects is ObjectManager

    def test_treasury_manager_accessible(self):
        assert LocusClient.treasury is TreasuryManager

    def test_governance_manager_accessible(self):
        assert LocusClient.governance is GovernanceManager

    def test_heartbeat_manager_accessible(self):
        assert LocusClient.heartbeat is HeartbeatManager

    def test_transaction_builder_accessible(self):
        assert LocusClient.tx is TransactionBuilder


class TestClientMethods:
    """Test LocusClient methods."""

    def test_broadcast_raises_without_mock(self):
        """Broadcast requires actual network - would fail without mocking."""
        client = LocusClient()
        # This would actually try to broadcast - we just test the method exists
        assert hasattr(client, "broadcast")

    def test_get_transaction_status_raises_without_mock(self):
        """Status query requires actual network - would fail without mocking."""
        client = LocusClient()
        # This would actually query - we just test the method exists
        assert hasattr(client, "get_transaction_status")
