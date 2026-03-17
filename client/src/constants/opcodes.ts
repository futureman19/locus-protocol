// Protocol identification per spec 07-transaction-formats.md
export const PROTOCOL_PREFIX = 'LOCUS';
export const PROTOCOL_PREFIX_HEX = '4c4f435553';
export const PROTOCOL_VERSION = 0x01;

// OP codes
export const OP_RETURN = 0x6a;
export const OP_PUSHDATA1 = 0x4c;
export const OP_PUSHDATA2 = 0x4d;

// Message type codes per spec 07-transaction-formats.md
export const TYPE_CODES = {
  city_found: 0x01,
  city_update: 0x02,
  citizen_join: 0x03,
  citizen_leave: 0x04,
  territory_claim: 0x10,
  territory_release: 0x11,
  territory_transfer: 0x12,
  object_deploy: 0x20,
  object_update: 0x21,
  object_destroy: 0x22,
  heartbeat: 0x30,
  ghost_invoke: 0x40,
  ghost_payment: 0x41,
  gov_propose: 0x50,
  gov_vote: 0x51,
  gov_exec: 0x52,
  ubi_claim: 0x60,
} as const;

// Reverse lookup: code → name
export const REVERSE_CODES: Record<number, string> = Object.fromEntries(
  Object.entries(TYPE_CODES).map(([name, code]) => [code, name])
);

// Proposal type codes per spec 07-transaction-formats.md
export const PROPOSAL_TYPE_CODES = {
  parameter_change: 0x01,
  contract_upgrade: 0x02,
  treasury_spend: 0x03,
  constitutional: 0x04,
  emergency: 0x05,
} as const;

// Vote value codes per spec 07-transaction-formats.md
export const VOTE_CODES = {
  no: 0,
  yes: 1,
  abstain: 2,
} as const;

// Dust limit
export const DUST_LIMIT = 546;

// Default fee rate (satoshis per byte)
export const DEFAULT_FEE_RATE = 0.5;
