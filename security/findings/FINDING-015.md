# FINDING-015: Type Code Mismatch Between Core and Node

**Severity:** LOW
**Component:** core, node
**Files:** `core/lib/locus/transaction.ex:37-55`, `node/lib/locus/tx_builder.ex:18-28`
**Status:** Open

## Description

The core and node modules define different type code mappings:

**Core (`transaction.ex`):**
```elixir
@type_codes %{
  city_found: 0x01,
  city_update: 0x02,
  citizen_join: 0x03,
  territory_claim: 0x10,
  # ...
}
```

**Node (`tx_builder.ex`):**
```elixir
@type_codes %{
  ghost_register: 0x01,
  ghost_update: 0x02,
  ghost_retire: 0x03,
  heartbeat: 0x04,
  invocation: 0x05,
  # ...
}
```

Type code `0x01` means `city_found` in core but `ghost_register` in node. Type code `0x03` means `citizen_join` in core but `ghost_retire` in node.

## Impact

- The node's ghost protocol operates in a different type code space than the core's territory protocol
- An indexer parsing transactions would need to know which component produced the transaction
- Without a namespace or version discriminator, type code collisions cause misinterpretation
- The protocol prefix differs too: core uses `"LOCUS"`, node uses `"locus"` (lowercase)

The case-sensitive prefix difference (`"LOCUS"` vs `"locus"`) actually prevents misinterpretation in practice, as the parser checks the prefix before interpreting the type code. However, this is accidental safety, not intentional design.

## Remediation

See `remediation/REM-015.md`
