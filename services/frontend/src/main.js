const { renderShell } = require("./render");

function init() {
  const root = document.getElementById("app");
  if (root) {
    renderShell(root);
  }
}

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}

module.exports = { init };
