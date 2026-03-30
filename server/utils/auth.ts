/**
 * Hashes a password with a given salt
 * @param password The password to hash
 * @param salt The salt to use for hashing
 * @returns The hashed password
 */
import { createHash, randomBytes } from 'crypto';

export function hashPassword(password: string, salt: string): string {
  return createHash('sha256').update(salt + password + salt).digest('hex');
}

/**
 * Creates a password hash with a random salt
 * @param password The password to hash
 * @returns The hashed password with salt, in the format "salt:hash"
 */
export function makePasswordHash(password: string): string {
  const salt = randomBytes(16).toString('hex');
  return salt + ':' + hashPassword(password, salt);
}

/**
 * Verifies a password against a stored hash
 * @param password The password to verify
 * @param stored The stored hash in the format "salt:hash"
 * @returns True if the password is correct, false otherwise
 */
export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(':');
  if (!salt || !hash) return false;
  return hashPassword(password, salt) === hash;
}
