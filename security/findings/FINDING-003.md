# FINDING-003: CLTV Emergency Path Missing Penalty Enforcement

**Severity:** HIGH
**Component:** core
**File:** `core/lib/locus/staking.ex:74-80`
**Status:** Open

## Description

The CLTV lock script's emergency unlock path uses the same `owner_pubkey` for OP_CHECKSIG as the normal path. The `protocol_treasury_address` parameter is accepted by `build_lock_script/3` but never incorporated into the script:

```elixir
def build_lock_script(owner_pubkey, lock_height, protocol_treasury_address) do
  # ...
  |> Script.push_op(:OP_ELSE)
  # Emergency unlock path (10% penalty)
  |> Script.push_int(10)
  |> Script.push_op(:OP_CHECKSEQUENCEVERIFY)
  |> Script.push_op(:OP_DROP)
  |> Script.push_data(Base.decode16!(owner_pubkey, case: :mixed))  # Same key!
  |> Script.push_op(:OP_CHECKSIG)
  # ...
end
```

The 10% penalty is only enforced at the application layer in `emergency_unlock/5`, not at the Bitcoin script level.

## Impact

The owner can craft a spending transaction on the emergency path that sends 100% of the stake to themselves, bypassing the 10% penalty entirely. The script only requires:
1. A valid signature from `owner_pubkey`
2. 10 blocks of relative timelock (CSV)

There is no on-chain enforcement that 10% must go to the protocol treasury.

## Attack Scenario

1. Owner locks 32 BSV in CLTV stake
2. Owner decides to emergency unlock
3. Instead of using the protocol's `emergency_unlock/5` function, owner constructs a raw transaction
4. Transaction spends the emergency path with a single output: 32 BSV to owner's address
5. Transaction is valid — script only checks CSV delay + owner signature
6. Protocol treasury receives nothing

## Remediation

See `remediation/REM-003.md`
