const { renderShell, renderTasks, setError } = require("../src/render");

describe("TaskFlow frontend rendering", () => {
  it("renders shell with heading, create form, error slot, and task list", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const root = document.getElementById("app");

    const els = renderShell(root);

    expect(root.querySelector("h1").textContent).toBe("TaskFlow");
    expect(els.form).not.toBeNull();
    expect(els.input).not.toBeNull();
    expect(els.list).toBe(root.querySelector("[data-testid='task-list']"));
  });

  it("renders empty state when there are no tasks", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const { list } = renderShell(document.getElementById("app"));

    renderTasks(list, [], { onToggle: jest.fn(), onDelete: jest.fn() });

    expect(list.textContent).toMatch(/no tasks yet/i);
  });

  it("safely renders task titles and fires toggle and delete callbacks", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const { list } = renderShell(document.getElementById("app"));
    const onToggle = jest.fn();
    const onDelete = jest.fn();

    renderTasks(
      list,
      [
        { id: 1, title: "<script>alert(1)</script>", done: false },
        { id: 2, title: "Completed item", done: true },
      ],
      { onToggle, onDelete },
    );

    const items = list.querySelectorAll("li");
    expect(items).toHaveLength(2);
    expect(list.querySelector("script")).toBeNull();
    expect(items[0].textContent).toContain("<script>alert(1)</script>");

    const checkboxes = list.querySelectorAll("input[type='checkbox']");
    expect(checkboxes[0].checked).toBe(false);
    expect(checkboxes[1].checked).toBe(true);

    checkboxes[0].click();
    expect(onToggle).toHaveBeenCalledWith({
      id: 1,
      title: "<script>alert(1)</script>",
      done: false,
    });

    const deleteButtons = list.querySelectorAll("button[data-action='delete']");
    deleteButtons[1].click();
    expect(onDelete).toHaveBeenCalledWith({
      id: 2,
      title: "Completed item",
      done: true,
    });
  });

  it("shows and clears error messages", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const { errorBox } = renderShell(document.getElementById("app"));

    setError(errorBox, "Could not save task");
    expect(errorBox.textContent).toBe("Could not save task");
    expect(errorBox.hidden).toBe(false);

    setError(errorBox, "");
    expect(errorBox.hidden).toBe(true);
  });
});
