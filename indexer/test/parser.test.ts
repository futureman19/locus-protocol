import { describe, it, expect } from 'vitest';
import { pack } from 'msgpackr';
import { parseScript, parseHexScript, parseTransactionOutputs } from '../src/scanner/parser';

function buildLocusScript(typeCode: number, payload: Record<string, unknown>): Buffer {
  const prefix = Buffer.from('LOCUS', 'utf8');
  const version = Buffer.from([0x01]);
  const type = Buffer.from([typeCode]);
  const msgpack = pack(payload);

  // OP_RETURN + pushdata length + content
  const content = Buffer.concat([prefix, version, type, msgpack]);
  const pushLen = content.length;

  // Simple pushdata encoding
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

describe('Parser', () => {
  describe('parseScript', () => {
    it('parses a city_found transaction', () => {
      const payload = { name: 'Neo-Tokyo', founder_pubkey: 'abc123' };
      const script = buildLocusScript(0x01, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.type).toBe(0x01);
      expect(result!.typeName).toBe('city_found');
      expect(result!.version).toBe(1);
      expect(result!.data['name']).toBe('Neo-Tokyo');
      expect(result!.data['founder_pubkey']).toBe('abc123');
    });

    it('parses a territory_claim transaction', () => {
      const payload = { level: 8, location: '891f1d48177ffff', stake_amount: 800_000_000 };
      const script = buildLocusScript(0x10, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.type).toBe(0x10);
      expect(result!.typeName).toBe('territory_claim');
      expect(result!.data['level']).toBe(8);
      expect(result!.data['stake_amount']).toBe(800_000_000);
    });

    it('parses a citizen_join transaction', () => {
      const payload = { city_id: 'h3abc', citizen_pubkey: 'pubkey123' };
      const script = buildLocusScript(0x03, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.type).toBe(0x03);
      expect(result!.typeName).toBe('citizen_join');
    });

    it('parses a gov_vote transaction', () => {
      const payload = { proposal_id: 'txid_abc', voter_pubkey: 'voter', vote: 1 };
      const script = buildLocusScript(0x51, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('gov_vote');
      expect(result!.data['vote']).toBe(1);
    });

    it('parses a heartbeat transaction', () => {
      const payload = { heartbeat_type: 2, entity_id: 'citizen_key', timestamp: 1700000000, nonce: 42 };
      const script = buildLocusScript(0x30, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('heartbeat');
      expect(result!.data['heartbeat_type']).toBe(2);
      expect(result!.data['nonce']).toBe(42);
    });

    it('parses an object_deploy transaction', () => {
      const payload = { object_type: 'agent', location: '891f1d48177ffff', stake_amount: 10_000_000 };
      const script = buildLocusScript(0x20, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('object_deploy');
      expect(result!.data['object_type']).toBe('agent');
    });

    it('parses a ubi_claim transaction', () => {
      const payload = { city_id: 'city1', citizen_pubkey: 'citizen1', claim_periods: 7 };
      const script = buildLocusScript(0x60, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('ubi_claim');
      expect(result!.data['claim_periods']).toBe(7);
    });

    it('parses a gov_propose transaction', () => {
      const payload = { proposal_type: 1, title: 'Change fees', deposit: 10_000_000 };
      const script = buildLocusScript(0x50, payload);

      const result = parseScript(script);
      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('gov_propose');
    });

    it('returns null for non-OP_RETURN data', () => {
      const result = parseScript(Buffer.from([0x00, 0x01, 0x02]));
      expect(result).toBeNull();
    });

    it('returns null for non-LOCUS OP_RETURN', () => {
      const script = Buffer.from([0x6a, 0x05, 0x48, 0x45, 0x4c, 0x4c, 0x4f]);
      const result = parseScript(script);
      expect(result).toBeNull();
    });

    it('returns null for wrong version', () => {
      const prefix = Buffer.from('LOCUS', 'utf8');
      const script = Buffer.concat([Buffer.from([0x6a, prefix.length + 3]), prefix, Buffer.from([0x02, 0x01]), pack({})]);
      const result = parseScript(script);
      expect(result).toBeNull();
    });

    it('returns null for unknown type code', () => {
      const prefix = Buffer.from('LOCUS', 'utf8');
      const script = Buffer.concat([Buffer.from([0x6a, prefix.length + 3]), prefix, Buffer.from([0x01, 0xFF]), pack({})]);
      const result = parseScript(script);
      expect(result).toBeNull();
    });

    it('returns null for empty buffer', () => {
      expect(parseScript(Buffer.alloc(0))).toBeNull();
    });

    it('returns null for too-short buffer', () => {
      expect(parseScript(Buffer.from([0x6a, 0x01, 0x02]))).toBeNull();
    });
  });

  describe('parseHexScript', () => {
    it('parses hex-encoded script', () => {
      const payload = { name: 'TestCity' };
      const script = buildLocusScript(0x01, payload);
      const hex = script.toString('hex');

      const result = parseHexScript(hex);
      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('city_found');
    });
  });

  describe('parseTransactionOutputs', () => {
    it('finds LOCUS output among multiple outputs', () => {
      const payload = { name: 'City1' };
      const locusScript = buildLocusScript(0x01, payload);
      const otherScript = Buffer.from([0x76, 0xa9, 0x14]); // random P2PKH

      const result = parseTransactionOutputs([
        otherScript.toString('hex'),
        locusScript.toString('hex'),
      ]);

      expect(result).not.toBeNull();
      expect(result!.typeName).toBe('city_found');
    });

    it('returns null when no LOCUS output exists', () => {
      const result = parseTransactionOutputs([
        Buffer.from([0x76, 0xa9]).toString('hex'),
      ]);
      expect(result).toBeNull();
    });
  });

  describe('all 17 type codes', () => {
    const typeCodes: [number, string][] = [
      [0x01, 'city_found'],
      [0x02, 'city_update'],
      [0x03, 'citizen_join'],
      [0x04, 'citizen_leave'],
      [0x10, 'territory_claim'],
      [0x11, 'territory_release'],
      [0x12, 'territory_transfer'],
      [0x20, 'object_deploy'],
      [0x21, 'object_update'],
      [0x22, 'object_destroy'],
      [0x30, 'heartbeat'],
      [0x40, 'ghost_invoke'],
      [0x41, 'ghost_payment'],
      [0x50, 'gov_propose'],
      [0x51, 'gov_vote'],
      [0x52, 'gov_exec'],
      [0x60, 'ubi_claim'],
    ];

    for (const [code, name] of typeCodes) {
      it(`recognizes 0x${code.toString(16).padStart(2, '0')} as ${name}`, () => {
        const script = buildLocusScript(code, { test: true });
        const result = parseScript(script);
        expect(result).not.toBeNull();
        expect(result!.type).toBe(code);
        expect(result!.typeName).toBe(name);
      });
    }
  });
});
