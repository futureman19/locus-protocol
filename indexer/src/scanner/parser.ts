import { unpack } from 'msgpackr';

const PROTOCOL_PREFIX = 'LOCUS';
const PROTOCOL_VERSION = 0x01;
const OP_RETURN = 0x6a;

const TYPE_NAMES: Record<number, string> = {
  0x01: 'city_found',
  0x02: 'city_update',
  0x03: 'citizen_join',
  0x04: 'citizen_leave',
  0x10: 'territory_claim',
  0x11: 'territory_release',
  0x12: 'territory_transfer',
  0x20: 'object_deploy',
  0x21: 'object_update',
  0x22: 'object_destroy',
  0x30: 'heartbeat',
  0x40: 'ghost_invoke',
  0x41: 'ghost_payment',
  0x50: 'gov_propose',
  0x51: 'gov_vote',
  0x52: 'gov_exec',
  0x60: 'ubi_claim',
};

export interface ParsedTransaction {
  type: number;
  typeName: string;
  version: number;
  data: Record<string, unknown>;
}

/**
 * Parse OP_RETURN script bytes into a LOCUS transaction.
 * Wire format: OP_RETURN <pushdata> "LOCUS" <version:1> <type:1> <msgpack>
 */
export function parseScript(script: Buffer): ParsedTransaction | null {
  if (!script || script.length < 10) return null;

  let offset = 0;

  // OP_RETURN
  if (script[offset] !== OP_RETURN) return null;
  offset++;

  // Skip pushdata opcode(s) to find "LOCUS" prefix
  const prefixIndex = findPrefix(script, offset);
  if (prefixIndex < 0) return null;
  offset = prefixIndex + PROTOCOL_PREFIX.length;

  // Version byte
  if (offset >= script.length) return null;
  const version = script[offset];
  if (version !== PROTOCOL_VERSION) return null;
  offset++;

  // Type byte
  if (offset >= script.length) return null;
  const typeCode = script[offset];
  const typeName = TYPE_NAMES[typeCode];
  if (!typeName) return null;
  offset++;

  // MessagePack payload (rest of the buffer)
  if (offset >= script.length) return null;
  const payloadBuf = script.subarray(offset);

  let data: Record<string, unknown>;
  try {
    data = unpack(payloadBuf) as Record<string, unknown>;
  } catch {
    return null;
  }

  return { type: typeCode, typeName, version, data };
}

/**
 * Parse a hex-encoded output script.
 */
export function parseHexScript(hex: string): ParsedTransaction | null {
  return parseScript(Buffer.from(hex, 'hex'));
}

/**
 * Scan all transaction outputs for a LOCUS OP_RETURN.
 * JungleBus provides outputs as an array of hex-encoded scripts.
 */
export function parseTransactionOutputs(outputScripts: string[]): ParsedTransaction | null {
  for (const hex of outputScripts) {
    const result = parseHexScript(hex);
    if (result) return result;
  }
  return null;
}

function findPrefix(buf: Buffer, startOffset: number): number {
  const prefixBytes = Buffer.from(PROTOCOL_PREFIX, 'utf8');
  for (let i = startOffset; i <= buf.length - prefixBytes.length; i++) {
    if (buf.subarray(i, i + prefixBytes.length).equals(prefixBytes)) {
      return i;
    }
  }
  return -1;
}
