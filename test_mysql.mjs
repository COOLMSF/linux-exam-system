import { config } from 'dotenv';
import { createConnection } from 'mysql2/promise';
import { readFileSync } from 'fs';

// Parse .env file manually
const envContent = readFileSync('.env', 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const match = line.match(/^([A-Z_]+)=(.*)$/i);
  if (match) {
    envVars[match[1]] = match[2];
  }
});

const connectionString = envVars.DATABASE_URL;
console.log('DATABASE_URL:', connectionString);

async function test() {
  try {
    const connection = await createConnection(connectionString);
    await connection.query('SELECT 1 as test');
    console.log('Connection successful!');
    await connection.end();
  } catch (err) {
    console.error('Connection failed:', err.message);
  }
}

test();
