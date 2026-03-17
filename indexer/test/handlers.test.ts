import { describe, it, expect, vi } from 'vitest';
import { ParsedTransaction, parseScript } from '../src/scanner/parser';
import { pack } from 'msgpackr';

// Test handler logic by verifying parsed transactions produce correct SQL parameters
// Since handlers require a real database connection, we test the parser→handler data flow

function buildLocusScript(typeCode: number, payload: Record<string, unknown>): Buffer {
  const prefix = Buffer.from('LOCUS', 'utf8');
  const version = Buffer.from([0x01]);
  const type = Buffer.from([typeCode]);
  const msgpack = pack(payload);
  const content = Buffer.concat([prefix, version, type, msgpack]);
  const pushLen = content.length;
  let header: Buffer;
  if (pushLen < 0x4c) {
    header = Buffer.from([0x6a, pushLen]);
  } else if (pushLen <= 0xff) {
    header = Buffer.from([0x6a, 0x4c, pushLen]);
  } else {
    header = Buffer.from([0x6a, 0x4d, pushLen & 0xff, (pushLen >> 8) & 0xff]);
  }
  return Buffer.concat([header, content]);
}

describe('Handler data extraction', () => {
  describe('city_found (0x01)', () => {
    it('extracts city founding data', () => {
      const payload = {
        name: 'Neo-Tokyo',
        description: 'A cyberpunk city',
        location: { lat: 35.6762, lng: 139.6503, h3_res7: '8f283080dcb019d' },
        founder_pubkey: 'abcdef1234567890',
      };

      const script = buildLocusScript(0x01, payload);
      const parsed = parseScript(script)!;

      expect(parsed.typeName).toBe('city_found');
      expect(parsed.data['name']).toBe('Neo-Tokyo');
      expect((parsed.data['location'] as any)['h3_res7']).toBe('8f283080dcb019d');
      expect(parsed.data['founder_pubkey']).toBe('abcdef1234567890');
    });
  });

  describe('citizen_join (0x03)', () => {
    it('extracts citizen join data', () => {
      const payload = { city_id: '8f283080dcb019d', citizen_pubkey: 'citizen_key_123' };
      const parsed = parseScript(buildLocusScript(0x03, payload))!;

      expect(parsed.typeName).toBe('citizen_join');
      expect(parsed.data['city_id']).toBe('8f283080dcb019d');
      expect(parsed.data['citizen_pubkey']).toBe('citizen_key_123');
    });
  });

  describe('territory_claim (0x10)', () => {
    it('extracts territory claim data', () => {
      const payload = {
        level: 8,
        location: '891f1d48177ffff',
        owner_pubkey: 'owner_key',
        stake_amount: 800_000_000,
        lock_height: 821_600,
        parent_city: '8f283080dcb019d',
      };

      const parsed = parseScript(buildLocusScript(0x10, payload))!;

      expect(parsed.typeName).toBe('territory_claim');
      expect(parsed.data['level']).toBe(8);
      expect(parsed.data['stake_amount']).toBe(800_000_000);
      expect(parsed.data['lock_height']).toBe(821_600);
      expect(parsed.data['parent_city']).toBe('8f283080dcb019d');
    });
  });

  describe('object_deploy (0x20)', () => {
    it('extracts object deploy data', () => {
      const payload = {
        object_type: 'agent',
        location: '891f1d48177ffff',
        owner_pubkey: 'owner_key',
        stake_amount: 10_000_000,
        content_hash: 'ipfs_hash_abc',
        parent_territory: 'parent_hex',
        capabilities: ['chat', 'trade'],
      };

      const parsed = parseScript(buildLocusScript(0x20, payload))!;

      expect(parsed.typeName).toBe('object_deploy');
      expect(parsed.data['object_type']).toBe('agent');
      expect(parsed.data['stake_amount']).toBe(10_000_000);
      expect(parsed.data['capabilities']).toEqual(['chat', 'trade']);
    });
  });

  describe('heartbeat (0x30)', () => {
    it('extracts heartbeat data', () => {
      const payload = {
        heartbeat_type: 2,
        entity_id: 'citizen_pubkey',
        location: '891f1d48177ffff',
        timestamp: 1700000000,
        nonce: 42,
      };

      const parsed = parseScript(buildLocusScript(0x30, payload))!;

      expect(parsed.typeName).toBe('heartbeat');
      expect(parsed.data['heartbeat_type']).toBe(2);
      expect(parsed.data['timestamp']).toBe(1700000000);
      expect(parsed.data['nonce']).toBe(42);
    });
  });

  describe('gov_propose (0x50)', () => {
    it('extracts proposal data', () => {
      const payload = {
        proposal_type: 1,
        scope: 0,
        title: 'Change fee rate',
        description: 'Reduce protocol fee from 10% to 8%',
        actions: [{ type: 'parameter', target: 'protocol_fee', data: '0.08' }],
        deposit: 10_000_000,
        proposer_pubkey: 'proposer_key',
      };

      const parsed = parseScript(buildLocusScript(0x50, payload))!;

      expect(parsed.typeName).toBe('gov_propose');
      expect(parsed.data['title']).toBe('Change fee rate');
      expect(parsed.data['deposit']).toBe(10_000_000);
    });
  });

  describe('gov_vote (0x51)', () => {
    it('extracts vote data', () => {
      const payload = { proposal_id: 'proposal_txid', voter_pubkey: 'voter_key', vote: 1 };
      const parsed = parseScript(buildLocusScript(0x51, payload))!;

      expect(parsed.typeName).toBe('gov_vote');
      expect(parsed.data['vote']).toBe(1);
      expect(parsed.data['proposal_id']).toBe('proposal_txid');
    });
  });

  describe('ubi_claim (0x60)', () => {
    it('extracts UBI claim data', () => {
      const payload = { city_id: 'city_h3', citizen_pubkey: 'citizen_key', claim_periods: 7 };
      const parsed = parseScript(buildLocusScript(0x60, payload))!;

      expect(parsed.typeName).toBe('ubi_claim');
      expect(parsed.data['claim_periods']).toBe(7);
    });
  });

  describe('territory_transfer (0x12)', () => {
    it('extracts transfer data', () => {
      const payload = {
        territory_id: '891f1d48177ffff',
        from_pubkey: 'old_owner',
        new_owner_pubkey: 'new_owner',
      };
      const parsed = parseScript(buildLocusScript(0x12, payload))!;

      expect(parsed.typeName).toBe('territory_transfer');
      expect(parsed.data['new_owner_pubkey']).toBe('new_owner');
    });
  });

  describe('roundtrip data integrity', () => {
    it('preserves numeric precision', () => {
      const payload = { stake_amount: 6_400_000_000, lock_height: 821_600 };
      const parsed = parseScript(buildLocusScript(0x10, payload))!;
      expect(parsed.data['stake_amount']).toBe(6_400_000_000);
      expect(parsed.data['lock_height']).toBe(821_600);
    });

    it('preserves nested objects', () => {
      const payload = {
        name: 'Test',
        location: { lat: 35.6762, lng: 139.6503, h3_res7: 'abc123' },
        policies: { immigration_policy: 'open' },
      };
      const parsed = parseScript(buildLocusScript(0x01, payload))!;
      expect((parsed.data['location'] as any)['lat']).toBeCloseTo(35.6762);
      expect((parsed.data['policies'] as any)['immigration_policy']).toBe('open');
    });

    it('preserves arrays', () => {
      const payload = { capabilities: ['fly', 'teleport', 'trade'] };
      const parsed = parseScript(buildLocusScript(0x20, payload))!;
      expect(parsed.data['capabilities']).toEqual(['fly', 'teleport', 'trade']);
    });
  });
});
