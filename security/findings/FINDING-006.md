# FINDING-006: City Found Signature Field Always Empty

**Severity:** HIGH
**Component:** client
**File:** `client/src/modules/transaction-builder.ts:89`
**Status:** Open

## Description

The `buildCityFound` method always sets the signature field to an empty string:

```typescript
static buildCityFound(params: CityFoundParams): Buffer {
  return TransactionBuilder.encode('city_found', {
    // ...
    founder_pubkey: params.founderPubkey,
    policies: params.policies || {},
    signature: '',  // Always empty
  });
}
```

The Elixir core `build_city_found/1` similarly passes through `hex(params[:signature] || "")`.

## Impact

Without a signature binding the founder's pubkey to the city founding payload:
1. Anyone who observes a pending CITY_FOUND transaction in the mempool could front-run it by rebroadcasting with a different `founder_pubkey`
2. The OP_RETURN payload is not cryptographically bound to the transaction's input signature
3. A relay or indexer cannot verify that the CITY_FOUND message was authorized by the claimed founder

The BSV transaction itself is signed (via the input's scriptSig), which provides some protection. However, the protocol-layer signature in the OP_RETURN payload is a defense-in-depth mechanism that is currently non-functional.

## Remediation

See `remediation/REM-006.md`
