export enum MessageType {
  CITY_FOUND = 0x01,
  CITY_UPDATE = 0x02,
  CITIZEN_JOIN = 0x03,
  CITIZEN_LEAVE = 0x04,
  TERRITORY_CLAIM = 0x10,
  TERRITORY_RELEASE = 0x11,
  TERRITORY_TRANSFER = 0x12,
  OBJECT_DEPLOY = 0x20,
  OBJECT_UPDATE = 0x21,
  OBJECT_DESTROY = 0x22,
  HEARTBEAT = 0x30,
  GHOST_INVOKE = 0x40,
  GHOST_PAYMENT = 0x41,
  GOV_PROPOSE = 0x50,
  GOV_VOTE = 0x51,
  GOV_EXEC = 0x52,
  UBI_CLAIM = 0x60,
}

export type MessageTypeName =
  | 'city_found'
  | 'city_update'
  | 'citizen_join'
  | 'citizen_leave'
  | 'territory_claim'
  | 'territory_release'
  | 'territory_transfer'
  | 'object_deploy'
  | 'object_update'
  | 'object_destroy'
  | 'heartbeat'
  | 'ghost_invoke'
  | 'ghost_payment'
  | 'gov_propose'
  | 'gov_vote'
  | 'gov_exec'
  | 'ubi_claim';

export interface DecodedTransaction {
  type: MessageTypeName;
  version: number;
  data: Record<string, unknown>;
}

export interface HeartbeatParams {
  heartbeatType: number;
  entityId: string;
  entityType?: number;
  h3Index: string;
  nonce?: number;
}
