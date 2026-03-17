"""
Example 6: Full Transaction Flow

Demonstrates a complete transaction flow including encoding/decoding
and all transaction types.
"""

from locus import (
    LocusClient,
    TransactionBuilder,
    CityFoundParams,
    TerritoryClaimParams,
    ObjectDeployParams,
    ProposeParams,
    HeartbeatParams,
    ProposalAction,
    TYPE_CODES,
    PROTOCOL_VERSION,
)


def main():
    client = LocusClient(network='testnet')
    print("Locus Protocol - Full Transaction Flow Example")
    print("=" * 50)

    # Step 1: List all transaction types
    print("\n1. All 17 Transaction Types:")
    for name, code in sorted(TYPE_CODES.items(), key=lambda x: x[1]):
        print(f"   0x{code:02x}: {name}")

    # Step 2: Encode and decode a transaction
    print("\n2. Encode/Decode Roundtrip:")
    
    original_payload = {
        'name': 'Test City',
        'stake': 3_200_000_000,
        'location': {'lat': 35.0, 'lng': 139.0},
    }
    
    script = TransactionBuilder.encode('city_found', original_payload)
    decoded = TransactionBuilder.decode(script)
    
    print(f"   Original: {original_payload}")
    print(f"   Decoded:  {decoded.data}")
    print(f"   Type: {decoded.type}")
    print(f"   Version: {decoded.version} (matches PROTOCOL_VERSION: {decoded.version == PROTOCOL_VERSION})")

    # Step 3: Build all transaction types
    print("\n3. Building All Transaction Types:")
    
    transactions = []
    
    # City operations
    city_found = TransactionBuilder.build_city_found(CityFoundParams(
        name='Neo-Tokyo',
        lat=35.6762,
        lng=139.6503,
        h3_res7='8f283080dcb019d',
        founder_pubkey='founder_key',
    ))
    transactions.append(('city_found', city_found))
    
    citizen_join = TransactionBuilder.build_citizen_join('city_123', 'citizen_key')
    transactions.append(('citizen_join', citizen_join))
    
    citizen_leave = TransactionBuilder.build_citizen_leave('city_123', 'citizen_key')
    transactions.append(('citizen_leave', citizen_leave))
    
    city_update = TransactionBuilder.build_city_update('city_123', 'updater_key', {'name': 'Updated'})
    transactions.append(('city_update', city_update))
    
    # Territory operations
    territory_claim = TransactionBuilder.build_territory_claim(TerritoryClaimParams(
        level=8,
        h3_index='891f1d48177ffff',
        owner_pubkey='owner_key',
        stake_amount=800_000_000,
        lock_height=821_600,
    ))
    transactions.append(('territory_claim', territory_claim))
    
    territory_release = TransactionBuilder.build_territory_release('territory_123', 'owner_key')
    transactions.append(('territory_release', territory_release))
    
    territory_transfer = TransactionBuilder.build_territory_transfer(
        'territory_123', 'from_key', 'to_key', 1_000_000
    )
    transactions.append(('territory_transfer', territory_transfer))
    
    # Object operations
    object_deploy = TransactionBuilder.build_object_deploy(ObjectDeployParams(
        object_type='agent',
        h3_index='891f1d48177ffff',
        owner_pubkey='owner_key',
        stake_amount=10_000_000,
        content_hash='content_hash',
        parent_territory='parent_id',
    ))
    transactions.append(('object_deploy', object_deploy))
    
    object_update = TransactionBuilder.build_object_update('object_123', 'owner_key', {'status': 'active'})
    transactions.append(('object_update', object_update))
    
    object_destroy = TransactionBuilder.build_object_destroy('object_123', 'owner_key', 'reason')
    transactions.append(('object_destroy', object_destroy))
    
    # Protocol operations
    heartbeat = TransactionBuilder.build_heartbeat(HeartbeatParams(
        heartbeat_type=1,
        entity_id='entity_123',
        h3_index='891f1d48177ffff',
    ))
    transactions.append(('heartbeat', heartbeat))
    
    ghost_invoke = TransactionBuilder.build_ghost_invoke('ghost_123', 'invoker_key', 'h3_index', 'session')
    transactions.append(('ghost_invoke', ghost_invoke))
    
    ghost_payment = TransactionBuilder.build_ghost_payment('ghost_123', 'payer_key', 1_000_000)
    transactions.append(('ghost_payment', ghost_payment))
    
    # Governance operations
    gov_propose = TransactionBuilder.build_gov_propose(ProposeParams(
        proposal_type='parameter_change',
        title='Test Proposal',
        proposer_pubkey='proposer_key',
    ))
    transactions.append(('gov_propose', gov_propose))
    
    gov_vote = TransactionBuilder.build_gov_vote('proposal_123', 'voter_key', 'yes')
    transactions.append(('gov_vote', gov_vote))
    
    gov_exec = TransactionBuilder.build_gov_exec('proposal_123', 'executor_key')
    transactions.append(('gov_exec', gov_exec))
    
    # Treasury operations
    ubi_claim = TransactionBuilder.build_ubi_claim('city_123', 'citizen_key', 7)
    transactions.append(('ubi_claim', ubi_claim))
    
    # Print sizes
    for name, tx in transactions:
        print(f"   {name:20s}: {len(tx):3d} bytes")

    # Step 4: Verify roundtrip for each type
    print("\n4. Verifying All Roundtrips:")
    all_passed = True
    for name, tx in transactions:
        try:
            decoded = TransactionBuilder.decode(tx)
            if decoded.type != name:
                print(f"   ✗ {name}: Type mismatch")
                all_passed = False
            else:
                print(f"   ✓ {name}")
        except Exception as e:
            print(f"   ✗ {name}: {e}")
            all_passed = False
    
    if all_passed:
        print("\n   All transaction types encode/decode correctly!")

    # Step 5: Transaction structure breakdown
    print("\n5. Transaction Structure (city_found example):")
    sample_tx = transactions[0][1]
    
    print(f"   Total size: {len(sample_tx)} bytes")
    print(f"   Hex: {sample_tx.hex()[:100]}...")
    
    # First byte is OP_RETURN
    print(f"   Byte 0: 0x{sample_tx[0]:02x} (OP_RETURN)")
    
    # Second byte is length or pushdata
    if sample_tx[1] <= 0x4b:
        print(f"   Byte 1: 0x{sample_tx[1]:02x} (length: {sample_tx[1]} bytes)")
    elif sample_tx[1] == 0x4c:
        print(f"   Byte 1: 0x{sample_tx[1]:02x} (OP_PUSHDATA1)")
        print(f"   Byte 2: 0x{sample_tx[2]:02x} (length: {sample_tx[2]} bytes)")

    # Step 6: Protocol prefix verification
    print("\n6. Protocol Prefix Verification:")
    # Extract and verify prefix
    decoded = TransactionBuilder.decode(sample_tx)
    print(f"   Protocol: LOCUS (verified in decode)")
    print(f"   Version: {decoded.version}")
    print(f"   Type: {decoded.type}")

    print("\n" + "=" * 50)
    print("Transaction Flow Summary:")
    print("1. Build transaction using TransactionBuilder or Managers")
    print("2. Transaction encoded as: OP_RETURN | length | LOCUS | version | type | msgpack_payload")
    print("3. Can be decoded back to verify contents")
    print("4. Broadcast to network using client.broadcast()")


if __name__ == "__main__":
    main()
