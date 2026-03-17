/**
 * Cryptographic utilities for secure random number generation.
 * 
 * SECURITY: Never use Math.random() for cryptographic purposes.
 * Always use crypto.getRandomValues() for nonces, keys, etc.
 */

/**
 * Generate a cryptographically secure random 32-bit unsigned integer.
 * Uses crypto.getRandomValues() which provides CSPRNG (Cryptographically
 * Secure Pseudo-Random Number Generator).
 * 
 * SECURITY FIX: Replaces insecure Math.random() for nonce generation.
 * Math.random() is NOT cryptographically secure and can be predicted.
 * 
 * @returns A secure random integer between 0 and 0xffffffff
 */
export function secureRandomUint32(): number {
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    // Browser/Node.js modern environment
    const arr = new Uint32Array(1);
    crypto.getRandomValues(arr);
    return arr[0];
  } else if (typeof require !== 'undefined') {
    // Node.js fallback
    try {
      const nodeCrypto = require('crypto');
      return nodeCrypto.randomInt(0, 0xffffffff + 1);
    } catch {
      // Fallback for older Node.js
      const buf = nodeCrypto.randomBytes(4);
      return buf.readUInt32BE(0);
    }
  }
  
  // Last resort - throw error rather than use insecure RNG
  throw new Error(
    'SECURITY: No secure random number generator available. ' +
    'Cannot generate nonce without crypto.getRandomValues() or Node.js crypto module.'
  );
}

/**
 * Generate a cryptographically secure random hex string.
 * 
 * @param bytes Number of random bytes to generate
 * @returns Hex-encoded random string
 */
export function secureRandomHex(bytes: number): string {
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    const arr = new Uint8Array(bytes);
    crypto.getRandomValues(arr);
    return Array.from(arr)
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  } else if (typeof require !== 'undefined') {
    const nodeCrypto = require('crypto');
    return nodeCrypto.randomBytes(bytes).toString('hex');
  }
  
  throw new Error(
    'SECURITY: No secure random number generator available.'
  );
}

/**
 * Generate a cryptographically secure nonce for protocol transactions.
 * Default generates a 32-bit nonce (4 bytes).
 * 
 * @returns Secure random nonce as number
 */
export function generateNonce(): number {
  return secureRandomUint32();
}
