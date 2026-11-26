async function fetchHealth(fetchImpl) {
  const doFetch = fetchImpl || globalThis.fetch;
  const response = await doFetch("/api/health");
  if (!response.ok) {
    throw new Error(`Health check failed with status ${response.status}`);
  }
  return response.json();
}

async function requestJson(url, options, fetchImpl) {
  const doFetch = fetchImpl || globalThis.fetch;
  const response = options ? await doFetch(url, options) : await doFetch(url);
  if (!response.ok) {
    let message = `Request failed with status ${response.status}`;
    try {
      const data = await response.json();
      if (data && typeof data.error === "string" && data.error.length > 0) {
        message = data.error;
      }
    } catch {
      // Ignore non-JSON error bodies and keep fallback status message.
    }
    throw new Error(message);
  }
  if (response.status === 204) {
    return null;
  }
  return response.json();
}

function listTasks(fetchImpl) {
  return requestJson("/api/tasks", null, fetchImpl);
}

function createTask(title, fetchImpl) {
  return requestJson(
    "/api/tasks",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title }),
    },
    fetchImpl,
  );
}

function updateTask(id, patch, fetchImpl) {
  return requestJson(
    `/api/tasks/${id}`,
    {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(patch),
    },
    fetchImpl,
  );
}

function deleteTask(id, fetchImpl) {
  return requestJson(`/api/tasks/${id}`, { method: "DELETE" }, fetchImpl);
}

module.exports = {
  fetchHealth,
  listTasks,
  createTask,
  updateTask,
  deleteTask,
};
