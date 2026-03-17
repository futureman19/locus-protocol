"""
Locus Protocol Type Definitions

Dataclasses representing all protocol entities.
Matches TypeScript SDK types exactly.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Literal, Optional, Any


# =============================================================================
# Common Types
# =============================================================================

Network = Literal["mainnet", "testnet", "stn"]

CityPhase = Literal[
    "genesis",
    "settlement",
    "village",
    "town",
    "city",
    "metropolis",
]

GovernanceType = Literal[
    "founder",
    "tribal_council",
    "republic",
    "direct_democracy",
    "senate",
]

TerritoryLevel = Literal[128, 64, 32, 16, 8, 4, 2, 1]

ObjectType = Literal[
    "item",
    "waypoint",
    "agent",
    "billboard",
    "rare",
    "epic",
    "legendary",
]

ProposalType = Literal[
    "parameter_change",
    "contract_upgrade",
    "treasury_spend",
    "constitutional",
    "emergency",
]

ProposalStatus = Literal[
    "active",
    "passed",
    "rejected",
    "executed",
    "expired",
]

VoteChoice = Literal["yes", "no", "abstain"]

MessageTypeName = Literal[
    "city_found",
    "city_update",
    "citizen_join",
    "citizen_leave",
    "territory_claim",
    "territory_release",
    "territory_transfer",
    "object_deploy",
    "object_update",
    "object_destroy",
    "heartbeat",
    "ghost_invoke",
    "ghost_payment",
    "gov_propose",
    "gov_vote",
    "gov_exec",
    "ubi_claim",
]


# =============================================================================
# Location Types
# =============================================================================

@dataclass
class LatLng:
    """Latitude and longitude coordinates."""
    lat: float
    lng: float


@dataclass
class H3Location(LatLng):
    """Location with H3 index."""
    h3_index: str


# =============================================================================
# Wallet & Transaction Types
# =============================================================================

@dataclass
class UTXO:
    """Unspent transaction output."""
    txid: str
    vout: int
    satoshis: int
    script: str


@dataclass
class ARCConfig:
    """ARC (API for Remote Communication) configuration."""
    endpoint: str
    api_key: Optional[str] = None


@dataclass
class ARCBroadcastResult:
    """Result of broadcasting a transaction via ARC."""
    txid: str
    tx_status: str
    block_hash: Optional[str] = None
    block_height: Optional[int] = None


@dataclass
class FeeDistribution:
    """Fee distribution breakdown."""
    developer: int
    territory: int
    protocol: int


@dataclass
class TerritoryFeeBreakdown:
    """Territory fee distribution breakdown."""
    building: int
    city: int
    block: int


# =============================================================================
# City Types
# =============================================================================

@dataclass
class CityPolicies:
    """City policy configuration."""
    block_auction_period: Optional[int] = None
    block_starting_bid: Optional[int] = None
    immigration_policy: Optional[str] = None


@dataclass
class City:
    """City entity."""
    id: str
    name: str
    description: str
    location: H3Location
    founder_pubkey: str
    founded_at: int
    phase: CityPhase
    citizens: List[str]
    citizen_count: int
    treasury_bsv: int
    token_supply: int
    treasury_tokens: int
    founder_tokens_total: int
    policies: CityPolicies = field(default_factory=CityPolicies)


@dataclass
class CityFoundParams:
    """Parameters for founding a city."""
    name: str
    lat: float
    lng: float
    h3_res7: str
    founder_pubkey: str
    description: str = ""
    policies: Optional[CityPolicies] = None


@dataclass
class CitizenJoinParams:
    """Parameters for a citizen joining a city."""
    city_id: str
    citizen_pubkey: str


@dataclass
class TokenDistribution:
    """Token distribution for a new city."""
    founder: int
    treasury: int
    public_sale: int
    protocol_dev: int
    total: int


# =============================================================================
# Territory Types
# =============================================================================

@dataclass
class Territory:
    """Territory entity."""
    id: str
    level: TerritoryLevel
    h3_index: str
    owner_pubkey: str
    stake_amount: int
    lock_height: int
    parent_city: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    claimed_at: int = 0


@dataclass
class TerritoryClaimParams:
    """Parameters for claiming a territory."""
    level: TerritoryLevel
    h3_index: str
    owner_pubkey: str
    stake_amount: int
    lock_height: int
    parent_city: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


@dataclass
class TerritoryTransferParams:
    """Parameters for transferring a territory."""
    territory_id: str
    from_pubkey: str
    to_pubkey: str
    price: int = 0


# =============================================================================
# Object Types
# =============================================================================

@dataclass
class LocusObject:
    """Object entity (including ghosts)."""
    id: str
    object_type: ObjectType
    h3_index: str
    owner_pubkey: str
    stake_amount: int
    content_hash: str
    parent_territory: str
    manifest_hash: Optional[str] = None
    capabilities: List[str] = field(default_factory=list)
    created_at: int = 0


@dataclass
class ObjectDeployParams:
    """Parameters for deploying an object."""
    object_type: ObjectType
    h3_index: str
    owner_pubkey: str
    stake_amount: int
    content_hash: str
    parent_territory: str
    manifest_hash: Optional[str] = None
    capabilities: Optional[List[str]] = None


@dataclass
class ObjectDestroyParams:
    """Parameters for destroying an object."""
    object_id: str
    owner_pubkey: str
    reason: str = ""


# =============================================================================
# Governance Types
# =============================================================================

@dataclass
class ProposalAction:
    """Action to execute from a proposal."""
    type: str
    target: str
    data: str


@dataclass
class Proposal:
    """Governance proposal."""
    id: str
    proposal_type: ProposalType
    scope: int
    title: str
    description: str
    actions: List[ProposalAction]
    deposit: int
    proposer_pubkey: str
    status: ProposalStatus
    votes_for: int
    votes_against: int
    votes_abstain: int
    voters: List[str]
    created_at: int
    voting_ends_at: int
    execution_txid: Optional[str] = None


@dataclass
class ProposeParams:
    """Parameters for creating a proposal."""
    proposal_type: ProposalType
    title: str
    proposer_pubkey: str
    scope: int = 1
    description: str = ""
    actions: Optional[List[ProposalAction]] = None
    deposit: int = 10_000_000  # 0.1 BSV


@dataclass
class VoteParams:
    """Parameters for casting a vote."""
    proposal_id: str
    voter_pubkey: str
    vote: VoteChoice
    weight: int = 1


# =============================================================================
# Treasury Types
# =============================================================================

@dataclass
class UBIInfo:
    """UBI information for a city."""
    daily_per_citizen: int
    monthly_cap: int
    treasury_balance: int
    citizen_count: int
    is_active: bool
    min_treasury: int


@dataclass
class UBIClaimParams:
    """Parameters for claiming UBI."""
    city_id: str
    citizen_pubkey: str
    claim_periods: int


@dataclass
class RedemptionInfo:
    """Token redemption information."""
    rate: float
    treasury_bsv: int
    total_supply: int


# =============================================================================
# Transaction Types
# =============================================================================

@dataclass
class DecodedTransaction:
    """Decoded Locus protocol transaction."""
    type: MessageTypeName
    version: int
    data: Dict[str, Any]


@dataclass
class HeartbeatParams:
    """Parameters for a heartbeat transaction."""
    heartbeat_type: int
    entity_id: str
    h3_index: str
    entity_type: Optional[int] = None
    nonce: Optional[int] = None


# =============================================================================
# Client Configuration
# =============================================================================

@dataclass
class LocusClientConfig:
    """Configuration for LocusClient."""
    network: Network = "testnet"
    arc_endpoint: Optional[str] = None
    arc_api_key: Optional[str] = None
    
    
@dataclass
class Citizen:
    """Citizen entity."""
    pubkey: str
    city_id: str
    joined_at: int
    token_balance: int
    territories_claimed: int
    last_heartbeat: Optional[int] = None
