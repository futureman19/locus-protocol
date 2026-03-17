"""
Territory Manager

Claim, release, transfer territories at any level.

Per spec 01-territory-hierarchy.md:
/128 Continent → /64 Country → /32 City → /16 Block → /8 Building → /4 Home → /2 Aura → /1 Object
"""

from typing import Literal

from .transaction import TransactionBuilder
from .types import (
    TerritoryClaimParams,
    TerritoryLevel,
    FeeDistribution,
    TerritoryFeeBreakdown,
)
from .constants import FEE_DISTRIBUTION, TERRITORY_FEE_SPLIT
from .utils.stakes import stake_for_level, progressive_tax, calculate_lock_height


class TerritoryManager:
    """
    Manages territory lifecycle operations.
    
    Provides methods for claiming, releasing, and transferring
    territories at all levels with proper stake calculations.
    """

    @staticmethod
    def build_claim_transaction(params: TerritoryClaimParams) -> bytes:
        """
        Build a TERRITORY_CLAIM transaction script.
        
        Args:
            params: Territory claim parameters
            
        Returns:
            OP_RETURN script bytes
            
        Example:
            >>> script = TerritoryManager.build_claim_transaction(TerritoryClaimParams(
            ...     level=8,
            ...     h3_index='891f1d48177ffff',
            ...     owner_pubkey='owner_key',
            ...     stake_amount=800_000_000,
            ...     lock_height=821_600,
            ... ))
        """
        return TransactionBuilder.build_territory_claim(params)

    @staticmethod
    def build_release_transaction(territory_id: str, owner_pubkey: str) -> bytes:
        """
        Build a TERRITORY_RELEASE transaction script.
        
        Args:
            territory_id: Territory identifier
            owner_pubkey: Owner's public key
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_territory_release(territory_id, owner_pubkey)

    @staticmethod
    def build_transfer_transaction(
        territory_id: str,
        from_pubkey: str,
        to_pubkey: str,
        price: int = 0,
    ) -> bytes:
        """
        Build a TERRITORY_TRANSFER transaction script.
        
        Args:
            territory_id: Territory identifier
            from_pubkey: Seller's public key
            to_pubkey: Buyer's public key
            price: Transfer price in satoshis
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_territory_transfer(
            territory_id, from_pubkey, to_pubkey, price
        )

    @staticmethod
    def get_stake_for_level(level: TerritoryLevel) -> int:
        """
        Returns the base stake for a territory level.
        
        Args:
            level: Territory level (32, 16, 8, 4, etc.)
            
        Returns:
            Stake amount in satoshis
            
        Example:
            >>> TerritoryManager.get_stake_for_level(32)
            3200000000  # 32 BSV
        """
        return stake_for_level(level)

    @staticmethod
    def get_progressive_tax(level: TerritoryLevel, property_number: int) -> int:
        """
        Returns the progressive tax for the Nth property at a given level.
        
        Per spec 03-staking-economics.md:
        cost = base * 2^(n-1)
        
        Args:
            level: Territory level
            property_number: Property number (1st, 2nd, 3rd, etc.)
            
        Returns:
            Progressive tax amount in satoshis
            
        Example:
            >>> TerritoryManager.get_progressive_tax(8, 2)  # 2nd building
            1600000000  # 16 BSV
        """
        base = stake_for_level(level)
        return progressive_tax(base, property_number)

    @staticmethod
    def get_lock_height(current_block_height: int) -> int:
        """
        Calculate CLTV lock height for a territory claim.
        
        Args:
            current_block_height: Current blockchain height
            
        Returns:
            Lock height
        """
        return calculate_lock_height(current_block_height)

    @staticmethod
    def distribute_fees(total_fee: int) -> FeeDistribution:
        """
        Distributes a fee amount according to the protocol split.
        
        Per spec 01-territory-hierarchy.md:
          50% developer, 40% territory, 10% protocol
        
        Args:
            total_fee: Total fee amount in satoshis
            
        Returns:
            Fee distribution breakdown
            
        Example:
            >>> TerritoryManager.distribute_fees(10000)
            FeeDistribution(developer=5000, territory=4000, protocol=1000)
        """
        return FeeDistribution(
            developer=int(total_fee * FEE_DISTRIBUTION["DEVELOPER"]),
            territory=int(total_fee * FEE_DISTRIBUTION["TERRITORY"]),
            protocol=int(total_fee * FEE_DISTRIBUTION["PROTOCOL"]),
        )

    @staticmethod
    def distribute_territory_fees(territory_share: int) -> TerritoryFeeBreakdown:
        """
        Breaks down the territory share (40%) among building, city, and block.
        
        Per spec 01-territory-hierarchy.md:
          50% building owner, 30% city treasury, 20% block owner
        
        Args:
            territory_share: Territory portion of fees
            
        Returns:
            Territory fee breakdown
            
        Example:
            >>> TerritoryManager.distribute_territory_fees(4000)
            TerritoryFeeBreakdown(building=2000, city=1200, block=800)
        """
        return TerritoryFeeBreakdown(
            building=int(territory_share * TERRITORY_FEE_SPLIT["BUILDING"]),
            city=int(territory_share * TERRITORY_FEE_SPLIT["CITY"]),
            block=int(territory_share * TERRITORY_FEE_SPLIT["BLOCK"]),
        )
