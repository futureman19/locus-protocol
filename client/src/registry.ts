/**
 * Ghost registry for querying and indexing
 */

import {
  Ghost,
  LatLng,
  Network
} from './types';

import {
  GhostType,
  GHOST_TYPES
} from './constants';

/**
 * In-memory ghost registry
 * 
 * In production, this would query an overlay service
 * or scan the blockchain for ghost data.
 */
export class GhostRegistry {
  private ghosts: Map<string, Ghost> = new Map();
  private network: Network;

  constructor(network: Network) {
    this.network = network;
  }

  /**
   * Register a ghost in the local index
   */
  registerGhost(ghost: Ghost): void {
    this.ghosts.set(ghost.id, ghost);
  }

  /**
   * Get ghost by ID
   */
  async getGhost(ghostId: string): Promise<Ghost | null> {
    // First check local cache
    if (this.ghosts.has(ghostId)) {
      return this.ghosts.get(ghostId)!;
    }

    // In production, query overlay service
    // const ghost = await this.queryOverlay(ghostId);
    
    return null;
  }

  /**
   * Find ghosts by owner public key
   */
  async findByOwner(ownerPubKey: string): Promise<Ghost[]> {
    const results: Ghost[] = [];

    for (const ghost of this.ghosts.values()) {
      if (ghost.ownerPubKey === ownerPubKey) {
        results.push(ghost);
      }
    }

    return results;
  }

  /**
   * Find ghosts by location (within radius)
   */
  async findByLocation(
    location: LatLng,
    radiusMeters: number
  ): Promise<Ghost[]> {
    const results: Ghost[] = [];

    for (const ghost of this.ghosts.values()) {
      const distance = this.haversineDistance(
        location.lat,
        location.lng,
        ghost.location.lat,
        ghost.location.lng
      );

      if (distance <= radiusMeters) {
        results.push(ghost);
      }
    }

    // Sort by distance
    results.sort((a, b) => {
      const distA = this.haversineDistance(
        location.lat, location.lng,
        a.location.lat, a.location.lng
      );
      const distB = this.haversineDistance(
        location.lat, location.lng,
        b.location.lat, b.location.lng
      );
      return distA - distB;
    });

    return results;
  }

  /**
   * Find ghosts by type
   */
  async findByType(type: GhostType): Promise<Ghost[]> {
    return Array.from(this.ghosts.values())
      .filter(g => g.type === type);
  }

  /**
   * Find ghosts by state
   */
  async findByState(state: Ghost['state']): Promise<Ghost[]> {
    return Array.from(this.ghosts.values())
      .filter(g => g.state === state);
  }

  /**
   * List all ghosts
   */
  async listAll(): Promise<Ghost[]> {
    return Array.from(this.ghosts.values());
  }

  /**
   * Update ghost state
   */
  updateGhostState(
    ghostId: string,
    state: Ghost['state']
  ): Ghost | null {
    const ghost = this.ghosts.get(ghostId);
    if (!ghost) return null;

    const updated = { ...ghost, state };
    this.ghosts.set(ghostId, updated);
    return updated;
  }

  /**
   * Update ghost heartbeat
   */
  updateHeartbeat(
    ghostId: string,
    sequence: number
  ): Ghost | null {
    const ghost = this.ghosts.get(ghostId);
    if (!ghost) return null;

    const updated = {
      ...ghost,
      heartbeatSeq: sequence,
      lastHeartbeat: new Date()
    };
    this.ghosts.set(ghostId, updated);
    return updated;
  }

  // ==========================================================================
  // Private Methods
  // ==========================================================================

  /**
   * Calculate haversine distance between two points
   */
  private haversineDistance(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number
  ): number {
    const R = 6_371_000; // Earth's radius in meters
    const toRad = (deg: number) => (deg * Math.PI) / 180;

    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  /**
   * Query overlay service for ghost data
   * 
   * In production implementation, this would query:
   * - tm_locus_ghosts topic manager
   * - 1sat-indexer for origin tracking
   * - Local overlay node
   */
  private async queryOverlay(ghostId: string): Promise<Ghost | null> {
    // Placeholder for overlay query
    // const response = await fetch(`${this.overlayEndpoint}/ghost/${ghostId}`);
    // return response.json();
    
    return null;
  }
}
