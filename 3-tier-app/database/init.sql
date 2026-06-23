CREATE TABLE IF NOT EXISTS tasks (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO tasks (title)
SELECT 'Verify persistent PostgreSQL storage on NFS'
WHERE NOT EXISTS (SELECT 1 FROM tasks WHERE title = 'Verify persistent PostgreSQL storage on NFS');
