import { describe, it, expect } from 'vitest';
import { TransactionBuilder } from '../src/modules/transaction-builder';
import { PROTOCOL_PREFIX, PROTOCOL_VERSION, TYPE_CODES } from '../src/constants/opcodes';

describe('TransactionBuilder', () => {
  describe('encode/decode roundtrip', () => {
    it('round-trips a city_found message', () => {
      const payload = { name: 'Neo-Tokyo', stake: 3_200_000_000 };
      const script = TransactionBuilder.encode('city_found', payload);

      expect(Buffer.isBuffer(script)).toBe(true);
      expect(script[0]).toBe(0x6a); // OP_RETURN

      const decoded = TransactionBuilder.decode(script);
      expect(decoded.type).toBe('city_found');
      expect(decoded.version).toBe(PROTOCOL_VERSION);
      expect(decoded.data['name']).toBe('Neo-Tokyo');
      expect(decoded.data['stake']).toBe(3_200_000_000);
    });

    it('round-trips a territory_claim message', () => {
      const payload = { level: 8, location: '891f1d48177ffff' };
      const script = TransactionBuilder.encode('territory_claim', payload);
      const decoded = TransactionBuilder.decode(script);

      expect(decoded.type).toBe('territory_claim');
      expect(decoded.data['level']).toBe(8);
    });

    it('round-trips a gov_vote message', () => {
      const payload = { proposal_id: 'abc123', vote: 1 };
      const script = TransactionBuilder.encode('gov_vote', payload);
      const decoded = TransactionBuilder.decode(script);

      expect(decoded.type).toBe('gov_vote');
      expect(decoded.data['vote']).toBe(1);
    });

    it('round-trips a ubi_claim message', () => {
      const payload = { city_id: 'city1', claim_periods: 7 };
      const script = TransactionBuilder.encode('ubi_claim', payload);
      const decoded = TransactionBuilder.decode(script);

      expect(decoded.type).toBe('ubi_claim');
      expect(decoded.data['claim_periods']).toBe(7);
    });
  });

  describe('encode errors', () => {
    it('rejects unknown type', () => {
      expect(() => {
        TransactionBuilder.encode('bogus' as any, {});
      }).toThrow('Unknown message type');
    });
  });

  describe('decode errors', () => {
    it('rejects non-OP_RETURN data', () => {
      expect(() => {
        TransactionBuilder.decode(Buffer.from([0x00, 0x01, 0x02]));
      }).toThrow();
    });
  });

  describe('type codes match spec 07', () => {
    it('has all 17 territory protocol types', () => {
      expect(Object.keys(TYPE_CODES).length).toBe(17);
    });

    it('city_found = 0x01', () => {
      expect(TYPE_CODES.city_found).toBe(0x01);
    });

    it('citizen_join = 0x03', () => {
      expect(TYPE_CODES.citizen_join).toBe(0x03);
    });

    it('territory_claim = 0x10', () => {
      expect(TYPE_CODES.territory_claim).toBe(0x10);
    });

    it('object_deploy = 0x20', () => {
      expect(TYPE_CODES.object_deploy).toBe(0x20);
    });

    it('heartbeat = 0x30', () => {
      expect(TYPE_CODES.heartbeat).toBe(0x30);
    });

    it('ghost_invoke = 0x40', () => {
      expect(TYPE_CODES.ghost_invoke).toBe(0x40);
    });

    it('gov_propose = 0x50', () => {
      expect(TYPE_CODES.gov_propose).toBe(0x50);
    });

    it('ubi_claim = 0x60', () => {
      expect(TYPE_CODES.ubi_claim).toBe(0x60);
    });
  });

  describe('payload builders', () => {
    it('buildCityFound', () => {
      const script = TransactionBuilder.buildCityFound({
        name: 'TestCity',
        description: 'A test city',
        lat: 35.6762,
        lng: 139.6503,
        h3Res7: '8f283080dcb019d',
        founderPubkey: 'pubkey_data',
      });

      const decoded = TransactionBuilder.decode(script);
      expect(decoded.data['name']).toBe('TestCity');
      expect((decoded.data['location'] as any)['h3_res7']).toBe('8f283080dcb019d');
    });

    it('buildTerritoryClaim', () => {
      const script = TransactionBuilder.buildTerritoryClaim({
        level: 8,
        h3Index: '891f1d48177ffff',
        ownerPubkey: 'owner_key',
        stakeAmount: 800_000_000,
        lockHeight: 821_600,
      });

      const decoded = TransactionBuilder.decode(script);
      expect(decoded.type).toBe('territory_claim');
      expect(decoded.data['stake_amount']).toBe(800_000_000);
    });

    it('buildGovVote', () => {
      const script = TransactionBuilder.buildGovVote('proposal_id', 'voter_key', 'yes');
      const decoded = TransactionBuilder.decode(script);
      expect(decoded.type).toBe('gov_vote');
      expect(decoded.data['vote']).toBe(1);
    });

    it('buildUBIClaim', () => {
      const script = TransactionBuilder.buildUBIClaim('city_id', 'citizen_key', 7);
      const decoded = TransactionBuilder.decode(script);
      expect(decoded.type).toBe('ubi_claim');
      expect(decoded.data['claim_periods']).toBe(7);
    });

    it('buildHeartbeat', () => {
      const script = TransactionBuilder.buildHeartbeat({
        heartbeatType: 2,
        entityId: 'citizen_pubkey',
        h3Index: '891f1d48177ffff',
      });

      const decoded = TransactionBuilder.decode(script);
      expect(decoded.type).toBe('heartbeat');
      expect(decoded.data['heartbeat_type']).toBe(2);
    });

    it('buildObjectDeploy', () => {
      const script = TransactionBuilder.buildObjectDeploy({
        objectType: 'agent',
        h3Index: '891f1d48177ffff',
        ownerPubkey: 'owner_key',
        stakeAmount: 10_000_000,
        contentHash: 'abc123',
        parentTerritory: 'parent_hex',
      });

      const decoded = TransactionBuilder.decode(script);
      expect(decoded.type).toBe('object_deploy');
      expect(decoded.data['object_type']).toBe('agent');
    });
  });
});
