"""
Stake Calculations

Stake calculations for territories, objects, and progressive taxation.

Per spec 03-staking-economics.md:
- Progressive property tax: cost = base * 2^(n-1)
- Emergency unlock penalty: 10%
"""

from typing import Literal

from ..constants import (
    TERRITORY_STAKES,
    OBJECT_STAKES,
    LOCK_PERIOD_BLOCKS,
    EMERGENCY_PENALTY_RATE,
)

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


def stake_for_level(level: TerritoryLevel) -> int:
    """
    Returns the stake amount in satoshis for a territory level.
    
    Args:
        level: Territory level (32, 16, 8, 4, etc.)
        
    Returns:
        Stake amount in satoshis
        
    Example:
        >>> stake_for_level(32)  # /32 City
        3200000000  # 32 BSV
    """
    mapping: dict[TerritoryLevel, int] = {
        32: TERRITORY_STAKES["CITY"],
        16: TERRITORY_STAKES["BLOCK_PRIVATE"],
        8: TERRITORY_STAKES["BUILDING"],
        4: TERRITORY_STAKES["HOME"],
    }
    return mapping.get(level, 0)


def stake_for_object_type(object_type: ObjectType) -> int:
    """
    Returns the minimum stake for an object type.
    
    Args:
        object_type: Type of object (item, waypoint, agent, etc.)
        
    Returns:
        Minimum stake amount in satoshis
        
    Example:
        >>> stake_for_object_type("rare")
        1600000000  # 16 BSV
    """
    mapping: dict[ObjectType, int] = {
        "item": OBJECT_STAKES["ITEM"],
        "waypoint": OBJECT_STAKES["WAYPOINT_MIN"],
        "agent": OBJECT_STAKES["AGENT_MIN"],
        "billboard": OBJECT_STAKES["BILLBOARD_MIN"],
        "rare": OBJECT_STAKES["RARE"],
        "epic": OBJECT_STAKES["EPIC"],
        "legendary": OBJECT_STAKES["LEGENDARY"],
    }
    return mapping.get(object_type, 0)


def calculate_lock_height(current_height: int) -> int:
    """
    Calculates the lock height given the current block height.
    
    Per spec 03-staking-economics.md:
    Lock period is 21,600 blocks (~5 months)
    
    Args:
        current_height: Current block height
        
    Returns:
        Lock height (current + LOCK_PERIOD_BLOCKS)
        
    Example:
        >>> calculate_lock_height(800_000)
        821600
    """
    return current_height + LOCK_PERIOD_BLOCKS


def calculate_penalty(stake_amount: int) -> int:
    """
    Calculates the 10% emergency penalty amount.
    
    Per spec 03-staking-economics.md:
    Emergency unlock has a 10% penalty to protocol treasury
    
    Args:
        stake_amount: Amount being unstaked
        
    Returns:
        Penalty amount in satoshis
        
    Example:
        >>> calculate_penalty(3_200_000_000)  # 32 BSV
        320000000  # 3.2 BSV
    """
    return int(stake_amount * EMERGENCY_PENALTY_RATE)


def calculate_emergency_return(stake_amount: int) -> int:
    """
    Calculates the 90% returned on emergency unlock.
    
    Args:
        stake_amount: Amount being unstaked
        
    Returns:
        Amount returned to owner in satoshis
        
    Example:
        >>> calculate_emergency_return(3_200_000_000)  # 32 BSV
        2880000000  # 28.8 BSV
    """
    return stake_amount - calculate_penalty(stake_amount)


def progressive_tax(base_cost: int, property_number: int) -> int:
    """
    Progressive property tax: cost = base * 2^(n-1)
    
    Per spec 03-staking-economics.md:
    Each additional property at the same level costs 2x the base.
    
    Args:
        base_cost: Base stake cost for the level
        property_number: Property number (1st, 2nd, 3rd, etc.)
        
    Returns:
        Progressive tax amount
        
    Example:
        >>> progressive_tax(800_000_000, 1)  # 1st building
        800000000  # 8 BSV
        >>> progressive_tax(800_000_000, 2)  # 2nd building
        1600000000  # 16 BSV
    """
    return int(base_cost * (2 ** (property_number - 1)))
