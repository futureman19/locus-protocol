"""
Heartbeat Manager

Proof of presence for properties and citizens.

Per spec 07-transaction-formats.md:
- heartbeat_type: 1=property, 2=citizen, 3=aura
- Timestamp must be within 24h window
- Nonce for replay protection
"""

import time

from .transaction import TransactionBuilder
from .types import HeartbeatParams


class HeartbeatManager:
    """
    Manages heartbeat transactions for proof of presence.
    
    Provides methods for building different types of heartbeats
    and validating their timestamps.
    """

    @staticmethod
    def build_heartbeat_transaction(params: HeartbeatParams) -> bytes:
        """
        Build a HEARTBEAT transaction script.
        
        Args:
            params: Heartbeat parameters
            
        Returns:
            OP_RETURN script bytes
            
        Example:
            >>> script = HeartbeatManager.build_heartbeat_transaction(HeartbeatParams(
            ...     heartbeat_type=1,
            ...     entity_id='property_id',
            ...     h3_index='891f1d48177ffff',
            ... ))
        """
        return TransactionBuilder.build_heartbeat(params)

    @staticmethod
    def build_property_heartbeat(
        entity_id: str,
        h3_index: str,
        entity_type: int = 8,
    ) -> bytes:
        """
        Build a property heartbeat (type=1).
        
        Args:
            entity_id: Property identifier
            h3_index: H3 index of property location
            entity_type: Entity type code (default 8 for building)
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_heartbeat(HeartbeatParams(
            heartbeat_type=1,
            entity_id=entity_id,
            h3_index=h3_index,
            entity_type=entity_type,
        ))

    @staticmethod
    def build_citizen_heartbeat(citizen_pubkey: str, h3_index: str) -> bytes:
        """
        Build a citizen heartbeat (type=2).
        
        Args:
            citizen_pubkey: Citizen's public key
            h3_index: H3 index of citizen's location
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_heartbeat(HeartbeatParams(
            heartbeat_type=2,
            entity_id=citizen_pubkey,
            h3_index=h3_index,
        ))

    @staticmethod
    def build_aura_heartbeat(owner_pubkey: str, h3_index: str) -> bytes:
        """
        Build an aura heartbeat (type=3).
        
        Args:
            owner_pubkey: Owner's public key
            h3_index: H3 index of aura location
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_heartbeat(HeartbeatParams(
            heartbeat_type=3,
            entity_id=owner_pubkey,
            h3_index=h3_index,
        ))

    @staticmethod
    def is_valid_timestamp(timestamp_secs: int) -> bool:
        """
        Validate heartbeat timestamp (within 24h window).
        
        Args:
            timestamp_secs: Unix timestamp in seconds
            
        Returns:
            True if timestamp is within valid window
            
        Example:
            >>> HeartbeatManager.is_valid_timestamp(int(time.time()))
            True
        """
        now = int(time.time())
        return abs(now - timestamp_secs) < 86400  # 24 hours
