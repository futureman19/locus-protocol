"""
Treasury Manager

UBI calculations, token redemption, treasury accounting.

Per spec 03-staking-economics.md:
- UBI activates at Phase 4 (city, 21+ citizens)
- Formula: daily_ubi = (treasury_bsv * 0.001) / citizen_count
- Monthly cap: 1% of treasury
- Min treasury: 100 BSV (10,000,000,000 sats)
"""

from .transaction import TransactionBuilder
from .types import CityPhase, UBIInfo, UBIClaimParams
from .constants import UBI, TOKEN_DISTRIBUTION


class TreasuryManager:
    """
    Manages treasury operations including UBI and token redemption.
    
    Provides calculations for UBI distribution, token redemption rates,
    and founder token vesting schedules.
    """

    @staticmethod
    def calculate_daily_ubi(treasury_sats: int, citizen_count: int) -> int:
        """
        Calculate daily UBI per citizen.
        
        Formula: (treasury_sats * 0.001) / citizen_count
        
        Args:
            treasury_sats: Treasury balance in satoshis
            citizen_count: Number of citizens
            
        Returns:
            Daily UBI per citizen in satoshis
            
        Example:
            >>> TreasuryManager.calculate_daily_ubi(100_000_000_000, 25)
            4000000  # 0.04 BSV per citizen
        """
        if citizen_count <= 0:
            return 0
        return int((treasury_sats * UBI["RATE"]) / citizen_count)

    @staticmethod
    def calculate_monthly_cap(treasury_sats: int) -> int:
        """
        Calculate monthly cap on UBI distribution.
        Max 1% of treasury per month.
        
        Args:
            treasury_sats: Treasury balance in satoshis
            
        Returns:
            Monthly cap in satoshis
            
        Example:
            >>> TreasuryManager.calculate_monthly_cap(100_000_000_000)
            1000000000  # 10 BSV cap
        """
        return int(treasury_sats * UBI["MONTHLY_CAP_RATE"])

    @staticmethod
    def is_ubi_eligible(phase: CityPhase, treasury_sats: int) -> bool:
        """
        Check if UBI can be distributed (phase + treasury minimums).
        
        Args:
            phase: Current city phase
            treasury_sats: Treasury balance in satoshis
            
        Returns:
            True if UBI is eligible
            
        Example:
            >>> TreasuryManager.is_ubi_eligible('city', 100_000_000_000)
            True
            >>> TreasuryManager.is_ubi_eligible('town', 100_000_000_000)
            False
        """
        eligible_phases: list[CityPhase] = ["city", "metropolis"]
        return phase in eligible_phases and treasury_sats >= UBI["MIN_TREASURY_SATS"]

    @staticmethod
    def get_ubi_info(
        phase: CityPhase,
        treasury_sats: int,
        citizen_count: int,
    ) -> UBIInfo:
        """
        Get full UBI info for a city.
        
        Args:
            phase: Current city phase
            treasury_sats: Treasury balance in satoshis
            citizen_count: Number of citizens
            
        Returns:
            Complete UBI information
            
        Example:
            >>> info = TreasuryManager.get_ubi_info('city', 100_000_000_000, 25)
            >>> info.is_active
            True
            >>> info.daily_per_citizen
            4000000
        """
        is_active = TreasuryManager.is_ubi_eligible(phase, treasury_sats)
        return UBIInfo(
            daily_per_citizen=TreasuryManager.calculate_daily_ubi(treasury_sats, citizen_count)
            if is_active else 0,
            monthly_cap=TreasuryManager.calculate_monthly_cap(treasury_sats),
            treasury_balance=treasury_sats,
            citizen_count=citizen_count,
            is_active=is_active,
            min_treasury=int(UBI["MIN_TREASURY_SATS"]),
        )

    @staticmethod
    def build_claim_transaction(
        city_id: str,
        citizen_pubkey: str,
        claim_periods: int,
    ) -> bytes:
        """
        Build a UBI_CLAIM transaction script.
        
        Args:
            city_id: City identifier
            citizen_pubkey: Citizen's public key
            claim_periods: Number of periods to claim
            
        Returns:
            OP_RETURN script bytes
        """
        return TransactionBuilder.build_ubi_claim(city_id, citizen_pubkey, claim_periods)

    @staticmethod
    def redemption_rate(treasury_sats: int, total_supply: int | None = None) -> float:
        """
        Calculate token redemption rate.
        
        Formula: rate = treasury_sats / total_token_supply
        
        Args:
            treasury_sats: Treasury balance in satoshis
            total_supply: Total token supply (defaults to 3.2M)
            
        Returns:
            Redemption rate (satoshis per token)
            
        Example:
            >>> TreasuryManager.redemption_rate(100_000_000_000)
            31250.0
        """
        supply = total_supply if total_supply is not None else TOKEN_DISTRIBUTION["TOTAL_SUPPLY"]
        if supply <= 0:
            return 0.0
        return treasury_sats / supply

    @staticmethod
    def redeem_tokens(
        tokens: int,
        treasury_sats: int,
        total_supply: int | None = None,
    ) -> int:
        """
        Calculate BSV received for redeeming tokens.
        
        Formula: amount = tokens * (treasury_sats / total_supply)
        
        Args:
            tokens: Number of tokens to redeem
            treasury_sats: Treasury balance in satoshis
            total_supply: Total token supply (defaults to 3.2M)
            
        Returns:
            Redemption amount in satoshis
            
        Example:
            >>> TreasuryManager.redeem_tokens(1000, 100_000_000_000)
            31250000  # 31.25M sats
        """
        rate = TreasuryManager.redemption_rate(treasury_sats, total_supply)
        return int(tokens * rate)

    @staticmethod
    def vested_founder_tokens(months_elapsed: int) -> int:
        """
        Calculate vested founder tokens at a given month.
        Linear: 1/12 per month.
        
        Args:
            months_elapsed: Months since founding
            
        Returns:
            Vested token amount
            
        Example:
            >>> TreasuryManager.vested_founder_tokens(6)
            320000  # 50% vested at 6 months
        """
        if months_elapsed <= 0:
            return 0
        if months_elapsed >= TOKEN_DISTRIBUTION["FOUNDER_VEST_MONTHS"]:
            return TOKEN_DISTRIBUTION["FOUNDER"]
        return (TOKEN_DISTRIBUTION["FOUNDER"] * months_elapsed) // TOKEN_DISTRIBUTION["FOUNDER_VEST_MONTHS"]
