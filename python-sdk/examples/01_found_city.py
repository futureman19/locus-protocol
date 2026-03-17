"""
Example 1: Found a City

Demonstrates founding a new city on the Locus Protocol.
Per spec 02-city-lifecycle.md:
- 32 BSV founding stake
- 21,600 block CLTV lock (~5 months)
- Token distribution: 20% founder, 50% treasury, 25% public sale, 5% dev
"""

from locus import LocusClient, CityManager, CityFoundParams, CityPolicies


def main():
    # Initialize client (using testnet for this example)
    client = LocusClient(network='testnet')
    print("Locus Protocol - Found a City Example")
    print("=" * 50)

    # Step 1: Check founding stake requirement
    founding_stake = CityManager.get_founding_stake()
    print(f"\n1. Founding Stake Required: {founding_stake:,} satoshis ({founding_stake / 1e8:.2f} BSV)")

    # Step 2: Calculate lock height (assuming current height)
    current_height = 800_000  # Example block height
    lock_height = CityManager.get_lock_height(current_height)
    lock_period = CityManager.get_lock_period()
    print(f"\n2. Lock Details:")
    print(f"   Current Height: {current_height:,}")
    print(f"   Lock Height: {lock_height:,}")
    print(f"   Lock Period: {lock_period:,} blocks (~5 months)")

    # Step 3: View token distribution
    token_dist = CityManager.get_token_distribution()
    print(f"\n3. Token Distribution:")
    print(f"   Total Supply: {token_dist.total:,} LOCUS")
    print(f"   Founder (20%): {token_dist.founder:,} LOCUS")
    print(f"   Treasury (50%): {token_dist.treasury:,} LOCUS")
    print(f"   Public Sale (25%): {token_dist.public_sale:,} LOCUS")
    print(f"   Protocol Dev (5%): {token_dist.protocol_dev:,} LOCUS")

    # Step 4: Founder vesting schedule
    print(f"\n4. Founder Vesting Schedule (12 months):")
    for months in [0, 3, 6, 9, 12, 18]:
        vested = CityManager.founder_vested_tokens(months)
        percentage = (vested / token_dist.founder) * 100
        print(f"   Month {months:2d}: {vested:,} LOCUS ({percentage:.1f}%)")

    # Step 5: Build the city founding transaction
    print(f"\n5. Building City Founding Transaction...")
    
    city_params = CityFoundParams(
        name="Neo-Tokyo",
        description="A cyberpunk metropolis on the blockchain",
        lat=35.6762,  # Tokyo coordinates
        lng=139.6503,
        h3_res7="8f283080dcb019d",  # H3 index at resolution 7
        founder_pubkey="02abc123def456...",  # Replace with actual pubkey
        policies=CityPolicies(
            block_auction_period=86400,  # 24 hours
            block_starting_bid=1_000_000,  # 0.01 BSV
            immigration_policy="open",
        ),
    )

    script = CityManager.build_found_transaction(city_params)
    print(f"   Transaction script built: {len(script)} bytes")
    print(f"   Script hex (first 100 chars): {script.hex()[:100]}...")

    # Step 6: Simulate city growth phases
    print(f"\n6. City Growth Phases:")
    citizen_counts = [1, 2, 5, 10, 25, 60]
    for count in citizen_counts:
        phase = CityManager.get_phase(count)
        governance = CityManager.get_governance_type(phase)
        unlocked_blocks = CityManager.get_unlocked_blocks(count)
        ubi_active = CityManager.is_ubi_active(phase)
        print(f"   {count:2d} citizens: {phase:12s} | {governance:20s} | "
              f"{unlocked_blocks:2d} blocks | UBI: {'✓' if ubi_active else '✗'}")

    print("\n" + "=" * 50)
    print("Note: To actually broadcast this transaction, you would:")
    print("1. Sign the transaction with a wallet holding 32 BSV")
    print("2. Broadcast using client.broadcast(signed_tx_hex)")


if __name__ == "__main__":
    main()
