const { createTaskRepository } = require("../src/repositories/tasks");
const { buildPoolOptions } = require("../src/db");

describe("Postgres task repository", () => {
  it("creates tasks table on initSchema", async () => {
    const pool = { query: jest.fn().mockResolvedValue({ rows: [] }) };
    const repo = createTaskRepository(pool);

    await repo.initSchema();

    expect(pool.query).toHaveBeenCalledTimes(1);
    expect(pool.query.mock.calls[0][0]).toMatch(
      /CREATE TABLE IF NOT EXISTS tasks/i,
    );
  });

  it("findAll returns ordered tasks", async () => {
    const sample = [{ id: 1, title: "A", done: false, created_at: "t" }];
    const pool = { query: jest.fn().mockResolvedValue({ rows: sample }) };
    const repo = createTaskRepository(pool);

    const rows = await repo.findAll();

    expect(rows).toEqual(sample);
    expect(pool.query).toHaveBeenCalledWith(
      "SELECT id, title, done, created_at FROM tasks ORDER BY id ASC",
    );
  });

  it("create inserts parameterized title and returns row", async () => {
    const created = { id: 1, title: "New task", done: false, created_at: "t" };
    const pool = { query: jest.fn().mockResolvedValue({ rows: [created] }) };
    const repo = createTaskRepository(pool);

    const row = await repo.create({ title: "New task" });

    expect(row).toEqual(created);
    expect(pool.query).toHaveBeenCalledWith(
      "INSERT INTO tasks (title) VALUES ($1) RETURNING id, title, done, created_at",
      ["New task"],
    );
  });

  it("update modifies provided fields with parameterized SQL and returns null if missing", async () => {
    const updated = { id: 3, title: "Edited", done: true, created_at: "t" };
    const pool = {
      query: jest
        .fn()
        .mockResolvedValueOnce({ rows: [updated] })
        .mockResolvedValueOnce({ rows: [] }),
    };
    const repo = createTaskRepository(pool);

    const first = await repo.update(3, { title: "Edited", done: true });
    expect(first).toEqual(updated);
    expect(pool.query).toHaveBeenNthCalledWith(
      1,
      "UPDATE tasks SET title = $1, done = $2 WHERE id = $3 RETURNING id, title, done, created_at",
      ["Edited", true, 3],
    );

    const second = await repo.update(99, { done: false });
    expect(second).toBeNull();
    expect(pool.query).toHaveBeenNthCalledWith(
      2,
      "UPDATE tasks SET done = $1 WHERE id = $2 RETURNING id, title, done, created_at",
      [false, 99],
    );
  });

  it("remove returns true when deleted and false otherwise", async () => {
    const pool = {
      query: jest
        .fn()
        .mockResolvedValueOnce({ rowCount: 1 })
        .mockResolvedValueOnce({ rowCount: 0 }),
    };
    const repo = createTaskRepository(pool);

    expect(await repo.remove(1)).toBe(true);
    expect(await repo.remove(999)).toBe(false);
    expect(pool.query).toHaveBeenCalledWith(
      "DELETE FROM tasks WHERE id = $1 RETURNING id",
      [1],
    );
  });
});

describe("buildPoolOptions", () => {
  it("disables SSL for local Compose/localhost hosts", () => {
    const opts = buildPoolOptions({
      host: "db",
      port: 5432,
      database: "taskflow",
      user: "taskflow",
      password: "secret",
    });

    expect(opts.ssl).toBe(false);
    expect(opts.host).toBe("db");
  });

  it("enables verified TLS with AWS RDS CA bundle for RDS endpoints", () => {
    const opts = buildPoolOptions({
      host: "taskflow-db.cip0s8u8q9ts.us-east-1.rds.amazonaws.com",
      port: 5432,
      database: "taskflow",
      user: "taskflow",
      password: "secret",
    });

    expect(opts.ssl).toMatchObject({
      rejectUnauthorized: true,
      ca: expect.any(Array),
    });
    expect(opts.ssl.ca.length).toBeGreaterThan(0);
  });
});
