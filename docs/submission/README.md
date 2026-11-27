# submission — the final PDF

**Owner:** Member 2 (PDF) · Member 3 (diagram + report). Final file: `GroupX.pdf` (git-ignored; upload it, don't commit it).

## Build it

```bash
node docs/submission/build-pdf.mjs                 # -> docs/submission/GroupX.pdf (git-ignored)
GROUP=7 node docs/submission/build-pdf.mjs --check-links   # final: Group7.pdf + every link in it requested
```

Needs Node 18+ and Chrome (or `CHROME=/path/to/chromium`). Everything comes from the repo: team table and
group number from `docs/WORK.md`, links from the README links table, `architecture.png`, the screenshots in
`docs/evidence/` (in the brief's order, by filename prefix), and `report.md`. Anything missing prints as a red
**MISSING** box and is listed at the end of the run, so a draft can be built at any time. Rebuild after every
new screenshot.

## PDF structure
1. **Cover page:** project name, group number, **all members with roll numbers**, GitHub link, live link (clickable)
2. **Architecture diagram** — `architecture.png` (checklist: REQUIREMENTS.md "Part 1")
3. **Proof of deployment** — repo link + screenshots from `docs/evidence/` in the order listed there, each with a one-line caption
4. **Live link**
5. **Findings report** (one page) — `report.md`

## report.md outline (one page max)
- What we learned
- Main problems and how we solved them (3–5 bullets)
- Post-incident note (few lines, from `docs/incidents/`)
- Impact on our understanding of DevOps, security, automation, reliability, cloud

| Member | Name | Roll no. | Contributions |
|--------|------|----------|---------------|
| M1 | | | |
| M2 | | | |
| M3 | | | |
| M4 | | | |
