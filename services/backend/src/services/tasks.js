const { ValidationError, NotFoundError } = require("../errors");

const MAX_TITLE_LENGTH = 200;

function parseId(rawId) {
  const str = String(rawId);
  if (!/^[1-9]\d*$/.test(str)) {
    throw new ValidationError("invalid task id");
  }
  return Number(str);
}

function validateTitle(title) {
  if (typeof title !== "string") {
    throw new ValidationError("title must be a string");
  }
  const trimmed = title.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_TITLE_LENGTH) {
    throw new ValidationError(
      `title must be between 1 and ${MAX_TITLE_LENGTH} characters`,
    );
  }
  return trimmed;
}

function createTaskService(taskRepository) {
  return {
    async listTasks() {
      return taskRepository.findAll();
    },

    async createTask(payload) {
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        throw new ValidationError("request body must be a JSON object");
      }
      const title = validateTitle(payload.title);
      return taskRepository.create({ title });
    },

    async updateTask(rawId, payload) {
      const id = parseId(rawId);
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        throw new ValidationError("request body must be a JSON object");
      }

      const fields = {};
      if (payload.title !== undefined) {
        fields.title = validateTitle(payload.title);
      }
      if (payload.done !== undefined) {
        if (typeof payload.done !== "boolean") {
          throw new ValidationError("done must be a boolean");
        }
        fields.done = payload.done;
      }
      if (Object.keys(fields).length === 0) {
        throw new ValidationError("at least one of title or done is required");
      }

      const updated = await taskRepository.update(id, fields);
      if (!updated) {
        throw new NotFoundError("task not found");
      }
      return updated;
    },

    async deleteTask(rawId) {
      const id = parseId(rawId);
      const removed = await taskRepository.remove(id);
      if (!removed) {
        throw new NotFoundError("task not found");
      }
    },
  };
}

module.exports = { createTaskService, parseId, validateTitle };
