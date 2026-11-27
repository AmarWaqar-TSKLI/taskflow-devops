#!/usr/bin/env node
// Builds the submission PDF (M2-15) from what is already in the repo, so it can be rebuilt in a
// minute whenever a screenshot, the diagram or the report changes:
//   cover   <- docs/WORK.md team table + group number, repo + live links
//   part 1  <- docs/submission/architecture.png (M3-14)
//   part 2  <- docs/evidence/*.{png,jpg,jpeg} in the order of the brief's 10 screenshot groups
//   part 3  <- live link (README links table)
//   part 4  <- docs/submission/report.md
// Anything missing becomes a red MISSING box, so a draft can be printed at any time.
//
// Usage: node docs/submission/build-pdf.mjs [--check-links]
//   env GROUP=7        group number (default: WORK.md "Group number", else X) -> docs/submission/Group7.pdf
//   env CHROME=...     Chrome/Chromium binary (default: macOS Chrome, then google-chrome / chromium on PATH)
//   --check-links      also request every http(s) link in the PDF and print its status (F-10)
// Needs only Node 18+ and Chrome. The PDF is git-ignored (docs/submission/*.pdf): upload it, don't commit it.
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const read = (p) => readFileSync(join(root, p), "utf8");
const esc = (s) =>
  String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

// ---------- data from the repo ----------
const work = read("docs/WORK.md");
const groupFromDoc = (work.match(/Group number[^*]*\*\*\s*([0-9A-Za-z]+)\s*\*\*/) || [])[1];
const group = process.env.GROUP || (groupFromDoc && !/^_+$/.test(groupFromDoc) ? groupFromDoc : "X");
if (!/^[0-9A-Za-z-]{1,20}$/.test(group)) {
  console.error(`GROUP must be letters, digits or '-' (it becomes the file name), got '${group}'`);
  process.exit(2);
}

const teamSection = work.slice(work.indexOf("## Team"), work.indexOf("Group number"));
const members = teamSection
  .split("\n")
  .filter((l) => /^\|\s*\*\*M\d\*\*/.test(l))
  .map((l) => {
    const [id, name, roll, github, area] = l.split("|").slice(1, 6).map((c) => c.trim().replace(/\*\*/g, ""));
    return { id, name, roll, github: github.replace(/^@/, ""), area };
  });

const readme = read("README.md");
// Row found by a label pattern, so "| Live app |", "| **Live app** |" and "| Live app (ALB URL) |" all work.
const link = (label) => {
  const re = new RegExp(`^\\|\\s*\\**${label}\\b`, "i");
  const row = readme.split("\n").find((l) => re.test(l));
  const url = row && (row.match(/https?:\/\/[^\s|)]+/) || [])[0];
  return url || null;
};
const repoUrl = link("GitHub repo") || "https://github.com/hussainwaz/taskflow-devops";
const liveUrl = link("Live app");
const blob = (p) => `${repoUrl}/blob/main/${p}`;

// ---------- tiny Markdown -> HTML (enough for report.md: headings, lists, tables, bold, code, links) ----------
function inline(s) {
  return esc(s)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/(^|[\s(])\*([^*\s][^*]*?)\*(?=[\s.,;:!?)]|$)/g, "$1<em>$2</em>")
    .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '<a href="$2">$1</a>')
    .replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, '$1<a href="$2">$2</a>');
}
function markdown(md) {
  const out = [];
  let list = false;
  let para = [];
  const flush = () => {
    if (para.length) out.push(`<p>${inline(para.join(" "))}</p>`);
    para = [];
    if (list) out.push("</ul>");
    list = false;
  };
  const lines = md.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const h = line.match(/^(#{1,4})\s+(.*)/);
    if (h) {
      flush();
      const level = Math.min(h[1].length + 1, 4); // report "#" becomes h2 inside the PDF
      out.push(`<h${level}>${inline(h[2])}</h${level}>`);
    } else if (/^\s*[-*]\s+/.test(line)) {
      if (para.length) flush();
      if (!list) out.push("<ul>");
      list = true;
      let item = line.replace(/^\s*[-*]\s+/, "");
      while (i + 1 < lines.length && /^\s{2,}\S/.test(lines[i + 1]) && !/^\s*[-*]\s/.test(lines[i + 1])) {
        item += " " + lines[++i].trim();
      }
      out.push(`<li>${inline(item)}</li>`);
    } else if (/^\|.*\|\s*$/.test(line)) {
      flush();
      const rows = [];
      while (i < lines.length && /^\|.*\|\s*$/.test(lines[i])) rows.push(lines[i++]);
      i--;
      const cells = (r) => r.split("|").slice(1, -1).map((c) => c.trim());
      const body = rows.filter((r) => !/^\|\s*:?-{3,}/.test(r));
      const [head, ...rest] = body;
      out.push(
        "<table><thead><tr>" +
          cells(head).map((c) => `<th>${inline(c)}</th>`).join("") +
          "</tr></thead><tbody>" +
          rest.map((r) => "<tr>" + cells(r).map((c) => `<td>${inline(c)}</td>`).join("") + "</tr>").join("") +
          "</tbody></table>",
      );
    } else if (line.trim() === "") {
      flush();
    } else {
      if (list) flush();
      para.push(line.trim());
    }
  }
  flush();
  return out.join("\n");
}

// ---------- evidence, in the brief's order ----------
const evidenceDir = join(root, "docs/evidence");
const images = readdirSync(evidenceDir)
  .filter((f) => /\.(png|jpe?g)$/i.test(f))
  .sort();
const groups = [
  { title: "CI run: each stage a separate job", match: /^D01-/, expect: "D01-01-pipeline-jobs.png" },
  { title: "A security stage failed and blocked a PR", match: /^D02-/, expect: "D02-01-snyk-failed.png, D02-02-merge-blocked.png" },
  { title: "Branch protection settings for main", match: /^D06-01-/, expect: "D06-01-branch-protection.png" },
  { title: "ECR with tagged images", match: /^(D06-02-|M2-07-)/, need: /^D06-02-/, expect: "D06-02-ecr-backend-tags.png" },
  { title: "IAM OIDC trust policy", match: /^D06-03-/, expect: "D06-03-oidc-trust-policy.png" },
  { title: "Multi-zone setup", match: /^D06-0[45]-/, expect: "D06-04-subnets.png, D06-05-asg-instances-2-azs.png" },
  { title: "Failure recovery", match: /^D03-/, expect: "D03-01-terminate.png, D03-02-app-still-up.png, D03-03-asg-replaced.png" },
  { title: "Load test: scale-out and scale-in", match: /^D04-/, expect: "D04-01-k6.png, D04-02-cpu-graph.png, D04-03-asg-activity.png" },
  { title: "Commit deployed automatically, and a rollback", match: /^D05-/, expect: "D05-01-deploy-run.png, D05-02-version-live.png, D05-03-rollback-run.png" },
  { title: "Monitoring dashboard and a fired alarm", match: /^D07-/, expect: "D07-01-dashboard.png, D07-02-alarm-in-alarm.png, D07-03-sns-email.png" },
  { title: "Centralized logs (CloudWatch log groups)", match: /^M2-13-/, expect: null },
];
const used = new Set();
const caption = (f) =>
  f
    .replace(/\.(png|jpe?g)$/i, "")
    .replace(/^(D\d\d|M\d-\d\d)-\d\d-/, "")
    .replace(/-/g, " ");
const img = (f) => {
  used.add(f);
  return `<figure><img src="${pathToFileURL(join(evidenceDir, f)).href}"><figcaption>${esc(caption(f))} <span class="file">(${esc(f)})</span></figcaption></figure>`;
};
const missing = (what) => `<div class="missing">MISSING: ${esc(what)}</div>`;
const gaps = [];

let n = 0;
const evidenceHtml = groups
  .map((g) => {
    const files = images.filter((f) => g.match.test(f));
    if (!files.length && !g.expect) return "";
    n++;
    // need: the file(s) that actually satisfy the brief; other matches are shown as supporting evidence
    const satisfied = files.some((f) => (g.need || g.match).test(f));
    if (!satisfied) gaps.push(`Screenshot ${n}: ${g.expect}`);
    return `<section class="shot"><h3>${n}. ${esc(g.title)}</h3>${satisfied ? "" : missing(`docs/evidence/${g.expect}`)}${files.map(img).join("")}</section>`;
  })
  .join("\n");
const extra = images.filter((f) => !used.has(f));

// ---------- the document ----------
const diagram = join(root, "docs/submission/architecture.png");
if (!existsSync(diagram)) gaps.push("Architecture diagram: docs/submission/architecture.png (M3-14)");
if (group === "X") gaps.push("Group number: docs/WORK.md or GROUP=<n>");
if (!liveUrl) gaps.push("Live link: README links table");
const reportPath = join(root, "docs/submission/report.md");
if (!existsSync(reportPath)) gaps.push("Findings report: docs/submission/report.md");

const repoFiles = [
  [".github/workflows/pipeline.yml", "CI/CD pipeline, stages 2-12"],
  [".github/workflows/rollback.yml", "Manual rollback (image tag input)"],
  ["services/backend/Dockerfile", "Backend Dockerfile"],
  ["services/frontend/Dockerfile", "Frontend Dockerfile"],
  ["docker-compose.yml", "Compose, local stack"],
  ["docker-compose.prod.yml", "Compose, production on EC2"],
  ["scripts/", "Shell scripts (smoke test, deploy, healthcheck, build-and-test)"],
  ["SECURITY.md", "Scanners, thresholds, accepted findings"],
  ["infra/README.md", "Rebuild and teardown guide"],
];

const html = `<!doctype html><html><head><meta charset="utf-8"><title>Group${esc(group)} - TaskFlow</title>
<style>
  @page { size: A4; margin: 16mm 15mm; }
  body { font: 10.5pt/1.45 -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; color: #1b1f24; }
  h1 { font-size: 26pt; margin: 0 0 4pt; } h2 { font-size: 15pt; border-bottom: 1.5pt solid #1b1f24; padding-bottom: 3pt; margin-top: 0; }
  h3 { font-size: 11.5pt; margin: 12pt 0 5pt; } a { color: #0b57d0; } code { font: 9pt Menlo, Consolas, monospace; background: #f0f2f4; padding: 0 2pt; }
  table { border-collapse: collapse; width: 100%; margin: 6pt 0 10pt; } th, td { border: 0.6pt solid #b8bec6; padding: 4pt 6pt; text-align: left; vertical-align: top; }
  th { background: #f0f2f4; } td:nth-child(3), td:first-child { white-space: nowrap; } .page { page-break-after: always; } .cover { padding-top: 40mm; }
  .sub { font-size: 13pt; color: #4a525c; margin-bottom: 18mm; } .links td:first-child { width: 28%; font-weight: 600; }
  figure { margin: 6pt 0 12pt; page-break-inside: avoid; } img { max-width: 100%; max-height: 205mm; border: 0.6pt solid #b8bec6; }
  figcaption { font-size: 9pt; color: #4a525c; margin-top: 2pt; } .file { color: #8a929c; }
  .shot { page-break-inside: avoid; } .missing { border: 1.5pt dashed #c62828; color: #c62828; padding: 14pt; font-weight: 600; margin: 6pt 0 12pt; }
  .report h2 { font-size: 13pt; border: 0; margin: 8pt 0 3pt; } .report h3 { margin: 8pt 0 2pt; } .report p, .report li { margin: 2pt 0; }
  .report { font-size: 9pt; line-height: 1.3; } .report table { margin: 4pt 0; } .report td, .report th { padding: 2pt 5pt; } tr { page-break-inside: avoid; }
</style></head><body>

<section class="page cover">
  <h1>TaskFlow</h1>
  <div class="sub">DevOps final project (CS4067) · Group ${esc(group)} · containerized task tracker on AWS with a 12-stage DevSecOps pipeline</div>
  <table><thead><tr><th>Member</th><th>Name</th><th>Roll no.</th><th>GitHub</th><th>Area</th></tr></thead><tbody>
  ${members.map((m) => `<tr><td>${esc(m.id)}</td><td>${esc(m.name)}</td><td>${esc(m.roll)}</td><td><a href="https://github.com/${esc(m.github)}">${esc(m.github)}</a></td><td>${esc(m.area)}</td></tr>`).join("\n")}
  </tbody></table>
  <table class="links"><tbody>
    <tr><td>GitHub repository</td><td><a href="${esc(repoUrl)}">${esc(repoUrl)}</a></td></tr>
    <tr><td>Live app</td><td>${liveUrl ? `<a href="${esc(liveUrl)}">${esc(liveUrl)}</a>` : missing("live link")}</td></tr>
  </tbody></table>
</section>

<section class="page">
  <h2>Part 1: Architecture</h2>
  ${existsSync(diagram) ? `<figure><img src="${pathToFileURL(diagram).href}"></figure>` : missing("docs/submission/architecture.png (M3-14)")}
</section>

<section class="page">
  <h2>Part 2: Proof of deployment</h2>
  <p>Repository: <a href="${esc(repoUrl)}">${esc(repoUrl)}</a> (public). Workflow runs: <a href="${esc(repoUrl)}/actions">${esc(repoUrl)}/actions</a></p>
  <table><thead><tr><th>Graded file</th><th>What it is</th></tr></thead><tbody>
  ${repoFiles.map(([p, d]) => `<tr><td><a href="${esc(p.endsWith("/") ? `${repoUrl}/tree/main/${p}` : blob(p))}">${esc(p)}</a></td><td>${esc(d)}</td></tr>`).join("\n")}
  </tbody></table>
  ${evidenceHtml}
  ${extra.length ? `<section class="shot"><h3>Additional evidence</h3>${extra.map(img).join("")}</section>` : ""}
</section>

<section class="page">
  <h2>Part 3: Live link</h2>
  <p style="font-size:14pt">${liveUrl ? `<a href="${esc(liveUrl)}">${esc(liveUrl)}</a>` : missing("live link")}</p>
  <p>Health: ${liveUrl ? `<a href="${esc(liveUrl)}/health">${esc(liveUrl)}/health</a> · <a href="${esc(liveUrl)}/api/health">${esc(liveUrl)}/api/health</a> (shows the deployed version)` : ""}</p>
</section>

<section class="report">
  <h2>Part 4: Findings report</h2>
  ${existsSync(reportPath) ? markdown(readFileSync(reportPath, "utf8").replace(/^#\s.*\n/, "")) : missing("docs/submission/report.md")}
</section>
</body></html>`;

// ---------- print ----------
const work_dir = mkdtempSync(join(tmpdir(), "taskflow-pdf-"));
const htmlFile = join(work_dir, `Group${group}.html`);
writeFileSync(htmlFile, html);
const out = join(root, `docs/submission/Group${group}.pdf`);

const candidates = [
  process.env.CHROME,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "google-chrome",
  "chromium",
  "chromium-browser",
].filter(Boolean);
const chrome = candidates.find((c) => {
  if (c.startsWith("/")) return existsSync(c);
  try {
    execFileSync("which", [c], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
});
if (!chrome) {
  console.error("No Chrome/Chromium found. Set CHROME=/path/to/chrome. HTML is at " + htmlFile);
  process.exit(2);
}
execFileSync(
  chrome,
  ["--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--allow-file-access-from-files", `--print-to-pdf=${out}`, pathToFileURL(htmlFile).href],
  { stdio: "ignore" },
);
console.log(`PDF:  ${out}`);
console.log(`HTML: ${htmlFile}`);
console.log(gaps.length ? `Still missing (${gaps.length}):\n  - ${gaps.join("\n  - ")}` : "Nothing missing.");

// ---------- optional link check (F-10) ----------
if (process.argv.includes("--check-links")) {
  const urls = [...new Set([...html.matchAll(/href="(https?:[^"]+)"/g)].map((m) => m[1].replace(/&amp;/g, "&")))];
  let bad = 0;
  const ownFile = new RegExp(`^${repoUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/(?:blob|tree)/main/(.+)$`);
  for (const u of urls) {
    // GitHub refuses anonymous automated requests for file pages (503 even for public repos), so a
    // link to a file in this repo is checked against the checkout instead: same path, same branch.
    const own = u.match(ownFile);
    if (own) {
      const ok = existsSync(join(root, decodeURIComponent(own[1])));
      if (!ok) bad++;
      console.log(`${ok ? "OK  " : "FAIL"} ${ok ? "in repo" : "missing in repo"} ${u}`);
      continue;
    }
    let code = "ERR";
    // GitHub answers 429/503 to fast, bare requests: browser-like UA, a pause, and one retry.
    for (let attempt = 0; attempt < 2; attempt++) {
      if (attempt) await new Promise((r) => setTimeout(r, 3000));
      try {
        const res = await fetch(u, {
          redirect: "follow",
          headers: { "User-Agent": "Mozilla/5.0 (submission link check)" },
          signal: AbortSignal.timeout(10000),
        });
        code = res.status;
      } catch (e) {
        code = e.name;
      }
      if (typeof code === "number" && code < 400) break;
    }
    await new Promise((r) => setTimeout(r, 400));
    const ok = typeof code === "number" && code < 400;
    if (!ok) bad++;
    console.log(`${ok ? "OK  " : "FAIL"} ${code} ${u}`);
  }
  console.log(bad ? `${bad} of ${urls.length} links failed` : `all ${urls.length} links OK`);
  process.exitCode = bad ? 1 : 0;
}
