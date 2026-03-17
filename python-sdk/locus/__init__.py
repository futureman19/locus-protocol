"""
Locus Protocol Python SDK

A reference implementation of the Locus Protocol SDK in Python.
Provides territory-centric blockchain operations on BSV.

Cities are the core primitive. Ghosts are just one type of /1 Object.

Quick Start:
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

Installation:
    pip install locus-protocol

Documentation:
    https://github.com/locusprotocol/locus-protocol/tree/main/python-sdk
"""

__version__ = "0.1.0"
__author__ = "Locus Protocol Team"
__license__ = "MIT"

# Main client
from .client import LocusClient

# Managers
from .city import CityManager
from .territory import TerritoryManager
from .object import ObjectManager
from .treasury import TreasuryManager
from .governance import GovernanceManager
from .heartbeat import HeartbeatManager
from .transaction import TransactionBuilder

# Broadcaster
from .broadcaster import ARCBroadcaster

# Types
from .types import (
    # Common
    Network,
    LatLng,
    H3Location,
    UTXO,
    ARCConfig,
    ARCBroadcastResult,
    FeeDistribution,
    TerritoryFeeBreakdown,
    # City
    CityPhase,
    GovernanceType,
    CityPolicies,
    City,
    CityFoundParams,
    CitizenJoinParams,
    TokenDistribution,
    # Territory
    TerritoryLevel,
    Territory,
    TerritoryClaimParams,
    TerritoryTransferParams,
    # Object
    ObjectType,
    LocusObject,
    ObjectDeployParams,
    ObjectDestroyParams,
    # Governance
    ProposalType,
    ProposalStatus,
    VoteChoice,
    Proposal,
    ProposalAction,
    ProposeParams,
    VoteParams,
    # Treasury
    UBIInfo,
    UBIClaimParams,
    RedemptionInfo,
    # Transaction
    DecodedTransaction,
    HeartbeatParams,
    Citizen,
    LocusClientConfig,
)

# Constants
from .constants import (
    PROTOCOL_PREFIX,
    PROTOCOL_VERSION,
    TYPE_CODES,
    REVERSE_CODES,
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

# Utils
from .utils import (
    # Fibonacci
    fibonacci_sequence,
    fibonacci_sum,
    blocks_for_citizens,
    phase_for_citizens,
    governance_for_phase,
    phase_number,
    # Stakes
    stake_for_level,
    stake_for_object_type,
    calculate_lock_height,
    calculate_penalty,
    calculate_emergency_return,
    progressive_tax,
    # MessagePack
    encode,
    decode,
)

__all__ = [
    # Version
    "__version__",
    # Client
    "LocusClient",
    # Managers
    "CityManager",
    "TerritoryManager",
    "ObjectManager",
    "TreasuryManager",
    "GovernanceManager",
    "HeartbeatManager",
    "TransactionBuilder",
    # Broadcaster
    "ARCBroadcaster",
    # Types - Common
    "Network",
    "LatLng",
    "H3Location",
    "UTXO",
    "ARCConfig",
    "ARCBroadcastResult",
    "FeeDistribution",
    "TerritoryFeeBreakdown",
    # Types - City
    "CityPhase",
    "GovernanceType",
    "CityPolicies",
    "City",
    "CityFoundParams",
    "CitizenJoinParams",
    "TokenDistribution",
    # Types - Territory
    "TerritoryLevel",
    "Territory",
    "TerritoryClaimParams",
    "TerritoryTransferParams",
    # Types - Object
    "ObjectType",
    "LocusObject",
    "ObjectDeployParams",
    "ObjectDestroyParams",
    # Types - Governance
    "ProposalType",
    "ProposalStatus",
    "VoteChoice",
    "Proposal",
    "ProposalAction",
    "ProposeParams",
    "VoteParams",
    # Types - Treasury
    "UBIInfo",
    "UBIClaimParams",
    "RedemptionInfo",
    # Types - Transaction
    "DecodedTransaction",
    "HeartbeatParams",
    "Citizen",
    "LocusClientConfig",
    # Constants - Protocol
    "PROTOCOL_PREFIX",
    "PROTOCOL_VERSION",
    # Constants - Type Codes
    "TYPE_CODES",
    "REVERSE_CODES",
    "PROPOSAL_TYPE_CODES",
    "VOTE_CODES",
    # Constants - Stakes
    "TERRITORY_STAKES",
    "OBJECT_STAKES",
    "TOKEN_DISTRIBUTION",
    "LOCK_PERIOD_BLOCKS",
    "EMERGENCY_PENALTY_RATE",
    # Constants - Fees
    "FEE_DISTRIBUTION",
    "TERRITORY_FEE_SPLIT",
    # Constants - UBI
    "UBI",
    # Constants - Governance
    "GOVERNANCE",
    "PROPOSAL_THRESHOLDS",
    "QUORUM_BY_PHASE",
    # Constants - Network
    "DUST_LIMIT",
    "DEFAULT_FEE_RATE",
    "ARC_ENDPOINTS",
    # Utils - Fibonacci
    "fibonacci_sequence",
    "fibonacci_sum",
    "blocks_for_citizens",
    "phase_for_citizens",
    "governance_for_phase",
    "phase_number",
    # Utils - Stakes
    "stake_for_level",
    "stake_for_object_type",
    "calculate_lock_height",
    "calculate_penalty",
    "calculate_emergency_return",
    "progressive_tax",
    # Utils - MessagePack
    "encode",
    "decode",
]
