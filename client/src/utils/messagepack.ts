/**
 * MessagePack encoding/decoding wrapper.
 *
 * All Locus protocol payloads use MessagePack per spec 07-transaction-formats.md.
 */

import { pack, unpack } from 'msgpackr';

/** Encodes a value to MessagePack binary. */
export function encode(data: unknown): Buffer {
  return pack(data);
}

/** Decodes MessagePack binary to a value. */
export function decode(buffer: Buffer | Uint8Array): unknown {
  return unpack(Buffer.from(buffer));
}
