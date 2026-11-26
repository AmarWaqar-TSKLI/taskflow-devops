function renderShell(root) {
  root.replaceChildren();

  const header = document.createElement("header");
  const title = document.createElement("h1");
  title.textContent = "TaskFlow";

  const subtitle = document.createElement("p");
  subtitle.className = "subtitle";
  subtitle.textContent = "Simple task tracker";

  header.append(title, subtitle);

  const list = document.createElement("ul");
  list.className = "task-list";
  list.setAttribute("data-testid", "task-list");

  root.append(header, list);
  return { list };
}

module.exports = { renderShell };
