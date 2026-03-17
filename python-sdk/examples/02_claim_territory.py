"""
Example 2: Claim Territory

Demonstrates claiming territories at different levels.
Per spec 01-territory-hierarchy.md:
/32 City → /16 Block → /8 Building → /4 Home
"""

from locus import (
    LocusClient,
    TerritoryManager,
    TerritoryClaimParams,
    CityManager,
)


def main():
    client = LocusClient(network='testnet')
    print("Locus Protocol - Claim Territory Example")
    print("=" * 50)

    # Step 1: Territory stake requirements
    print("\n1. Territory Stake Requirements:")
    levels = [32, 16, 8, 4]
    for level in levels:
        stake = TerritoryManager.get_stake_for_level(level)
        print(f"   /{level:2d}: {stake:>15,} sats ({stake / 1e8:.2f} BSV)")

    # Step 2: Progressive tax for multiple properties
    print("\n2. Progressive Property Tax (doubling per property):")
    print("   Building level (/8):")
    for n in range(1, 6):
        tax = TerritoryManager.get_progressive_tax(8, n)
        print(f"   Property #{n}: {tax:>15,} sats ({tax / 1e8:.2f} BSV)")

    # Step 3: Fee distribution
    print("\n3. Fee Distribution:")
    total_fee = 1_000_000  # 0.01 BSV
    fees = TerritoryManager.distribute_fees(total_fee)
    print(f"   Total Fee: {total_fee:,} sats")
    print(f"   Developer (50%): {fees.developer:,} sats")
    print(f"   Territory (40%): {fees.territory:,} sats")
    print(f"   Protocol (10%): {fees.protocol:,} sats")

    # Step 4: Territory fee breakdown
    print("\n4. Territory Fee Breakdown (of the 40% territory share):")
    breakdown = TerritoryManager.distribute_territory_fees(fees.territory)
    print(f"   Building (50%): {breakdown.building:,} sats")
    print(f"   City (30%): {breakdown.city:,} sats")
    print(f"   Block (20%): {breakdown.block:,} sats")

    # Step 5: Claim a block (/16)
    print("\n5. Claiming a Block (/16)...")
    current_height = 800_000
    
    block_params = TerritoryClaimParams(
        level=16,
        h3_index="8f283080dcb019d",
        owner_pubkey="owner_pubkey_here",
        stake_amount=800_000_000,  # 8 BSV
        lock_height=TerritoryManager.get_lock_height(current_height),
        parent_city="city_id_here",
        metadata={
            "name": "Block 42",
            "description": "Premium downtown block",
        },
    )

    block_script = TerritoryManager.build_claim_transaction(block_params)
    print(f"   Block claim script: {len(block_script)} bytes")

    # Step 6: Claim a building (/8)
    print("\n6. Claiming a Building (/8)...")
    
    building_params = TerritoryClaimParams(
        level=8,
        h3_index="891f1d48177ffff",
        owner_pubkey="owner_pubkey_here",
        stake_amount=800_000_000,  # 8 BSV
        lock_height=TerritoryManager.get_lock_height(current_height),
        parent_city="city_id_here",
        metadata={
            "name": "Cyber Tower",
            "floors": 42,
            "type": "mixed_use",
        },
    )

    building_script = TerritoryManager.build_claim_transaction(building_params)
    print(f"   Building claim script: {len(building_script)} bytes")

    # Step 7: Claim a home (/4)
    print("\n7. Claiming a Home (/4)...")
    
    home_params = TerritoryClaimParams(
        level=4,
        h3_index="8a1f1d48177ffff",
        owner_pubkey="owner_pubkey_here",
        stake_amount=400_000_000,  # 4 BSV
        lock_height=TerritoryManager.get_lock_height(current_height),
        parent_city="city_id_here",
        metadata={
            "name": "Penthouse Suite",
            "unit": "PH-1",
        },
    )

    home_script = TerritoryManager.build_claim_transaction(home_params)
    print(f"   Home claim script: {len(home_script)} bytes")

    # Step 8: Transfer a territory
    print("\n8. Transferring a Territory...")
    transfer_script = TerritoryManager.build_transfer_transaction(
        territory_id="territory_id_here",
        from_pubkey="seller_pubkey",
        to_pubkey="buyer_pubkey",
        price=1_000_000_000,  # 10 BSV
    )
    print(f"   Transfer script: {len(transfer_script)} bytes")

    # Step 9: Release a territory
    print("\n9. Releasing a Territory...")
    release_script = TerritoryManager.build_release_transaction(
        territory_id="territory_id_here",
        owner_pubkey="owner_pubkey_here",
    )
    print(f"   Release script: {len(release_script)} bytes")

    print("\n" + "=" * 50)
    print("Note: These are unsigned scripts. To complete:")
    print("1. Create full transaction with proper inputs")
    print("2. Sign with wallet containing the stake amount")
    print("3. Broadcast using client.broadcast()")


if __name__ == "__main__":
    main()
