CREATE TABLE IF NOT EXISTS todos (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO todos (title)
SELECT 'Verify persistent PostgreSQL storage on NFS'
WHERE NOT EXISTS (SELECT 1 FROM todos WHERE title = 'Verify persistent PostgreSQL storage on NFS');
