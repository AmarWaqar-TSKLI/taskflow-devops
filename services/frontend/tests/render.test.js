const { renderShell } = require("../src/render");

describe("TaskFlow frontend shell", () => {
  it("renders the TaskFlow heading and task container", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const root = document.getElementById("app");

    renderShell(root);

    expect(root.querySelector("h1").textContent).toBe("TaskFlow");
    expect(root.querySelector("[data-testid='task-list']")).not.toBeNull();
  });
});
