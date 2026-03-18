require('dotenv').config();

const mysql = require('mysql2/promise');

const connectionString = process.env.DATABASE_URL;
console.log('DATABASE_URL:', connectionString);

async function test() {
  try {
    const connection = await mysql.createConnection(connectionString);
    await connection.query('SELECT 1 as test');
    console.log('Connection successful!');
    await connection.end();
  } catch (err) {
    console.error('Connection failed:', err.message);
  }
}

test();
