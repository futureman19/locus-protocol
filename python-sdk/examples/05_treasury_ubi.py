"""
Example 5: Treasury and UBI

Demonstrates UBI calculations and token redemption.
Per spec 03-staking-economics.md:
- UBI activates at Phase 4 (city, 21+ citizens)
- Formula: daily_ubi = (treasury * 0.001) / citizen_count
- Monthly cap: 1% of treasury
"""

from locus import (
    LocusClient,
    TreasuryManager,
    CityManager,
)


def main():
    client = LocusClient(network='testnet')
    print("Locus Protocol - Treasury & UBI Example")
    print("=" * 50)

    # Step 1: UBI Eligibility
    print("\n1. UBI Eligibility:")
    phases = ['village', 'town', 'city', 'metropolis']
    treasury_small = 50_000_000_000   # 500 BSV (below min)
    treasury_large = 200_000_000_000  # 2000 BSV (above min)
    
    for phase in phases:
        eligible_small = TreasuryManager.is_ubi_eligible(phase, treasury_small)
        eligible_large = TreasuryManager.is_ubi_eligible(phase, treasury_large)
        print(f"   {phase:12s} | 500 BSV: {'✓' if eligible_small else '✗'} | 2000 BSV: {'✓' if eligible_large else '✗'}")

    # Step 2: UBI calculation examples
    print("\n2. UBI Calculation Examples:")
    scenarios = [
        (100_000_000_000, 25, "Medium City"),   # 1000 BSV, 25 citizens
        (500_000_000_000, 100, "Large City"),   # 5000 BSV, 100 citizens
        (50_000_000_000, 10, "Small City"),     # 500 BSV, 10 citizens
    ]
    
    for treasury, citizens, desc in scenarios:
        daily = TreasuryManager.calculate_daily_ubi(treasury, citizens)
        monthly_cap = TreasuryManager.calculate_monthly_cap(treasury)
        info = TreasuryManager.get_ubi_info('city', treasury, citizens)
        
        print(f"\n   {desc}:")
        print(f"      Treasury: {treasury/1e8:,.0f} BSV | Citizens: {citizens}")
        print(f"      Daily UBI per citizen: {daily:,.0f} sats ({daily/1e8:.4f} BSV)")
        print(f"      Monthly cap: {monthly_cap:,.0f} sats ({monthly_cap/1e8:.4f} BSV)")
        print(f"      Active: {'Yes' if info.is_active else 'No'}")

    # Step 3: Full UBI info
    print("\n3. Full UBI Info for Metropolis:")
    ubi_info = TreasuryManager.get_ubi_info('metropolis', 1_000_000_000_000, 200)
    print(f"   Daily per citizen: {ubi_info.daily_per_citizen:,.0f} sats")
    print(f"   Monthly cap: {ubi_info.monthly_cap:,.0f} sats")
    print(f"   Treasury balance: {ubi_info.treasury_balance:,.0f} sats")
    print(f"   Citizen count: {ubi_info.citizen_count}")
    print(f"   Is active: {ubi_info.is_active}")
    print(f"   Min treasury: {ubi_info.min_treasury:,.0f} sats")

    # Step 4: Token redemption
    print("\n4. Token Redemption:")
    
    # Different treasury sizes
    treasuries = [
        100_000_000_000,   # 1000 BSV
        500_000_000_000,   # 5000 BSV
        1_000_000_000_000, # 10000 BSV
    ]
    
    total_supply = 3_200_000  # LOCUS tokens
    
    for treasury in treasuries:
        rate = TreasuryManager.redemption_rate(treasury, total_supply)
        redeem_1000 = TreasuryManager.redeem_tokens(1000, treasury, total_supply)
        redeem_10000 = TreasuryManager.redeem_tokens(10000, treasury, total_supply)
        
        print(f"\n   Treasury: {treasury/1e8:,.0f} BSV")
        print(f"   Redemption rate: {rate:,.0f} sats per token")
        print(f"   1,000 tokens = {redeem_1000/1e8:.4f} BSV")
        print(f"   10,000 tokens = {redeem_10000/1e8:.4f} BSV")

    # Step 5: Founder vesting
    print("\n5. Founder Token Vesting:")
    print("   Month | Vested Tokens | Percentage")
    print("   " + "-" * 40)
    
    total_founder = 640_000
    for month in range(0, 15):
        vested = TreasuryManager.vested_founder_tokens(month)
        pct = (vested / total_founder) * 100
        bar = "█" * int(pct / 5)
        print(f"   {month:5d} | {vested:13,} | {pct:5.1f}% {bar}")

    # Step 6: UBI claim
    print("\n6. UBI Claim Transaction:")
    claim_script = TreasuryManager.build_claim_transaction(
        city_id='city_123',
        citizen_pubkey='citizen_pubkey',
        claim_periods=7,  # Claim 7 days
    )
    print(f"   Claim script: {len(claim_script)} bytes")
    print(f"   Claiming for: 7 periods (1 week)")

    # Step 7: Treasury growth scenario
    print("\n7. Treasury Growth Scenario:")
    print("   Simulating a city growing from founding to metropolis...")
    
    citizens_list = [1, 5, 15, 30, 75, 150]
    base_treasury = 100_000_000_000  # Start with 1000 BSV
    
    for citizens in citizens_list:
        phase = CityManager.get_phase(citizens)
        treasury = base_treasury * (1 + citizens * 0.02)  # Simulate growth
        
        if phase in ['city', 'metropolis']:
            daily = TreasuryManager.calculate_daily_ubi(int(treasury), citizens)
            monthly = daily * 30 * citizens
            monthly_cap = TreasuryManager.calculate_monthly_cap(int(treasury))
            capped = min(monthly, monthly_cap)
            
            print(f"\n   {phase:12s} ({citizens:3d} citizens)")
            print(f"      Treasury: {treasury/1e8:,.0f} BSV")
            print(f"      Daily per citizen: {daily/1e8:.4f} BSV")
            print(f"      Monthly total (capped): {capped/1e8:.2f} BSV")
        else:
            print(f"\n   {phase:12s} ({citizens:3d} citizens) - UBI not active")

    print("\n" + "=" * 50)
    print("Treasury & UBI Summary:")
    print("- UBI activates at 21+ citizens (city phase)")
    print("- Minimum treasury: 100 BSV")
    print("- Daily rate: 0.1% of treasury / citizen count")
    print("- Monthly cap: 1% of treasury total")
    print("- Tokens redeemable based on treasury ratio")


if __name__ == "__main__":
    main()
