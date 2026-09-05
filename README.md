# OC Agent Orquestator

[opencode](https://opencode.ai) configuration that defines a multi-agent development team: an orchestrator that plans, decomposes and delegates work to specialized subagents (architect, frontend, backend, QA, reviewer, devops and docs), plus a professor agent that only explains code.

It contains no application code: it is pure agent configuration.

## Structure

```
opencode.json             Global opencode configuration (minimal)
.opencode/rules/
  team.md                 GLOBAL layer (rules shared by every agent)
.opencode/agents/         ROLE layer (one file = one agent)
  orchestrator.md         Orchestrator (primary)
  arquitecto.md           Architecture and contracts subagent
  frontend.md             UI subagent
  backend.md              APIs and logic subagent
  qa.md                   Tests subagent
  reviewer.md             Code review subagent (does not edit)
  devops.md               CI/CD, builds and deploys subagent
  docs.md                 Documentation subagent
  profesor.md             Professor agent (primary, does not edit)
```

The definition is organized in two layers to avoid duplication:

- **GLOBAL** (`.opencode/rules/team.md`, injected to every agent via `instructions`): boundaries, decision policy and autonomy levels, uncertainty management (FACT/ASSUMPTION/DECISION/QUESTION/RISK), priority hierarchy, security, git policy, communication/handoff protocol, output format and base Definition of Done.
- **ROLE** (each `.md` in `.opencode/agents/`): identity, scope (responsible / not responsible), inputs, autonomy, workflow, decision policy, role engineering standards, testing and role-specific Definition of Done. Generic sections are inherited from the GLOBAL layer, never duplicated.

## Agents

| Agent | Mode | Model | Edits | Runs commands | Role |
|---|---|---|---|---|---|
| `orchestrator` | primary | deepseek-v4-flash | No | Read-only `git` only | Plans, delegates via `task` and integrates. |
| `profesor` | primary | deepseek-v4-flash | No | No | Explains code; does not modify files. |
| `arquitecto` | subagent | deepseek-v4-flash | No | Read-only `git` only | Defines architecture and contracts before implementation. |
| `frontend` | subagent | deepseek-v4-flash | Yes | Yes | UI, components, styles, a11y. |
| `backend` | subagent | deepseek-v4-flash | Yes | Yes | APIs, business logic, persistence. |
| `qa` | subagent | deepseek-v4-flash | Yes | Yes | Tests and requirement validation. |
| `reviewer` | subagent | gpt-5.6-luna | No | Read-only `git` only | Code review and security. |
| `devops` | subagent | deepseek-v4-flash | Yes | Yes | CI/CD, builds, deploys and infrastructure. |
| `docs` | subagent | deepseek-v4-flash | Yes | No | README and technical documentation. |

Subagents cannot launch other subagents (`task: deny`) nor access the web; the orchestrator is the only one that delegates.

> **Note**: `reviewer` uses the model `opencode-go/gpt-5.6-luna`. If that provider is not configured, the subagent fails; opencode has no per-agent model fallback. Make sure it is available or change its `model`.

## How to use

Open opencode at the root of a project:

- **Default agent**: any of the primaries (orchestrator or profesor), cycling with `Tab` or invoking it with `@`.
- **Orchestrator**: give it a development task and it decomposes, delegates to subagents, verifies and integrates.
- **Subagents**: also invoked directly with `@arquitecto`, `@frontend`, `@backend`, `@qa`, `@reviewer`, `@devops`, `@docs`.
- **Profesor**: ask it to explain a piece of code, a file or the whole project.

## How the flow works

1. The orchestrator analyzes the request and decomposes it into subtasks, identifying dependencies.
2. If the feature crosses frontend and backend, it defines the data contract first (delegates to `arquitecto` to propose it).
3. It delegates with the `task` tool (in parallel if there are no dependencies, in sequence if there are), always with objective, context, files and acceptance criteria.
4. It integrates the results and resolves conflicts between subagents (re-delegating or asking you).
5. Before closing, it requires reviewer or qa to validate the work when applicable. If reviewer requests changes, it re-delegates the fix (max 2 iterations) and then escalates to you if it persists.

## Specialization rules

Each agent defines in its `.md` (ROLE layer) identity, scope, inputs, autonomy, workflow, decision policy, engineering standards, testing and role-specific Definition of Done. The GLOBAL layer (`team.md`) provides what is common to all:

- **Boundaries**: frontend never touches backend and vice versa; if they need something from the other side, they report the exact contract (method, route, payload) to the orchestrator. QA does not fix production logic; docs only touches documentation; reviewer only reviews.
- **Decision policy**: autonomy levels (0 autonomous → 3 human approval) and when to escalate to the orchestrator or the user.
- **Uncertainty**: agents label facts, assumptions, decisions, questions and risks so an assumption never becomes a requirement.
- **Communication**: handoffs between agents follow a structured protocol (context, completed, decisions, files, interfaces, pending, risks, validation).
- **Verification**: each subagent declares its completion criteria (build/lint, tests, migrations, a11y) and reports which files it touched and what it tested.
- **Security**: common rules (no secrets, untrusted inputs, no disabling controls) + reviewer security checklist.

## Validating the agent configuration

`check-models.ps1` validates the agents (frontmatter, mode, permissions and models) and the availability of the models in opencode:

powershell -ExecutionPolicy Bypass -File check-models.ps1

- If a provider does not respond (e.g. in CI without global credentials), that check is skipped with a warning; the real failure (missing model with a queryable provider) stops with `exit 1`.
- The same script runs in CI (`.github/workflows/check-agents.yml`) on every push and PR, on `windows-latest`.

## Using this team in other projects

`opencode.json` and `.opencode/` only apply if you open opencode in this repository. To have the team available in any project, copy the configuration to opencode's global folder:

- **Windows**: `%USERPROFILE%\.config\opencode\`
- **Linux/macOS**: `~/.config/opencode/`

Copy `opencode.json` and the `.opencode/` folder there. If you already have a global `opencode.json`, merge the keys (agents and rules) instead of overwriting.

Global and project config combine: global agents are always available and project ones complement them.

## What a project needs to be functional

This team defines **how agents work** (GLOBAL and ROLE layers), but it does not
define **how your system works**. The GLOBAL layer requires every agent to read
the project context before starting:

- `AGENTS.md` (project root)
- `docs/` (architecture, conventions, api-contracts, when they exist)

Without that context, agents work on assumptions and behavior becomes
inconsistent. A project is fully functional with this team when it has the
`AGENTS.md` and the `docs/` described below.

### Recommended structure

```
project/
├── AGENTS.md                 Context the team reads on startup (required)
├── opencode.json             Optional: only if you define project-specific config
├── docs/
│   ├── architecture.md       Architecture and module boundaries
│   ├── conventions.md        Code and agent conventions
│   └── api-contracts.md      Data contracts between frontend and backend
├── apps/  |  packages/  |  ...  (your code)
```

Create `docs/` **only if the project already has content to document**; an
empty `docs/` adds nothing and agents will ignore it anyway.

> **Important**: the `AGENTS.md`, `docs/architecture.md`,
> `docs/conventions.md` and `docs/api-contracts.md` templates in this section
> are **only examples** of how they could be defined, adapted to a specific
> stack (Next.js + NestJS + Prisma). They are not a global definition for all
> projects: each project must define its own based on its real stack,
> structure and conventions.

### `AGENTS.md` (required)

It is the team's entry point. It must be **concise and verifiable**; if
something changes often (current state, backlog), do not put it here.

```markdown
# <Project>

## Stack
- Frontend: Next.js 15 / TypeScript / Tailwind CSS / Zustand
- Backend: NestJS / PostgreSQL / Prisma
- Testing: Vitest + Playwright
- Package manager: pnpm

## Structure
/apps
  /web       Frontend
  /api       Backend
/packages
  /ui        Shared components
  /types     Shared types and contracts
/docs

## Key conventions
- API routes: REST, versioned under /api/v1
- API errors: { error: { code, message } }
- No new dependencies without justification

## Commands
- Install: pnpm install
- Tests: pnpm test
- Lint: pnpm lint
- Typecheck: pnpm typecheck
- Build: pnpm build
```

`AGENTS.md` golden rules:

- Put what agents **need and cannot deduce** from the code.
- Put the exact verification commands (agents run them in their Definition of
  Done).
- Do not duplicate what is already in `.opencode/rules/team.md` (git,
  security, output format): opencode already injects that.
- Keep only stable information; current state and backlog go in `docs/` or in
  the tasks.

### `docs/architecture.md`

Describes how the system is organized. Required when the project has multiple
modules or a non-obvious architecture; the `arquitecto` uses it to propose
consistent contracts.

```markdown
# Architecture

## Modules
- web: Next.js app (SSR + client). Talks only to the backend over REST.
- api: NestJS. Exposes REST under /api/v1, logic in services, data in Prisma.

## Boundaries
- web does not access the database; it only consumes the API.
- api does not render UI.

## Main flows
- Authentication: JWT issued by POST /api/v1/auth/login, sent in
  Authorization: Bearer.
```

### `docs/conventions.md`

Conventions agents must follow so they do not invent patterns. The `reviewer`
verifies compliance.

```markdown
# Conventions

## Code
- Strict TypeScript across the whole repo.
- Presentation components do not contain business logic.
- Endpoint naming: kebab-case in the route, camelCase in JSON fields.

## Git / commits
feat(scope): description
fix(scope): description
test(scope): description

## Testing
- Business logic tests live next to the module (*.test.ts).
- The smallest test that validates the key behavior; no trivialities.
```

### `docs/api-contracts.md`

The data contract frontend and backend agree on **before** implementing.
Required for features that cross frontend and backend; the `arquitecto`
proposes it and keeps it updated.

```markdown
# API contracts

## GET /api/v1/users/:id
Response 200:
UserDTO { id: string, name: string, avatarUrl: string | null }

Response 404:
{ error: { code: "USER_NOT_FOUND", message: "..." } }

## POST /api/v1/users
Request:
{ name: string, email: string }

Response 201:
UserDTO (see GET /api/v1/users/:id)

Response 400:
{ error: { code: "VALIDATION_ERROR", message: "..." } }
```

### How these files are used

- Every agent **reads them before starting** (required by its ROLE layer), so
  they must be at the root and/or in `docs/` of the project where opencode is
  opened.
- There is no need to declare them in `opencode.json`: agents read them with
  `read` at the start of their workflow. Only if you want opencode to always
  load them into the session context can you add them to `instructions`
  (e.g. `"instructions": ["AGENTS.md", "docs/conventions.md"]`).
- If a project has no `docs/`, agents work with `AGENTS.md` alone: it is the
  minimum viable setup for the team to be functional.