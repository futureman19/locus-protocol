"""
LocusClient — main entry point for the territory-centric Locus Protocol SDK.

Cities are the core primitive. Ghosts are just one type of /1 Object.
"""

from typing import Optional

from .broadcaster import ARCBroadcaster
from .city import CityManager
from .territory import TerritoryManager
from .object import ObjectManager
from .treasury import TreasuryManager
from .governance import GovernanceManager
from .heartbeat import HeartbeatManager
from .transaction import TransactionBuilder
from .types import Network, ARCBroadcastResult


class LocusClient:
    """
    Main client for interacting with the Locus Protocol.
    
    Provides access to all protocol operations including city management,
    territory claims, object deployment, governance, and transaction broadcasting.
    
    Example:
        >>> from locus import LocusClient, CityManager
        
        >>> client = LocusClient(network='testnet')
        
        >>> # Found a city (32 BSV stake)
        >>> script = CityManager.build_found_transaction({
        ...     'name': 'Neo-Tokyo',
        ...     'lat': 35.6762,
        ...     'lng': 139.6503,
        ...     'h3_res7': '8f283080dcb019d',
        ...     'founder_pubkey': '02abc...',
        ... })
        
        >>> # Get city phase by citizen count
        >>> phase = CityManager.get_phase(25)  # 'city'
    """

    def __init__(
        self,
        network: Network = "testnet",
        arc_api_key: Optional[str] = None,
    ):
        """
        Initialize Locus client.
        
        Args:
            network: Network to connect to (mainnet/testnet/stn)
            arc_api_key: Optional API key for ARC
        """
        self.network: Network = network
        self.broadcaster = ARCBroadcaster(network, arc_api_key)

    def broadcast(self, tx_hex: str) -> ARCBroadcastResult:
        """
        Broadcast a raw transaction hex to the BSV network.
        
        Args:
            tx_hex: Raw transaction in hexadecimal
            
        Returns:
            Broadcast result
        """
        return self.broadcaster.broadcast(tx_hex)

    def get_transaction_status(self, txid: str) -> ARCBroadcastResult:
        """
        Query transaction status from ARC.
        
        Args:
            txid: Transaction ID
            
        Returns:
            Transaction status
        """
        return self.broadcaster.get_status(txid)


# Manager modules exposed for convenience (matching TypeScript SDK)
LocusClient.city = CityManager
LocusClient.territory = TerritoryManager
LocusClient.objects = ObjectManager
LocusClient.treasury = TreasuryManager
LocusClient.governance = GovernanceManager
LocusClient.heartbeat = HeartbeatManager
LocusClient.tx = TransactionBuilder
