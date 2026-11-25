const express = require("express");

function createTasksRouter(taskService) {
  const router = express.Router();

  router.get("/", async (_req, res) => {
    const tasks = await taskService.listTasks();
    res.status(200).json(tasks);
  });

  router.post("/", async (req, res) => {
    const task = await taskService.createTask(req.body);
    res.status(201).json(task);
  });

  router.patch("/:id", async (req, res) => {
    const task = await taskService.updateTask(req.params.id, req.body);
    res.status(200).json(task);
  });

  router.delete("/:id", async (req, res) => {
    await taskService.deleteTask(req.params.id);
    res.status(204).end();
  });

  return router;
}

module.exports = { createTasksRouter };
