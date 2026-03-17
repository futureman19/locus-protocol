"""
Object Manager

Deploy, update, destroy /1 objects (including ghosts).

Per spec 01-territory-hierarchy.md:
Objects are the /1 level — the smallest unit in Geo-IPv6.
Types: item, waypoint, agent/ghost, billboard, rare, epic, legendary

Ghosts are NOT the center — they're just one type of /1 Object.
"""

from .transaction import TransactionBuilder
from .types import ObjectDeployParams, ObjectType
from .utils.stakes import stake_for_object_type


class ObjectManager:
    """
    Manages object lifecycle operations.
    
    Provides methods for deploying, updating, and destroying
    objects including ghost-specific operations.
    """

    @staticmethod
    def build_deploy_transaction(params: ObjectDeployParams) -> bytes:
        """
        Build an OBJECT_DEPLOY transaction script.
        
        Args:
            params: Object deployment parameters
            
        Returns:
            OP_RETURN script bytes
            
        Example:
            >>> script = ObjectManager.build_deploy_transaction(ObjectDeployParams(
            ...     object_type='agent',
            ...     h3_index='891f1d48177ffff',
            ...     owner_pubkey='owner_key',
            ...     stake_amount=10_000_000,
            ...     content_hash='abc123',
            ...     parent_territory='parent_hex',
            ... ))
        """
        return TransactionBuilder.build_object_deploy(params)

    @staticmethod
    def build_update_transaction(
        object_id: str,
        owner_pubkey: str,
        updates: dict,
    ) -> bytes:
        """
        Build an OBJECT_UPDATE transaction script.
        
        Args:
            object_id: Object identifier
            owner_pubkey: Owner's public key
            updates: Dictionary of field updates
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_object_update(object_id, owner_pubkey, updates)

    @staticmethod
    def build_destroy_transaction(
        object_id: str,
        owner_pubkey: str,
        reason: str = "",
    ) -> bytes:
        """
        Build an OBJECT_DESTROY transaction script.
        
        Args:
            object_id: Object identifier
            owner_pubkey: Owner's public key
            reason: Optional destruction reason
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_object_destroy(object_id, owner_pubkey, reason)

    @staticmethod
    def build_ghost_invoke_transaction(
        ghost_id: str,
        invoker_pubkey: str,
        invoker_location: str,
        session_id: str = "",
    ) -> bytes:
        """
        Build a GHOST_INVOKE transaction script.
        
        Args:
            ghost_id: Ghost object identifier
            invoker_pubkey: Invoker's public key
            invoker_location: Invoker's H3 location
            session_id: Optional session identifier
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_ghost_invoke(
            ghost_id, invoker_pubkey, invoker_location, session_id
        )

    @staticmethod
    def build_ghost_payment_transaction(
        ghost_id: str,
        payer_pubkey: str,
        amount: int,
        service_id: str = "",
    ) -> bytes:
        """
        Build a GHOST_PAYMENT transaction script.
        
        Args:
            ghost_id: Ghost object identifier
            payer_pubkey: Payer's public key
            amount: Payment amount in satoshis
            service_id: Optional service identifier
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_ghost_payment(
            ghost_id, payer_pubkey, amount, service_id
        )

    @staticmethod
    def get_min_stake(object_type: ObjectType) -> int:
        """
        Returns the minimum stake for an object type.
        
        Args:
            object_type: Type of object
            
        Returns:
            Minimum stake in satoshis
            
        Example:
            >>> ObjectManager.get_min_stake('rare')
            1600000000  # 16 BSV
        """
        return stake_for_object_type(object_type)
