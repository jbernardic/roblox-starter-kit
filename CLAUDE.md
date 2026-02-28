# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

Install tools (requires [Aftman](https://github.com/LPGhatguy/aftman)):
```bash
aftman install
```

Build the place file:
```bash
rojo build -o "SpeedGame.rbxlx"
```

Start the live-sync dev server (open `SpeedGame.rbxlx` in Roblox Studio first):
```bash
rojo serve
```

## Project Structure

Rojo maps `src/` to the Roblox game hierarchy via `default.project.json`:

| Source path | Roblox location |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |

- **Server files** are named `XxxService.luau`
- **Client files** are named `XxxController.luau`
- **Shared modules** go in `src/shared/` — never put server-only logic here

## Auto-Init System

`init.server.luau` and `init.client.luau` auto-discover all ModuleScripts in their respective folders. **Never manually add require lines to these init scripts.**

- Server: initialized sequentially (safe for inter-service dependencies)
- Client: initialized in parallel (faster load), fires `ClientLoadedEvent` when done
- Control init order with `.Priority` (number, lower = earlier, default = 100)

```luau
local MyService = {}
MyService.Priority = 1  -- runs before Priority 100 services

function MyService.Init()
end

return MyService
```

## Architecture Conventions

**No OOP.** Never use metatables, `__index`, `setmetatable`, or colon syntax for custom modules. Use factory functions with closures returning plain tables instead.

**Module structure:**
- `local ModuleName = {}` at top, `return ModuleName` at bottom
- Module name must match the file name
- Public functions: `function ModuleName.FunctionName()`
- Private helpers: `local function camelCase()`

**Naming:**

| Thing | Convention | Example |
|---|---|---|
| Public functions | PascalCase | `EventBus.Subscribe()` |
| Private functions | camelCase local | `local function deepCopy()` |
| Constants | UPPER_SNAKE_CASE | `AUTO_SAVE_INTERVAL` |
| Local variables | camelCase | `local playerData` |
| Event names | PascalCase strings | `"WaveStarted"` |
| Tags | PascalCase with prefix | `"UI_MobShop"`, `"ShopPrompt"` |

**State:** Store module-level state in local variables above the public API. Key player data by `player.UserId` (number). Always clean up in `Players.PlayerRemoving` to prevent leaks.

**Type annotations:** Use `--!strict` on shared modules. Annotate all function parameters and returns. Use `:: Type` casts for TagManager/FindFirstChild results.

## Communication Patterns

**Server ↔ Server:** Prefer direct `require` — it gives full intellisense and type safety. Use `EventBus` only when:
- A direct require would create a circular dependency
- One emitter needs to notify multiple independent consumers (e.g. achievements, analytics, and UI all reacting to `"PlayerDied"`)
- A low-level module needs to notify higher-level modules without depending on them

Avoid EventBus for simple point-to-point calls where a require works — event names are untyped strings, payloads aren't enforced, and subscribers are invisible to the type checker.

**Client ↔ Server:** Define all RemoteEvents/RemoteFunctions in a shared events file using `Net.CreateEvent()` / `Net.CreateFunction()`. Never create Remotes manually or use `WaitForChild` strings.

```luau
-- src/shared/GameEvents.luau
local Net = require(shared.Net)
local Events = {}
Events.WaveStart = Net.CreateEvent("WaveStart")
return Events
```

## Key Shared Modules

| Module | Purpose |
|---|---|
| `EventBus` | Pub/sub for decoupled server-to-server communication |
| `Net` | Wraps RemoteEvents/RemoteFunctions with symmetric client/server API |
| `ProfileStore` | Session-locked DataStore (by loleris) — all player persistence goes here |
| `TagManager` | CollectionService wrapper; filters StarterGui duplicates on client |
| `Panel` | Factory for toggleable UI screens (`Show/Hide/Toggle`) |
| `Multipliers` | Centralized multiplier stack (register sources, query combined value) |
| `Objectives` | Data-driven quest/tutorial system driven by EventBus events |

## Player Data

All persistent data goes through `ProfileStore`. Never create separate DataStores for individual features.

```luau
local store = ProfileStore.New("PlayerData", defaultTemplate)
local profile = store:StartSessionAsync(tostring(player.UserId))
-- profile.Data.currency = ...
profile:EndSession()  -- on PlayerRemoving
```

## Error Handling

- Wrap all DataStore calls in `pcall`
- Log errors with a module prefix: `warn("[ModuleName] {err}")`
- Never silently swallow errors
- Guard against nil before accessing data: `if not profile then return end`

## Luau Style

- Use generalized iteration (`for k, v in t do`) — not `pairs()`/`ipairs()`
- Use string interpolation (`` `hello {name}` ``) — not concatenation
- Use `task.spawn` for non-blocking work, `task.delay` for deferred work
- Use `table.clear(t)` instead of reassigning `t = {}`
