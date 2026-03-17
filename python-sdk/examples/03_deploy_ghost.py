"""
Example 3: Deploy a Ghost

Demonstrates deploying a ghost (agent object) on the Locus Protocol.
Per spec 05-ghost-protocol.md:
- Ghosts are /1 Objects with type 'agent'
- Minimum stake: 0.1 BSV (10,000,000 sats)
- Can be invoked and paid
"""

from locus import (
    LocusClient,
    ObjectManager,
    ObjectDeployParams,
    HeartbeatManager,
)


def main():
    client = LocusClient(network='testnet')
    print("Locus Protocol - Deploy Ghost Example")
    print("=" * 50)

    # Step 1: Object stake requirements
    print("\n1. Object Stake Requirements:")
    object_types = ['item', 'waypoint', 'agent', 'billboard', 'rare', 'epic', 'legendary']
    for obj_type in object_types:
        stake = ObjectManager.get_min_stake(obj_type)
        print(f"   {obj_type:12s}: {stake:>15,} sats ({stake / 1e8:.4f} BSV)")

    # Step 2: Deploy a ghost (agent)
    print("\n2. Deploying a Ghost (Agent)...")
    
    ghost_params = ObjectDeployParams(
        object_type='agent',
        h3_index='891f1d48177ffff',
        owner_pubkey='ghost_owner_pubkey',
        stake_amount=100_000_000,  # 1 BSV (above 0.1 minimum)
        content_hash='sha256_of_manifest_or_code',
        parent_territory='building_territory_id',
        capabilities=[
            'oracle',      # Can provide external data
            'compute',     # Can execute code
            'payment',     # Can receive payments
            'presence',    # Supports heartbeat
        ],
    )

    deploy_script = ObjectManager.build_deploy_transaction(ghost_params)
    print(f"   Deploy script: {len(deploy_script)} bytes")
    print(f"   Ghost capabilities: {', '.join(ghost_params.capabilities)}")

    # Step 3: Ghost invocation
    print("\n3. Invoking a Ghost...")
    
    invoke_script = ObjectManager.build_ghost_invoke_transaction(
        ghost_id='ghost_object_id',
        invoker_pubkey='user_pubkey',
        invoker_location='8a1f1d48177ffff',  # User's H3 location
        session_id='session_12345',
    )
    print(f"   Invoke script: {len(invoke_script)} bytes")

    # Step 4: Ghost payment
    print("\n4. Paying a Ghost...")
    
    payment_script = ObjectManager.build_ghost_payment_transaction(
        ghost_id='ghost_object_id',
        payer_pubkey='user_pubkey',
        amount=1_000_000,  # 0.01 BSV
        service_id='compute_job_67890',
    )
    print(f"   Payment script: {len(payment_script)} bytes")

    # Step 5: Ghost heartbeat
    print("\n5. Ghost Heartbeat...")
    
    heartbeat_script = HeartbeatManager.build_property_heartbeat(
        entity_id='ghost_object_id',
        h3_index='891f1d48177ffff',
        entity_type=1,  # Object/Agent type
    )
    print(f"   Heartbeat script: {len(heartbeat_script)} bytes")

    # Step 6: Update ghost
    print("\n6. Updating Ghost...")
    
    update_script = ObjectManager.build_update_transaction(
        object_id='ghost_object_id',
        owner_pubkey='ghost_owner_pubkey',
        updates={
            'status': 'active',
            'version': '1.2.0',
            'rate': 500_000,  # Updated service rate
        },
    )
    print(f"   Update script: {len(update_script)} bytes")

    # Step 7: Destroy ghost
    print("\n7. Destroying Ghost...")
    
    destroy_script = ObjectManager.build_destroy_transaction(
        object_id='ghost_object_id',
        owner_pubkey='ghost_owner_pubkey',
        reason='Service discontinued - migrating to new version',
    )
    print(f"   Destroy script: {len(destroy_script)} bytes")

    # Step 8: Deploy other object types for comparison
    print("\n8. Other Object Examples:")
    
    # Deploy a rare object
    rare_params = ObjectDeployParams(
        object_type='rare',
        h3_index='8a1f1d48177ffff',
        owner_pubkey='owner_pubkey',
        stake_amount=1_600_000_000,  # 16 BSV
        content_hash='rare_nft_hash',
        parent_territory='home_territory_id',
    )
    rare_script = ObjectManager.build_deploy_transaction(rare_params)
    print(f"   Rare object: {len(rare_script)} bytes (16 BSV stake)")

    # Deploy a legendary object
    legendary_params = ObjectDeployParams(
        object_type='legendary',
        h3_index='8b1f1d48177ffff',
        owner_pubkey='owner_pubkey',
        stake_amount=6_400_000_000,  # 64 BSV
        content_hash='legendary_artifact_hash',
        parent_territory='city_territory_id',
    )
    legendary_script = ObjectManager.build_deploy_transaction(legendary_params)
    print(f"   Legendary object: {len(legendary_script)} bytes (64 BSV stake)")

    print("\n" + "=" * 50)
    print("Ghost Lifecycle Complete!")
    print("- Deploy: Create the ghost with stake")
    print("- Invoke: Users invoke the ghost")
    print("- Pay: Users pay for services")
    print("- Heartbeat: Maintain presence")
    print("- Update: Modify ghost parameters")
    print("- Destroy: Return stake and remove")


if __name__ == "__main__":
    main()
