const request = require("supertest");
const { createApp } = require("../src/app");

function createMockRepo(initial = []) {
  let nextId = initial.length + 1;
  const rows = initial.map((t) => ({ ...t }));

  return {
    findAll: jest.fn(async () => rows.map((t) => ({ ...t }))),
    create: jest.fn(async ({ title }) => {
      const created = {
        id: nextId++,
        title,
        done: false,
        created_at: "2026-11-25T17:00:00.000Z",
      };
      rows.push(created);
      return { ...created };
    }),
    update: jest.fn(async (id, fields) => {
      const idx = rows.findIndex((t) => t.id === id);
      if (idx === -1) return null;
      rows[idx] = { ...rows[idx], ...fields };
      return { ...rows[idx] };
    }),
    remove: jest.fn(async (id) => {
      const idx = rows.findIndex((t) => t.id === id);
      if (idx === -1) return false;
      rows.splice(idx, 1);
      return true;
    }),
  };
}

describe("Tasks CRUD API (/api/tasks)", () => {
  describe("GET /api/tasks", () => {
    it("returns list of tasks from repository", async () => {
      const repo = createMockRepo([
        {
          id: 1,
          title: "Write tests first",
          done: false,
          created_at: "2026-11-25T17:00:00.000Z",
        },
      ]);
      const app = createApp({ taskRepository: repo });

      const res = await request(app).get("/api/tasks");

      expect(res.status).toBe(200);
      expect(res.body).toEqual([
        {
          id: 1,
          title: "Write tests first",
          done: false,
          created_at: "2026-11-25T17:00:00.000Z",
        },
      ]);
      expect(repo.findAll).toHaveBeenCalledTimes(1);
    });
  });

  describe("POST /api/tasks", () => {
    it("creates a trimmed task and returns 201", async () => {
      const repo = createMockRepo();
      const app = createApp({ taskRepository: repo });

      const res = await request(app)
        .post("/api/tasks")
        .send({ title: "  Deploy to ECS/EC2  " });

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        id: 1,
        title: "Deploy to ECS/EC2",
        done: false,
      });
      expect(repo.create).toHaveBeenCalledWith({ title: "Deploy to ECS/EC2" });
    });

    it("returns 400 when title is missing, blank, non-string, or > 200 chars", async () => {
      const repo = createMockRepo();
      const app = createApp({ taskRepository: repo });

      for (const body of [
        {},
        { title: "" },
        { title: "   " },
        { title: 123 },
        { title: "a".repeat(201) },
      ]) {
        const res = await request(app).post("/api/tasks").send(body);
        expect(res.status).toBe(400);
        expect(res.body).toEqual({ error: expect.any(String) });
      }
      expect(repo.create).not.toHaveBeenCalled();
    });

    it("returns 400 on malformed JSON body", async () => {
      const repo = createMockRepo();
      const app = createApp({ taskRepository: repo });

      const res = await request(app)
        .post("/api/tasks")
        .set("Content-Type", "application/json")
        .send("{bad json");

      expect(res.status).toBe(400);
      expect(res.body).toEqual({ error: expect.any(String) });
    });
  });

  describe("PATCH /api/tasks/:id", () => {
    it("updates title and/or done status and returns 200", async () => {
      const repo = createMockRepo([
        {
          id: 1,
          title: "Initial",
          done: false,
          created_at: "2026-11-25T17:00:00.000Z",
        },
      ]);
      const app = createApp({ taskRepository: repo });

      const res1 = await request(app)
        .patch("/api/tasks/1")
        .send({ done: true });
      expect(res1.status).toBe(200);
      expect(res1.body.done).toBe(true);

      const res2 = await request(app)
        .patch("/api/tasks/1")
        .send({ title: "  Updated  ", done: false });
      expect(res2.status).toBe(200);
      expect(res2.body).toMatchObject({ title: "Updated", done: false });
    });

    it("returns 404 when task does not exist", async () => {
      const repo = createMockRepo();
      const app = createApp({ taskRepository: repo });

      const res = await request(app)
        .patch("/api/tasks/999")
        .send({ done: true });

      expect(res.status).toBe(404);
      expect(res.body).toEqual({ error: expect.any(String) });
    });

    it("returns 400 for invalid id, empty update, invalid title, or non-boolean done", async () => {
      const repo = createMockRepo([
        { id: 1, title: "Initial", done: false, created_at: "now" },
      ]);
      const app = createApp({ taskRepository: repo });

      const badCases = [
        ["abc", { done: true }],
        ["0", { done: true }],
        ["1", {}],
        ["1", { title: "   " }],
        ["1", { title: "x".repeat(201) }],
        ["1", { done: "yes" }],
      ];

      for (const [id, payload] of badCases) {
        const res = await request(app).patch(`/api/tasks/${id}`).send(payload);
        expect(res.status).toBe(400);
        expect(res.body).toEqual({ error: expect.any(String) });
      }
    });
  });

  describe("DELETE /api/tasks/:id", () => {
    it("deletes existing task and returns 204", async () => {
      const repo = createMockRepo([
        { id: 1, title: "Delete me", done: false, created_at: "now" },
      ]);
      const app = createApp({ taskRepository: repo });

      const res = await request(app).delete("/api/tasks/1");

      expect(res.status).toBe(204);
      expect(repo.remove).toHaveBeenCalledWith(1);
    });

    it("returns 404 when task does not exist", async () => {
      const repo = createMockRepo();
      const app = createApp({ taskRepository: repo });

      const res = await request(app).delete("/api/tasks/42");

      expect(res.status).toBe(404);
      expect(res.body).toEqual({ error: expect.any(String) });
    });

    it("returns 400 for invalid id", async () => {
      const repo = createMockRepo();
      const app = createApp({ taskRepository: repo });

      const res = await request(app).delete("/api/tasks/not-a-number");

      expect(res.status).toBe(400);
      expect(res.body).toEqual({ error: expect.any(String) });
    });
  });
});
