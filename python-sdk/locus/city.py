"""
City Manager

City founding, citizen management, phase tracking.

Per spec 02-city-lifecycle.md:
- Cities are the core /32 primitive
- 6 phases driven by citizen count
- 32 BSV founding stake with 21,600-block CLTV lock
"""

from typing import Literal

from .transaction import TransactionBuilder
from .types import (
    CityFoundParams,
    TokenDistribution,
    CityPhase,
    GovernanceType,
    CityPolicies,
)
from .constants import (
    TERRITORY_STAKES,
    TOKEN_DISTRIBUTION,
    LOCK_PERIOD_BLOCKS,
)
from .utils.fibonacci import (
    phase_for_citizens,
    blocks_for_citizens,
    governance_for_phase,
)
from .utils.stakes import calculate_lock_height


class CityManager:
    """
    Manages city lifecycle operations.
    
    Provides methods for founding cities, managing citizens,
    tracking phases, and calculating token distributions.
    """

    @staticmethod
    def build_found_transaction(params: CityFoundParams) -> bytes:
        """
        Build a CITY_FOUND transaction script.
        Requires 32 BSV stake.
        
        Args:
            params: City founding parameters
            
        Returns:
            OP_RETURN script bytes
            
        Example:
            >>> script = CityManager.build_found_transaction(CityFoundParams(
            ...     name='Neo-Tokyo',
            ...     lat=35.6762,
            ...     lng=139.6503,
            ...     h3_res7='8f283080dcb019d',
            ...     founder_pubkey='02abc...',
            ... ))
        """
        return TransactionBuilder.build_city_found(params)

    @staticmethod
    def build_join_transaction(city_id: str, citizen_pubkey: str) -> bytes:
        """
        Build a CITIZEN_JOIN transaction script.
        
        Args:
            city_id: City identifier
            citizen_pubkey: Citizen's public key
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_citizen_join(city_id, citizen_pubkey)

    @staticmethod
    def build_leave_transaction(city_id: str, citizen_pubkey: str) -> bytes:
        """
        Build a CITIZEN_LEAVE transaction script.
        
        Args:
            city_id: City identifier
            citizen_pubkey: Citizen's public key
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_citizen_leave(city_id, citizen_pubkey)

    @staticmethod
    def get_phase(citizen_count: int) -> CityPhase | Literal["none"]:
        """
        Returns the current phase for a city based on citizen count.
        
        Args:
            citizen_count: Number of citizens
            
        Returns:
            City phase or 'none' if no citizens
            
        Example:
            >>> CityManager.get_phase(25)
            'city'
        """
        return phase_for_citizens(citizen_count)

    @staticmethod
    def get_governance_type(phase: CityPhase) -> GovernanceType:
        """
        Returns the governance type for the current phase.
        
        Args:
            phase: City phase
            
        Returns:
            Governance type
            
        Example:
            >>> CityManager.get_governance_type('city')
            'direct_democracy'
        """
        return governance_for_phase(phase)

    @staticmethod
    def get_unlocked_blocks(citizen_count: int) -> int:
        """
        Returns the number of /16 blocks unlocked for the citizen count.
        
        Args:
            citizen_count: Number of citizens
            
        Returns:
            Number of unlocked /16 blocks
            
        Example:
            >>> CityManager.get_unlocked_blocks(25)
            16
        """
        return blocks_for_citizens(citizen_count)

    @staticmethod
    def get_founding_stake() -> int:
        """
        Returns the founding stake in satoshis (32 BSV).
        
        Returns:
            Stake amount in satoshis
            
        Example:
            >>> CityManager.get_founding_stake()
            3200000000
        """
        return TERRITORY_STAKES["CITY"]

    @staticmethod
    def get_lock_height(current_block_height: int) -> int:
        """
        Returns the CLTV lock height for founding at a given block.
        
        Args:
            current_block_height: Current blockchain height
            
        Returns:
            Lock height (current + LOCK_PERIOD_BLOCKS)
        """
        return calculate_lock_height(current_block_height)

    @staticmethod
    def get_token_distribution() -> TokenDistribution:
        """
        Returns the token distribution for a new city.
        
        Returns:
            Token distribution breakdown
            
        Example:
            >>> dist = CityManager.get_token_distribution()
            >>> dist.total
            3200000
            >>> dist.founder
            640000
        """
        return TokenDistribution(
            founder=TOKEN_DISTRIBUTION["FOUNDER"],
            treasury=TOKEN_DISTRIBUTION["TREASURY"],
            public_sale=TOKEN_DISTRIBUTION["PUBLIC_SALE"],
            protocol_dev=TOKEN_DISTRIBUTION["PROTOCOL_DEV"],
            total=TOKEN_DISTRIBUTION["TOTAL_SUPPLY"],
        )

    @staticmethod
    def founder_vested_tokens(months_elapsed: int) -> int:
        """
        Calculate how many founder tokens are vested at a given month.
        Linear vest: 1/12 per month over 12 months.
        
        Args:
            months_elapsed: Number of months since founding
            
        Returns:
            Vested token amount
            
        Example:
            >>> CityManager.founder_vested_tokens(6)
            320000  # 50% vested at 6 months
        """
        if months_elapsed <= 0:
            return 0
        if months_elapsed >= TOKEN_DISTRIBUTION["FOUNDER_VEST_MONTHS"]:
            return TOKEN_DISTRIBUTION["FOUNDER"]
        return (TOKEN_DISTRIBUTION["FOUNDER"] * months_elapsed) // TOKEN_DISTRIBUTION["FOUNDER_VEST_MONTHS"]

    @staticmethod
    def is_ubi_active(phase: CityPhase) -> bool:
        """
        Checks if UBI is active for the given phase.
        Requires Phase 4 (city, 21+ citizens).
        
        Args:
            phase: City phase
            
        Returns:
            True if UBI is active
            
        Example:
            >>> CityManager.is_ubi_active('city')
            True
            >>> CityManager.is_ubi_active('town')
            False
        """
        ubi_phases: list[CityPhase] = ["city", "metropolis"]
        return phase in ubi_phases

    @staticmethod
    def get_lock_period() -> int:
        """
        Returns the lock period in blocks.
        
        Returns:
            Lock period (~21,600 blocks = ~5 months)
        """
        return LOCK_PERIOD_BLOCKS
