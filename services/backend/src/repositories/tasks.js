const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS tasks (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)`;

function createTaskRepository(pool) {
  return {
    async initSchema() {
      await pool.query(SCHEMA_SQL);
    },

    async findAll() {
      const { rows } = await pool.query(
        "SELECT id, title, done, created_at FROM tasks ORDER BY id ASC",
      );
      return rows;
    },

    async create({ title }) {
      const { rows } = await pool.query(
        "INSERT INTO tasks (title) VALUES ($1) RETURNING id, title, done, created_at",
        [title],
      );
      return rows[0];
    },

    async update(id, fields) {
      const clauses = [];
      const values = [];
      let idx = 1;

      if (fields.title !== undefined) {
        clauses.push(`title = $${idx++}`);
        values.push(fields.title);
      }
      if (fields.done !== undefined) {
        clauses.push(`done = $${idx++}`);
        values.push(fields.done);
      }

      values.push(id);
      const { rows } = await pool.query(
        `UPDATE tasks SET ${clauses.join(", ")} WHERE id = $${idx} RETURNING id, title, done, created_at`,
        values,
      );
      return rows[0] || null;
    },

    async remove(id) {
      const { rowCount } = await pool.query(
        "DELETE FROM tasks WHERE id = $1 RETURNING id",
        [id],
      );
      return rowCount > 0;
    },
  };
}

module.exports = { createTaskRepository };
