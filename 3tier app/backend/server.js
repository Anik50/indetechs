const express = require('express');
const { Pool } = require('pg');

const PORT = Number(process.env.PORT || 8080);

const pool = new Pool({
  host: process.env.PGHOST || 'todo-database',
  port: Number(process.env.PGPORT || 5432),
  user: process.env.PGUSER || 'todoapp',
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE || 'tododb',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const app = express();
app.use(express.json({ limit: '32kb' }));

async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS todos (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      completed BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

app.get('/healthz', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/readyz', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not-ready', error: error.message });
  }
});

app.get('/api/todos', async (_req, res, next) => {
  try {
    const result = await pool.query(
      'SELECT id, title, completed, created_at FROM todos ORDER BY id DESC LIMIT 100'
    );
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

app.post('/api/todos', async (req, res, next) => {
  try {
    const title = String(req.body.title || '').trim();
    if (!title) {
      return res.status(400).json({ error: 'title is required' });
    }

    const result = await pool.query(
      'INSERT INTO todos (title) VALUES ($1) RETURNING id, title, completed, created_at',
      [title]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

app.patch('/api/todos/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const completed = Boolean(req.body.completed);

    const result = await pool.query(
      'UPDATE todos SET completed = $1 WHERE id = $2 RETURNING id, title, completed, created_at',
      [completed, id]
    );

    if (!result.rowCount) {
      return res.status(404).json({ error: 'todo not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

app.delete('/api/todos/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    await pool.query('DELETE FROM todos WHERE id = $1', [id]);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: 'internal server error' });
});

ensureSchema()
  .then(() => {
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`todo backend listening on ${PORT}`);
    });
  })
  .catch(error => {
    console.error('failed to initialize database schema', error);
    process.exit(1);
  });
