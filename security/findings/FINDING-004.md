# FINDING-004: Node Staking Script Diverges From Core Spec

**Severity:** HIGH
**Component:** node
**File:** `node/lib/locus/staking.ex:35-42`
**Status:** Open

## Description

The node's staking module builds a fundamentally different CLTV script than the core module:

**Node version (simple, no emergency path):**
```elixir
def build_lock_script(lock_height, owner_pubkey) do
  Script.new()
  |> Script.push_int(lock_height)
  |> Script.push_op(:OP_CHECKLOCKTIMEVERIFY)
  |> Script.push_op(:OP_DROP)
  |> Script.push_data(owner_pubkey)
  |> Script.push_op(:OP_CHECKSIG)
end
```

**Core version (OP_IF/OP_ELSE with emergency path):**
```elixir
def build_lock_script(owner_pubkey, lock_height, protocol_treasury_address) do
  # OP_IF normal path with CLTV
  # OP_ELSE emergency path with CSV
  # OP_ENDIF
end
```

## Impact

1. The node builds ghost registration transactions using the simple script (no emergency unlock)
2. The core expects the complex script with emergency unlock capability
3. UTXOs created by the node cannot be emergency-unlocked using core's `emergency_unlock/5`
4. The two modules are functionally incompatible — a transaction built by one cannot be properly validated/spent by the other
5. Function signatures differ: node takes `(lock_height, owner_pubkey)`, core takes `(owner_pubkey, lock_height, treasury_address)`

## Remediation

See `remediation/REM-004.md`
