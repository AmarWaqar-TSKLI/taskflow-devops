function renderShell(root) {
  root.replaceChildren();

  const header = document.createElement("header");
  const title = document.createElement("h1");
  title.textContent = "TaskFlow";

  const subtitle = document.createElement("p");
  subtitle.className = "subtitle";
  subtitle.textContent = "Simple task tracker";
  header.append(title, subtitle);

  const form = document.createElement("form");
  form.className = "task-form";

  const input = document.createElement("input");
  input.type = "text";
  input.name = "title";
  input.maxLength = 200;
  input.placeholder = "Add a task (1-200 chars)...";
  input.setAttribute("aria-label", "Task title");

  const submitBtn = document.createElement("button");
  submitBtn.type = "submit";
  submitBtn.textContent = "Add";
  form.append(input, submitBtn);

  const errorBox = document.createElement("p");
  errorBox.className = "error-banner";
  errorBox.setAttribute("role", "alert");
  errorBox.hidden = true;

  const list = document.createElement("ul");
  list.className = "task-list";
  list.setAttribute("data-testid", "task-list");

  root.append(header, form, errorBox, list);
  return { form, input, errorBox, list };
}

function setError(errorBox, message) {
  if (message) {
    errorBox.textContent = message;
    errorBox.hidden = false;
  } else {
    errorBox.textContent = "";
    errorBox.hidden = true;
  }
}

function renderTasks(list, tasks, handlers) {
  list.replaceChildren();

  if (tasks.length === 0) {
    const empty = document.createElement("li");
    empty.className = "empty-state";
    empty.textContent = "No tasks yet. Add one above.";
    list.append(empty);
    return;
  }

  for (const task of tasks) {
    const item = document.createElement("li");
    item.className = task.done ? "task-item is-done" : "task-item";

    const label = document.createElement("label");
    label.className = "task-label";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = Boolean(task.done);
    checkbox.addEventListener("change", () => handlers.onToggle(task));

    const span = document.createElement("span");
    span.className = "task-title";
    span.textContent = task.title;
    label.append(checkbox, span);

    const deleteBtn = document.createElement("button");
    deleteBtn.type = "button";
    deleteBtn.className = "delete-btn";
    deleteBtn.setAttribute("data-action", "delete");
    deleteBtn.textContent = "Delete";
    deleteBtn.addEventListener("click", () => handlers.onDelete(task));

    item.append(label, deleteBtn);
    list.append(item);
  }
}

module.exports = { renderShell, renderTasks, setError };
