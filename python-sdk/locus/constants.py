"""
Locus Protocol Constants

Protocol constants per specifications:
- 01-territory-hierarchy.md
- 03-staking-economics.md
- 04-governance.md
- 07-transaction-formats.md
"""

from typing import Dict, Literal

# =============================================================================
# Protocol Identification
# =============================================================================

PROTOCOL_PREFIX: str = "LOCUS"
PROTOCOL_PREFIX_HEX: str = "4c4f435553"
PROTOCOL_VERSION: int = 0x01

# =============================================================================
# Bitcoin Script Opcodes
# =============================================================================

OP_RETURN: int = 0x6a
OP_PUSHDATA1: int = 0x4c
OP_PUSHDATA2: int = 0x4d

# =============================================================================
# Transaction Type Codes (17 types per spec 07)
# =============================================================================

# Type code → name mapping
TYPE_CODES: Dict[str, int] = {
    "city_found": 0x01,
    "city_update": 0x02,
    "citizen_join": 0x03,
    "citizen_leave": 0x04,
    "territory_claim": 0x10,
    "territory_release": 0x11,
    "territory_transfer": 0x12,
    "object_deploy": 0x20,
    "object_update": 0x21,
    "object_destroy": 0x22,
    "heartbeat": 0x30,
    "ghost_invoke": 0x40,
    "ghost_payment": 0x41,
    "gov_propose": 0x50,
    "gov_vote": 0x51,
    "gov_exec": 0x52,
    "ubi_claim": 0x60,
}

# Reverse lookup: code → name
REVERSE_CODES: Dict[int, str] = {v: k for k, v in TYPE_CODES.items()}

# Type aliases for type safety
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
# Proposal Type Codes
# =============================================================================

PROPOSAL_TYPE_CODES: Dict[str, int] = {
    "parameter_change": 0x01,
    "contract_upgrade": 0x02,
    "treasury_spend": 0x03,
    "constitutional": 0x04,
    "emergency": 0x05,
}

# Reverse lookup
REVERSE_PROPOSAL_CODES: Dict[int, str] = {v: k for k, v in PROPOSAL_TYPE_CODES.items()}

ProposalType = Literal[
    "parameter_change",
    "contract_upgrade",
    "treasury_spend",
    "constitutional",
    "emergency",
]

# =============================================================================
# Vote Value Codes
# =============================================================================

VOTE_CODES: Dict[str, int] = {
    "no": 0,
    "yes": 1,
    "abstain": 2,
}

# Reverse lookup
REVERSE_VOTE_CODES: Dict[int, str] = {v: k for k, v in VOTE_CODES.items()}

VoteChoice = Literal["yes", "no", "abstain"]

# =============================================================================
# Territory Stakes (in satoshis: 1 BSV = 100,000,000 sats)
# =============================================================================

TERRITORY_STAKES: Dict[str, int] = {
    "CITY": 3_200_000_000,          # /32 — 32 BSV
    "BLOCK_PRIVATE": 800_000_000,   # /16 — 8 BSV
    "BUILDING": 800_000_000,        # /8  — 8 BSV
    "HOME": 400_000_000,            # /4  — 4 BSV
}

# =============================================================================
# Object Stakes (in satoshis)
# =============================================================================

OBJECT_STAKES: Dict[str, int] = {
    "ITEM": 10_000,                 # 0.0001 BSV
    "WAYPOINT_MIN": 50_000_000,     # 0.5 BSV
    "WAYPOINT_MAX": 400_000_000,    # 4 BSV
    "AGENT_MIN": 10_000_000,        # 0.1 BSV
    "AGENT_MAX": 400_000_000,       # 4 BSV
    "BILLBOARD_MIN": 1_000_000_000, # 10 BSV
    "BILLBOARD_MAX": 10_000_000_000,# 100 BSV
    "RARE": 1_600_000_000,          # 16 BSV
    "EPIC": 3_200_000_000,          # 32 BSV
    "LEGENDARY": 6_400_000_000,     # 64 BSV
}

# =============================================================================
# Token Distribution
# =============================================================================

TOKEN_DISTRIBUTION: Dict[str, int] = {
    "TOTAL_SUPPLY": 3_200_000,
    "FOUNDER": 640_000,         # 20%
    "TREASURY": 1_600_000,      # 50%
    "PUBLIC_SALE": 800_000,     # 25%
    "PROTOCOL_DEV": 160_000,    # 5%
    "FOUNDER_VEST_MONTHS": 12,
    "DEV_VEST_MONTHS": 24,
}

# =============================================================================
# Lock Periods
# =============================================================================

LOCK_PERIOD_BLOCKS: int = 21_600  # ~5 months
EMERGENCY_PENALTY_RATE: float = 0.10  # 10% to protocol treasury

# =============================================================================
# Fee Distribution
# =============================================================================

FEE_DISTRIBUTION: Dict[str, float] = {
    "DEVELOPER": 0.50,   # 50%
    "TERRITORY": 0.40,   # 40%
    "PROTOCOL": 0.10,    # 10%
}

# Territory sub-split (of the 40% territory share)
TERRITORY_FEE_SPLIT: Dict[str, float] = {
    "BUILDING": 0.50,    # 50% → building owner
    "CITY": 0.30,        # 30% → city treasury
    "BLOCK": 0.20,       # 20% → block owner
}

# =============================================================================
# UBI Parameters
# =============================================================================

UBI: Dict[str, float | int] = {
    "RATE": 0.001,
    "MONTHLY_CAP_RATE": 0.01,
    "MIN_TREASURY_SATS": 10_000_000_000,  # 100 BSV
    "MIN_PHASE": "city",  # Phase 4 (21+ citizens)
}

# =============================================================================
# Governance Parameters
# =============================================================================

GOVERNANCE: Dict[str, int] = {
    "PROPOSAL_DEPOSIT": 10_000_000,       # 0.1 BSV
    "DISCUSSION_PERIOD_BLOCKS": 1_008,    # ~7 days
    "VOTING_PERIOD_BLOCKS": 2_016,        # ~14 days
    "EXECUTION_DELAY_BLOCKS": 432,        # ~3 days
    "GENESIS_KEY_EXPIRY_BLOCK": 2_100_000,  # ~Year 10
}

# Proposal thresholds (required yes votes ratio)
PROPOSAL_THRESHOLDS: Dict[str, float] = {
    "parameter_change": 0.51,
    "contract_upgrade": 0.66,
    "treasury_spend": 0.51,
    "constitutional": 0.75,
    "emergency": 0.583,  # 7/12 Guardian
}

# Quorum requirements by city phase
QUORUM_BY_PHASE: Dict[str, float] = {
    "village": 0.67,
    "town": 0.60,
    "city": 0.40,
    "metropolis": 0.51,
}

# =============================================================================
# Network Defaults
# =============================================================================

DUST_LIMIT: int = 546  # Minimum output value in satoshis
DEFAULT_FEE_RATE: float = 0.5  # Satoshis per byte

# ARC Endpoints
ARC_ENDPOINTS: Dict[str, str] = {
    "mainnet": "https://arc.taal.com",
    "testnet": "https://arc.gorillapool.io",
    "stn": "https://arc.stn.gorillapool.io",
}

Network = Literal["mainnet", "testnet", "stn"]
