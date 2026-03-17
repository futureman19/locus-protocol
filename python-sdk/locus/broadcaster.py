"""
ARC Broadcaster

Broadcast transactions to BSV network via ARC (API for Remote Communication).
"""

from typing import Optional
import requests

from .types import ARCConfig, ARCBroadcastResult, Network
from .constants import ARC_ENDPOINTS


class ARCBroadcaster:
    """
    Broadcasts transactions to the BSV network via ARC.
    
    Supports mainnet, testnet, and STN networks with optional API key
    for authenticated endpoints.
    """

    def __init__(self, network: Network = "testnet", api_key: Optional[str] = None):
        """
        Initialize ARC broadcaster.
        
        Args:
            network: Network to broadcast to (mainnet/testnet/stn)
            api_key: Optional API key for authenticated endpoints
        """
        self.config = ARCConfig(
            endpoint=ARC_ENDPOINTS[network],
            api_key=api_key,
        )

    def broadcast(self, tx_hex: str) -> ARCBroadcastResult:
        """
        Broadcast a raw transaction hex to the network.
        
        Args:
            tx_hex: Raw transaction in hexadecimal
            
        Returns:
            Broadcast result with txid and status
            
        Raises:
            requests.RequestException: If broadcast fails
            
        Example:
            >>> broadcaster = ARCBroadcaster('testnet')
            >>> result = broadcaster.broadcast('01000000...')
            >>> print(result.txid)
        """
        headers: dict[str, str] = {
            "Content-Type": "application/json",
        }

        if self.config.api_key:
            headers["Authorization"] = f"Bearer {self.config.api_key}"

        response = requests.post(
            f"{self.config.endpoint}/v1/tx",
            headers=headers,
            json={"rawTx": tx_hex},
            timeout=30,
        )

        if not response.ok:
            raise requests.RequestException(
                f"ARC broadcast failed ({response.status_code}): {response.text}"
            )

        data = response.json()
        return ARCBroadcastResult(
            txid=data["txid"],
            tx_status=data["txStatus"],
            block_hash=data.get("blockHash"),
            block_height=data.get("blockHeight"),
        )

    def get_status(self, txid: str) -> ARCBroadcastResult:
        """
        Query transaction status.
        
        Args:
            txid: Transaction ID
            
        Returns:
            Transaction status
            
        Raises:
            requests.RequestException: If query fails
            
        Example:
            >>> broadcaster = ARCBroadcaster('testnet')
            >>> status = broadcaster.get_status('txid...')
            >>> print(status.tx_status)
        """
        headers: dict[str, str] = {}
        if self.config.api_key:
            headers["Authorization"] = f"Bearer {self.config.api_key}"

        response = requests.get(
            f"{self.config.endpoint}/v1/tx/{txid}",
            headers=headers,
            timeout=30,
        )

        if not response.ok:
            raise requests.RequestException(
                f"ARC status query failed ({response.status_code})"
            )

        data = response.json()
        return ARCBroadcastResult(
            txid=data["txid"],
            tx_status=data["txStatus"],
            block_hash=data.get("blockHash"),
            block_height=data.get("blockHeight"),
        )
