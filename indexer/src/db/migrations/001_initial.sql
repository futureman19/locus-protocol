-- Locus Protocol Indexer — Initial Schema
-- Requires PostGIS extension for spatial queries

CREATE EXTENSION IF NOT EXISTS postgis;

-- Indexer sync state
CREATE TABLE sync_state (
  id INTEGER PRIMARY KEY DEFAULT 1,
  last_block_height INTEGER NOT NULL DEFAULT 0,
  last_block_hash TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO sync_state (id) VALUES (1);

-- All indexed LOCUS transactions
CREATE TABLE transactions (
  txid TEXT PRIMARY KEY,
  message_type SMALLINT NOT NULL,
  message_type_name TEXT NOT NULL,
  block_height INTEGER NOT NULL,
  block_hash TEXT,
  block_time TIMESTAMPTZ,
  payload JSONB NOT NULL DEFAULT '{}',
  indexed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cities (/32 territories)
CREATE TABLE cities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  geom GEOMETRY(Point, 4326),
  h3_index TEXT NOT NULL,
  founder_pubkey TEXT NOT NULL,
  founded_block INTEGER NOT NULL,
  founded_txid TEXT NOT NULL REFERENCES transactions(txid),
  phase TEXT NOT NULL DEFAULT 'genesis',
  citizen_count INTEGER NOT NULL DEFAULT 1,
  unlocked_blocks INTEGER NOT NULL DEFAULT 2,
  governance_type TEXT NOT NULL DEFAULT 'founder',
  treasury_sats BIGINT NOT NULL DEFAULT 0,
  token_supply INTEGER NOT NULL DEFAULT 3200000,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Citizens
CREATE TABLE citizens (
  pubkey TEXT NOT NULL,
  city_id TEXT NOT NULL REFERENCES cities(id),
  joined_block INTEGER NOT NULL,
  joined_txid TEXT NOT NULL REFERENCES transactions(txid),
  last_heartbeat TIMESTAMPTZ,
  territories_claimed INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  left_block INTEGER,
  left_txid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (pubkey, city_id)
);

-- Territories (all levels)
CREATE TABLE territories (
  id TEXT PRIMARY KEY,
  level SMALLINT NOT NULL,
  h3_index TEXT NOT NULL,
  owner_pubkey TEXT NOT NULL,
  stake_amount BIGINT NOT NULL,
  lock_height INTEGER NOT NULL,
  parent_city TEXT REFERENCES cities(id),
  claimed_block INTEGER NOT NULL,
  claimed_txid TEXT NOT NULL REFERENCES transactions(txid),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  released_block INTEGER,
  released_txid TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Objects (/1 level)
CREATE TABLE objects (
  id TEXT PRIMARY KEY,
  object_type TEXT NOT NULL,
  h3_index TEXT NOT NULL,
  owner_pubkey TEXT NOT NULL,
  stake_amount BIGINT NOT NULL,
  content_hash TEXT,
  manifest_hash TEXT,
  parent_territory TEXT,
  capabilities TEXT[],
  deployed_block INTEGER NOT NULL,
  deployed_txid TEXT NOT NULL REFERENCES transactions(txid),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  destroyed_block INTEGER,
  destroyed_txid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Governance proposals
CREATE TABLE proposals (
  id TEXT PRIMARY KEY,
  proposal_type TEXT NOT NULL,
  scope SMALLINT NOT NULL DEFAULT 0,
  title TEXT NOT NULL,
  description TEXT,
  actions JSONB,
  deposit BIGINT NOT NULL,
  proposer_pubkey TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  votes_for INTEGER NOT NULL DEFAULT 0,
  votes_against INTEGER NOT NULL DEFAULT 0,
  votes_abstain INTEGER NOT NULL DEFAULT 0,
  created_block INTEGER NOT NULL,
  created_txid TEXT NOT NULL REFERENCES transactions(txid),
  voting_ends_block INTEGER NOT NULL,
  execution_txid TEXT,
  city_id TEXT REFERENCES cities(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Votes on proposals
CREATE TABLE votes (
  proposal_id TEXT NOT NULL REFERENCES proposals(id),
  voter_pubkey TEXT NOT NULL,
  vote SMALLINT NOT NULL,
  block_height INTEGER NOT NULL,
  txid TEXT NOT NULL REFERENCES transactions(txid),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (proposal_id, voter_pubkey)
);

-- Heartbeats
CREATE TABLE heartbeats (
  id SERIAL PRIMARY KEY,
  heartbeat_type SMALLINT NOT NULL,
  entity_id TEXT NOT NULL,
  entity_type SMALLINT,
  h3_index TEXT NOT NULL,
  timestamp_unix INTEGER NOT NULL,
  nonce INTEGER NOT NULL,
  block_height INTEGER NOT NULL,
  txid TEXT NOT NULL REFERENCES transactions(txid),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (entity_id, nonce)
);

-- UBI claims
CREATE TABLE ubi_claims (
  id SERIAL PRIMARY KEY,
  city_id TEXT NOT NULL REFERENCES cities(id),
  citizen_pubkey TEXT NOT NULL,
  claim_periods INTEGER NOT NULL,
  amount_sats BIGINT NOT NULL,
  block_height INTEGER NOT NULL,
  txid TEXT NOT NULL REFERENCES transactions(txid),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_cities_geom ON cities USING gist (geom);
CREATE INDEX idx_cities_h3 ON cities (h3_index);
CREATE INDEX idx_cities_phase ON cities (phase);

CREATE INDEX idx_citizens_city ON citizens (city_id) WHERE is_active = TRUE;
CREATE INDEX idx_citizens_pubkey ON citizens (pubkey);

CREATE INDEX idx_territories_h3 ON territories (h3_index);
CREATE INDEX idx_territories_owner ON territories (owner_pubkey) WHERE is_active = TRUE;
CREATE INDEX idx_territories_city ON territories (parent_city) WHERE is_active = TRUE;
CREATE INDEX idx_territories_level ON territories (level) WHERE is_active = TRUE;

CREATE INDEX idx_objects_h3 ON objects (h3_index) WHERE is_active = TRUE;
CREATE INDEX idx_objects_owner ON objects (owner_pubkey) WHERE is_active = TRUE;
CREATE INDEX idx_objects_parent ON objects (parent_territory) WHERE is_active = TRUE;
CREATE INDEX idx_objects_type ON objects (object_type) WHERE is_active = TRUE;

CREATE INDEX idx_proposals_city ON proposals (city_id);
CREATE INDEX idx_proposals_status ON proposals (status);

CREATE INDEX idx_heartbeats_entity ON heartbeats (entity_id);

CREATE INDEX idx_transactions_type ON transactions (message_type);
CREATE INDEX idx_transactions_block ON transactions (block_height);

CREATE INDEX idx_ubi_claims_city ON ubi_claims (city_id);
CREATE INDEX idx_ubi_claims_citizen ON ubi_claims (citizen_pubkey);
