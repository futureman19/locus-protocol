# FINDING-012: Unrestricted CORS on Indexer API

**Severity:** MEDIUM
**Component:** indexer
**File:** `indexer/src/server.ts`
**Status:** Open

## Description

The indexer uses `cors()` middleware with default settings, which allows requests from any origin:

```typescript
import cors from 'cors';
app.use(cors());
```

## Impact

- Any website can query the indexer API from a browser context
- While the indexer is read-only (no mutations via API), unrestricted CORS enables:
  1. Third-party sites scraping city/citizen data
  2. Potential abuse for user fingerprinting (querying which cities/pubkeys a user interacts with)
  3. Amplification attacks where malicious sites trigger many API requests from user browsers

The indexer is designed as a public data source, so open read access may be intentional. However, CORS should still be configured explicitly rather than left as a permissive default.

## Remediation

See `remediation/REM-012.md`
