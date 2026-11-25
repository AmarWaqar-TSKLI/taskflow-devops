const { listTasks, createTask, updateTask, deleteTask } = require("./api");
const { renderShell, renderTasks, setError } = require("./render");

async function mountApp(root) {
  const { form, input, errorBox, list } = renderShell(root);
  let tasks = [];

  const draw = () =>
    renderTasks(list, tasks, {
      onToggle: async (task) => {
        try {
          setError(errorBox, "");
          const updated = await updateTask(task.id, { done: !task.done });
          tasks = tasks.map((t) => (t.id === task.id ? updated : t));
          draw();
        } catch (err) {
          setError(errorBox, err.message);
          draw();
        }
      },
      onDelete: async (task) => {
        try {
          setError(errorBox, "");
          await deleteTask(task.id);
          tasks = tasks.filter((t) => t.id !== task.id);
          draw();
        } catch (err) {
          setError(errorBox, err.message);
        }
      },
    });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const title = input.value.trim();
    if (!title) {
      setError(errorBox, "Please enter a task title.");
      return;
    }
    try {
      setError(errorBox, "");
      const created = await createTask(title);
      tasks = [...tasks, created];
      input.value = "";
      draw();
    } catch (err) {
      setError(errorBox, err.message);
    }
  });

  try {
    tasks = await listTasks();
    draw();
  } catch (err) {
    setError(errorBox, err.message);
  }
}

function init() {
  const root = document.getElementById("app");
  if (root) {
    mountApp(root);
  }
}

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}

module.exports = { init, mountApp };
