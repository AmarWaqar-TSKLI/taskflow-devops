# Contributing — how we work

Read this once, fully. These rules exist so four people can work in parallel for two weeks without breaking
each other's stuff or losing marks.

## The 10 rules

1. **Never push to `main`.** Branch → PR → green checks → 1 review → merge.
2. **Write the test before the code.** (See [Tests first](#tests-first-tdd).)
3. **One task per branch, one branch per PR.** Branch name contains the task ID.
4. **Code against the contracts** in [docs/ARCHITECTURE.md §3](docs/ARCHITECTURE.md#3-contracts-single-source-of-truth). Don't invent names.
5. **Never commit a secret** — not even a "test" one, not even on a branch you'll delete.
6. **Never disable a scanner or lower a threshold.** Fix it, or document it in `SECURITY.md` with a reason.
7. **Commit as yourself** (your own GitHub account, your own machine). Marks depend on traceable contributions.
8. **Update [docs/PROGRESS.md](docs/PROGRESS.md) in the same PR** as the work.
9. **Blocked for more than 2 hours? Say so** in the group chat. Don't sit on it.
10. **Never delete AWS resources** without Member 4. Never create AWS access keys.

## Daily routine

- Post a 3-line standup in the group chat every day by 11:00:
  `Done: … / Next: … / Blocked: …`
- `git pull` main before starting, rebase your branch if main moved.

## Branches

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/<task-id>-<short-name>` | `feat/M1-03-tasks-api` |
| Fix | `fix/<task-id>-<short-name>` | `fix/M2-06-smoke-test-timeout` |
| Docs | `docs/<task-id>-<short-name>` | `docs/M4-13-infra-readme` |
| CI/infra | `ci/<task-id>-<short-name>` | `ci/M3-06-sonarcloud` |

`main` is always deployable. Feature branches live max ~2 days — small PRs merge faster.

## Commits

Format: `<type>(<scope>): <what> [<task-id>]`

```
feat(backend): add POST /api/tasks with validation [M1-03]
test(backend): failing tests for task validation [M1-03]
ci: add trivy image scan job [M3-09]
docs(infra): document security groups [M4-13]
```

Types: `feat`, `fix`, `test`, `docs`, `ci`, `build`, `refactor`, `chore`.

## Pull requests

1. Fill in the PR template (it's automatic).
2. Request your **reviewer** (rotation below). Anyone else is welcome to review too.
3. All required checks must be green. If a scanner fails, fix the cause — don't bypass.
4. Reviewer actually checks: pulls the branch or reads the diff, runs it if it's runnable, confirms tests exist.
5. **Merge with "Create a merge commit"** (keeps every individual commit visible in history).
6. Delete the branch after merging.

**Review rotation** (your default reviewer):

| Author | Reviewer |
|--------|----------|
| Member 1 | Member 2 |
| Member 2 | Member 3 |
| Member 3 | Member 4 |
| Member 4 | Member 1 |

## Tests first (TDD)

For **application code** (Member 1, plus anyone touching `services/`):

1. **Red** — write a Jest test that describes the behaviour. Run it. It fails.
2. **Green** — write the smallest code that makes it pass.
3. **Refactor** — clean up with the test still green.
4. Commit the test (ideally its own commit first — it shows TDD in the history).

Rules:
- Every endpoint has tests for the happy path **and** the error cases (400, 404).
- Every bug fix starts with a test that reproduces the bug.
- **Unit tests need no DB, no network, no AWS.** Mock the repository layer.
- Coverage threshold **80%** lines/branches is enforced in `jest.config.js`; CI fails below it.
- Run before every push: `npm test` and `npm run lint` and `npm run format:check` in the service folder
  (or `scripts/build-and-test.sh` once it exists).

For **non-app work**, "test first" means *decide how you'll prove it works before you build it* — write the
check in the task's PR description, then build until the check passes:

| Kind of work | How it is "tested" |
|--------------|-------------------|
| Dockerfile | Hadolint clean · `docker build` works · container runs as non-root (`docker run --rm <img> id`) · Trivy clean |
| Compose | `docker compose up --build` from a fresh clone → app works in browser, health endpoints return 200 |
| Shell script | ShellCheck clean · run it for real (success **and** a failure case) · paste output in PR |
| Workflow job | Link to a green run **and** a run where it correctly fails |
| AWS resource | The verification command / console screenshot listed in WORK.md for that task |
| Alarm | Deliberately trigger it, screenshot the SNS email |

## Definition of Done (both columns in PROGRESS.md)

- **Built ✅** — merged to `main` via a reviewed PR.
- **Tested ✅** — the proof from the table above exists and is linked in the *Proof* column of PROGRESS.md.

A task is not done until both are ticked.

## Secrets — read twice

- `.env` files are git-ignored. Only `.env.example` (placeholders) is committed.
- Before your first commit, check `git status` — no `.env`, no `*.pem`, no credentials.
- **If you commit a secret by accident: stop, tell Member 3 immediately.** We rotate the secret *and* rewrite
  history before it reaches `main`. Deleting the file in a new commit is **not** enough — Gitleaks scans history.
- Do **not** test Gitleaks with a fake key on a pushed branch. Demonstrate security blocking with Snyk/Trivy instead.

## AWS rules

- Everyone logs in to the console with their **own IAM user + MFA** (Member 4 creates them). No access keys.
- Tag everything you create: `Project=taskflow`, `Owner=M<n>`.
- Region is always `us-east-1`. Check the top-right before creating anything.
- Only Member 4 scales the ASG down overnight, and restores it before demos. Nothing is deleted before grading.

## Changing a contract

Need a new env var, endpoint, port, resource name? Open a `docs/` PR editing
[docs/ARCHITECTURE.md §3](docs/ARCHITECTURE.md#3-contracts-single-source-of-truth), tag the affected owners,
merge it, *then* build against it.
