"""
Transaction Builder

OP_RETURN encoding and decoding for the territory-centric protocol.

Per spec 07-transaction-formats.md:
  OP_RETURN "LOCUS" {version:1} {type:1} {msgpack payload}
"""

import time
import random
from typing import Dict, Any, Optional

from .constants import (
    PROTOCOL_PREFIX,
    PROTOCOL_VERSION,
    OP_RETURN,
    OP_PUSHDATA1,
    OP_PUSHDATA2,
    TYPE_CODES,
    REVERSE_CODES,
    PROPOSAL_TYPE_CODES,
    VOTE_CODES,
)
from .types import (
    MessageTypeName,
    DecodedTransaction,
    CityFoundParams,
    TerritoryClaimParams,
    ObjectDeployParams,
    ProposeParams,
    VoteChoice,
    HeartbeatParams,
    ProposalType,
)
from .utils.messagepack import encode as msgpack_encode, decode as msgpack_decode


class TransactionBuilder:
    """
    Builds and decodes Locus protocol OP_RETURN transactions.
    
    Provides encoding and decoding for all 17 transaction types
    defined in the protocol specification.
    """

    @staticmethod
    def encode(type_name: MessageTypeName, payload: Dict[str, Any]) -> bytes:
        """
        Encode a protocol message into an OP_RETURN script.
        
        Returns the full script as bytes:
          OP_RETURN [pushdata] "LOCUS" version type msgpack_payload
        
        Args:
            type_name: Message type (e.g., 'city_found', 'territory_claim')
            payload: Message payload dictionary
            
        Returns:
            OP_RETURN script as bytes
            
        Raises:
            ValueError: If message type is unknown
            
        Example:
            >>> script = TransactionBuilder.encode('city_found', {
            ...     'name': 'Neo-Tokyo',
            ...     'stake': 3200000000
            ... })
        """
        type_code = TYPE_CODES.get(type_name)
        if type_code is None:
            raise ValueError(f"Unknown message type: {type_name}")

        payload_bin = msgpack_encode(payload)

        # Protocol data: "LOCUS" + version + type + payload
        prefix = PROTOCOL_PREFIX.encode('ascii')
        protocol_data = prefix + bytes([PROTOCOL_VERSION, type_code]) + payload_bin

        total_len = len(protocol_data)

        # OP_RETURN with appropriate pushdata opcode
        if total_len <= 0x4b:
            return bytes([OP_RETURN, total_len]) + protocol_data
        elif total_len <= 0xff:
            return bytes([OP_RETURN, OP_PUSHDATA1, total_len]) + protocol_data
        else:
            len_bytes = total_len.to_bytes(2, 'little')
            return bytes([OP_RETURN, OP_PUSHDATA2]) + len_bytes + protocol_data

    @staticmethod
    def decode(script: bytes) -> DecodedTransaction:
        """
        Decode an OP_RETURN script into protocol data.
        
        Args:
            script: OP_RETURN script bytes
            
        Returns:
            Decoded transaction with type, version, and data
            
        Raises:
            ValueError: If script is invalid or not a LOCUS message
            
        Example:
            >>> decoded = TransactionBuilder.decode(script)
            >>> decoded.type
            'city_found'
            >>> decoded.data['name']
            'Neo-Tokyo'
        """
        data = TransactionBuilder._extract_pushdata(script)
        return TransactionBuilder._parse_protocol_data(data)

    # -- Payload builders matching TypeScript SDK --

    @staticmethod
    def build_city_found(params: CityFoundParams) -> bytes:
        """Build a CITY_FOUND transaction script."""
        return TransactionBuilder.encode('city_found', {
            'name': params.name,
            'description': params.description or '',
            'location': {
                'lat': params.lat,
                'lng': params.lng,
                'h3_res7': params.h3_res7,
            },
            'founder_pubkey': params.founder_pubkey,
            'policies': params.policies.__dict__ if params.policies else {},
            'signature': '',
        })

    @staticmethod
    def build_citizen_join(city_id: str, citizen_pubkey: str) -> bytes:
        """Build a CITIZEN_JOIN transaction script."""
        return TransactionBuilder.encode('citizen_join', {
            'city_id': city_id,
            'citizen_pubkey': citizen_pubkey,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_citizen_leave(city_id: str, citizen_pubkey: str) -> bytes:
        """Build a CITIZEN_LEAVE transaction script."""
        return TransactionBuilder.encode('citizen_leave', {
            'city_id': city_id,
            'citizen_pubkey': citizen_pubkey,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_territory_claim(params: TerritoryClaimParams) -> bytes:
        """Build a TERRITORY_CLAIM transaction script."""
        return TransactionBuilder.encode('territory_claim', {
            'level': params.level,
            'location': params.h3_index,
            'owner_pubkey': params.owner_pubkey,
            'stake_amount': params.stake_amount,
            'lock_height': params.lock_height,
            'parent_city': params.parent_city or '',
            'metadata': params.metadata or {},
        })

    @staticmethod
    def build_territory_release(territory_id: str, owner_pubkey: str) -> bytes:
        """Build a TERRITORY_RELEASE transaction script."""
        return TransactionBuilder.encode('territory_release', {
            'territory_id': territory_id,
            'owner_pubkey': owner_pubkey,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_territory_transfer(
        territory_id: str,
        from_pubkey: str,
        to_pubkey: str,
        price: int = 0,
    ) -> bytes:
        """Build a TERRITORY_TRANSFER transaction script."""
        return TransactionBuilder.encode('territory_transfer', {
            'territory_id': territory_id,
            'from_pubkey': from_pubkey,
            'to_pubkey': to_pubkey,
            'price': price,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_object_deploy(params: ObjectDeployParams) -> bytes:
        """Build an OBJECT_DEPLOY transaction script."""
        return TransactionBuilder.encode('object_deploy', {
            'object_type': params.object_type,
            'location': params.h3_index,
            'owner_pubkey': params.owner_pubkey,
            'stake_amount': params.stake_amount,
            'content_hash': params.content_hash,
            'parent_territory': params.parent_territory,
            'capabilities': params.capabilities or [],
        })

    @staticmethod
    def build_object_update(
        object_id: str,
        owner_pubkey: str,
        updates: Dict[str, Any],
    ) -> bytes:
        """Build an OBJECT_UPDATE transaction script."""
        return TransactionBuilder.encode('object_update', {
            'object_id': object_id,
            'owner_pubkey': owner_pubkey,
            'updates': updates,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_object_destroy(
        object_id: str,
        owner_pubkey: str,
        reason: str = "",
    ) -> bytes:
        """Build an OBJECT_DESTROY transaction script."""
        return TransactionBuilder.encode('object_destroy', {
            'object_id': object_id,
            'owner_pubkey': owner_pubkey,
            'reason': reason,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_ghost_invoke(
        ghost_id: str,
        invoker_pubkey: str,
        invoker_location: str,
        session_id: str = "",
    ) -> bytes:
        """Build a GHOST_INVOKE transaction script."""
        return TransactionBuilder.encode('ghost_invoke', {
            'ghost_id': ghost_id,
            'invoker_pubkey': invoker_pubkey,
            'location': invoker_location,
            'timestamp': int(time.time()),
            'session_id': session_id,
        })

    @staticmethod
    def build_ghost_payment(
        ghost_id: str,
        payer_pubkey: str,
        amount: int,
        service_id: str = "",
    ) -> bytes:
        """Build a GHOST_PAYMENT transaction script."""
        return TransactionBuilder.encode('ghost_payment', {
            'ghost_id': ghost_id,
            'payer_pubkey': payer_pubkey,
            'amount': amount,
            'service_id': service_id,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_gov_propose(params: ProposeParams) -> bytes:
        """Build a GOV_PROPOSE transaction script."""
        type_code = PROPOSAL_TYPE_CODES.get(params.proposal_type, 0x00)
        actions = []
        if params.actions:
            actions = [{'type': a.type, 'target': a.target, 'data': a.data} for a in params.actions]
        
        return TransactionBuilder.encode('gov_propose', {
            'proposal_type': type_code,
            'scope': params.scope,
            'title': params.title,
            'description': params.description or '',
            'actions': actions,
            'deposit': params.deposit,
            'proposer_pubkey': params.proposer_pubkey,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_gov_vote(
        proposal_id: str,
        voter_pubkey: str,
        vote: VoteChoice,
    ) -> bytes:
        """Build a GOV_VOTE transaction script."""
        return TransactionBuilder.encode('gov_vote', {
            'proposal_id': proposal_id,
            'voter_pubkey': voter_pubkey,
            'vote': VOTE_CODES[vote],
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_gov_exec(proposal_id: str, executor_pubkey: str) -> bytes:
        """Build a GOV_EXEC transaction script."""
        return TransactionBuilder.encode('gov_exec', {
            'proposal_id': proposal_id,
            'executor_pubkey': executor_pubkey,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_heartbeat(params: HeartbeatParams) -> bytes:
        """Build a HEARTBEAT transaction script."""
        return TransactionBuilder.encode('heartbeat', {
            'heartbeat_type': params.heartbeat_type,
            'entity_id': params.entity_id,
            'entity_type': params.entity_type,
            'location': params.h3_index,
            'timestamp': int(time.time()),
            'nonce': params.nonce if params.nonce is not None else random.randint(0, 0xffffffff),
        })

    @staticmethod
    def build_ubi_claim(
        city_id: str,
        citizen_pubkey: str,
        claim_periods: int,
    ) -> bytes:
        """Build a UBI_CLAIM transaction script."""
        return TransactionBuilder.encode('ubi_claim', {
            'city_id': city_id,
            'citizen_pubkey': citizen_pubkey,
            'claim_periods': claim_periods,
            'timestamp': int(time.time()),
        })

    @staticmethod
    def build_city_update(
        city_id: str,
        updater_pubkey: str,
        updates: Dict[str, Any],
    ) -> bytes:
        """Build a CITY_UPDATE transaction script."""
        return TransactionBuilder.encode('city_update', {
            'city_id': city_id,
            'updater_pubkey': updater_pubkey,
            'updates': updates,
            'timestamp': int(time.time()),
        })

    # -- Private helpers --

    @staticmethod
    def _extract_pushdata(script: bytes) -> bytes:
        """Extract pushdata from OP_RETURN script."""
        if script[0] != OP_RETURN:
            raise ValueError('Not an OP_RETURN script')

        offset = 1
        
        if script[offset] <= 0x4b:
            length = script[offset]
            offset += 1
        elif script[offset] == OP_PUSHDATA1:
            length = script[offset + 1]
            offset += 2
        elif script[offset] == OP_PUSHDATA2:
            length = int.from_bytes(script[offset + 1:offset + 3], 'little')
            offset += 3
        else:
            raise ValueError('Invalid pushdata opcode')

        return script[offset:offset + length]

    @staticmethod
    def _parse_protocol_data(data: bytes) -> DecodedTransaction:
        """Parse protocol data from extracted pushdata."""
        prefix = data[0:5].decode('ascii')
        if prefix != PROTOCOL_PREFIX:
            raise ValueError('Not a LOCUS protocol message')

        version = data[5]
        type_code = data[6]
        type_name = REVERSE_CODES.get(type_code)

        if not type_name:
            raise ValueError(f'Unknown type code: 0x{type_code:02x}')

        payload = data[7:]
        decoded = msgpack_decode(payload)

        # Convert type_name to MessageTypeName
        from typing import cast
        return DecodedTransaction(
            type=cast(MessageTypeName, type_name),
            version=version,
            data=decoded,
        )
