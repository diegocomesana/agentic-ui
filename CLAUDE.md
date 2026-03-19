# CLAUDE.md — Agentic UI Framework

## What is this
Phoenix LiveView app where an AI agent (OpenAI gpt-4o-mini) controls the UI dynamically through a chat. Layout split: widgets left (~70%), chat right (~30%).

## How to run
See [readme.md](readme.md) for full quick start, prerequisites, and environment variables.

**TL;DR:**
```bash
mix deps.get && cp .env.local.example .env.local  # one time — edit the API key
./dev-start.sh                                     # run
./dev-stop.sh                                      # stop
```

## Configuration
- API key goes in `.env.local` (gitignored). Copy from `.env.local.example`.
- Loaded automatically in `config/runtime.exs`
- `DATABASE_URL` in `.env.local` enables PostgreSQL. Without it, the app works in-memory.
- Dev local: `DATABASE_URL=ecto://postgres:postgres@localhost/agentic_ui_dev`

## Testing

### Unit tests
```bash
mix test                 # Run all tests
mix precommit            # Compile + format + test
```

### E2E tests with Playwright MCP

Test cases are defined in **`docs/e2e-tests.md`**.

#### Prerequisites
1. Verify Playwright MCP is active:
   ```bash
   claude mcp list
   ```
2. Start the server:
   ```bash
   ./dev-start.sh
   ```
3. Navigate to `http://localhost:4000`

#### How to run
1. Open `docs/e2e-tests.md` and pick tests by ID (T1, T2, etc.)
2. Use Playwright MCP tools to navigate and verify each step
3. T3.x (mechanical) are instant. T2.x/T4.x require agent (3-10s)
4. T5.x/T6.x (pinning/defaults) require editing `business/default_state.ex` and recompiling

#### When to run E2E
- **Always** after changes in: store, engine, session, workspace_live, widget components, agent prompt
- **Smoke** (T1 + T3): after any UI change
- **Full suite** (T1-T8): before a release or after structural changes

#### Test categories
| ID | Category | Covers | Speed |
|----|----------|--------|-------|
| T1 | Smoke | Layout, basic chat | Fast |
| T2 | Widgets via agent | All widget types | Slow (agent) |
| T3 | Mechanical events | Pagination, close, selects | Instant |
| T4 | Clear/Remove | Widget cleanup | Slow (agent) |
| T5 | Pinning | Pinned widgets | Requires config |
| T6 | Default State | Initial widgets | Requires config |
| T7 | Layout | Vertical/horizontal | Slow (agent) |
| T8 | UI General | Theme, debug panel | Fast |

## Project structure
```
dev-start.sh                       # Script: levanta todo para dev
dev-stop.sh                        # Script: para server + PostgreSQL
Dockerfile                         # Producción (EasyPanel)
docker-compose.yml                 # Solo PostgreSQL para dev local

business/                          # YOUR code — edit only this
  CLAUDE.md                          Guide for creating widgets
  ui_config.ex                       Branding, labels, visibility
  default_state.ex                   Initial widgets on load
  prompts/business_prompt.eex        Business-specific agent prompt
  descriptors/                       Widget type definitions (1 per type)
    registry.ex                      Type -> module mapping
  widgets/                           HEEx components (1 per type)
  reducers/                          State mutations (cart, common, config)
  services/                          Data layer (ProductService, DummyJSON, cache)
  tools/                             Agent tools (MCP-standard format)
    registry.ex                      Tool name -> module mapping

lib/agentic_ui/                    # Framework core
  store.ex                           Pure state (widgets, layout, conversation, pinned)
  engine.ex                          Orchestrator (event routing, agent dispatch, data resolution)
  agent_scheduler.ex                 Pure state machine: serializes agent invocations
  session.ex                         GenServer in-memory state + undo history + DB persist
  repo.ex                            Ecto.Repo (optional, when DATABASE_URL set)
  release.ex                         Migration runner for production
  accounts.ex                        Guest user + session persistence context
  accounts/                          Ecto schemas (GuestUser, GuestSession)
  agent/
    agent.ex                         Prompt builder + tool loop + JSON mode (provider-agnostic)
    provider.ex                      LLM provider behaviour
    providers/
      openai.ex                      OpenAI HTTP client (HTTPoison + retry)
    prompts/system_prompt.eex        Framework system prompt

lib/agentic_ui_web/                # Visual layer
  renderer.ex                        Store -> ordered widget list
  live/workspace_live.ex             Main LiveView
  components/widgets/chat.ex         Chat component
  plugs/guest_plug.ex                Guest token cookie assignment

docs/                              # Documentation
  ARCHITECTURE.md                    Design, patterns, data flow
  e2e-tests.md                       Playwright test suite
  architecture-diagram.html          Interactive diagram
```

## Key patterns
- **Pluggable LLM providers**: `AgenticUi.Agent.Provider` behaviour — OpenAI default, extensible via `AGENT_PROVIDER`
- **HTTPoison** for HTTP (copied from argentic-sentinel, NOT Req)
- **Mechanical events** (pagination) vs **semantic events** (go to agent)
- **JSON mode** agent: responds `{message, widgets, layout}`
- **Embedded MCP tools**: defined in MCP-standard format (`inputSchema`), provider converts to native format
- **Multi-turn tool calling**: agent makes up to 10 tool calls per invocation, evaluates results, decides next action
- **AgentScheduler** pure state machine: serializes invocations, discards stale results, auto-reinvokes
- **Task.async** for agent invocation (doesn't block LiveView)
- **Pluggable reducers**: descriptors declare `reducer: {Module, :function}` on events
- **Spawn actions**: descriptors declare auto-creation of widgets on events
- **Universal actions**: `toggle_pin` and `close` work on any widget
- **Guest users**: anonymous visitors get a persistent UUID cookie, session state saved to PostgreSQL
- **Dual storage**: with `DATABASE_URL` → PostgreSQL (sessions persist), without → in-memory (sessions lost on restart)
- `.env.local` parsed manually in runtime.exs (no dotenv library)
- `business/` is compiled via `elixirc_paths` in mix.exs

## Repo rules
- **Do NOT create files in the repo root** (snapshots, logs, screenshots, temps, etc.)
- Server logs go to `/tmp/phx-server.log`, NOT the repo
- Playwright screenshots/snapshots are NOT saved in the repo
- For temporary files, use `/tmp/` or Claude's memory directory

## Useful commands
```bash
./dev-start.sh           # Levantar todo para dev (Colima + Postgres + migraciones + server)
./dev-stop.sh            # Parar server + PostgreSQL
mix compile              # Compile
mix phx.server           # Dev server (sin dev-start.sh)
mix test                 # Tests
mix precommit            # Compile + format + test
mix deps.get             # Install dependencies

# PostgreSQL
mix ecto.create -r AgenticUi.Repo   # Crear DB
mix ecto.migrate -r AgenticUi.Repo  # Correr migraciones
mix ecto.reset -r AgenticUi.Repo    # Drop + create + migrate
```
