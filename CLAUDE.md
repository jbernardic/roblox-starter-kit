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
- **Config/data tables** go in `src/shared/` (e.g. `Constants.luau`, `MobConfig.luau`). Prefer data-driven config tables over hardcoded logic scattered across files.

## Auto-Init System

`init.server.luau` and `init.client.luau` auto-discover all ModuleScripts in their respective folders. **Never manually add require lines to these init scripts.**

- Server: initialized sequentially (safe for inter-service dependencies)
- Client: initialized in parallel (faster load), fires `Events.ClientLoaded:FireServer()` when all controllers are done
- Control init order with `.Priority` (number, lower = earlier, default = 100)
- Discovery is name-based: any ModuleScript whose name contains `"Service"` is loaded

**Client-ready handshake:** `PlayerInit` on the server is not called on `PlayerAdded`. Instead the server waits for `Events.ClientLoaded` from that player before calling `PlayerInit`. This guarantees all client controllers are initialized and listening before the server fires any `OnClientEvent`s at them. Never send data to a client from `PlayerInit` before this handshake — the client won't be ready.

Each service may export:
- `Init()` — called once at server start, in priority order. Use for server-level setup (connecting `PlayerRemoving`, etc.)
- `PlayerInit(player: Player)` — called per player after the client fires `ClientLoaded`, in priority order. Each player runs concurrently, but services are called sequentially per player so e.g. data loads before other services run.

```luau
local MyService = {}
MyService.Priority = 1  -- runs before Priority 100 services

function MyService.Init()
    -- server-level setup (event connections, etc.)
end

function MyService.PlayerInit(player: Player)
    -- called for each player, after higher-priority services have finished
end

return MyService
```

## Architecture Conventions

**No OOP.** Never use metatables, `__index`, `setmetatable`, or colon syntax for custom modules. Use factory functions with closures returning plain tables, called with dot syntax:

```luau
function Panel.Create(tag)
    local gui = TagManager.WaitForTagged(tag)[1]
    local panel = {}

    function panel.Show()
        gui.Enabled = true
    end

    function panel.Hide()
        gui.Enabled = false
    end

    return panel
end

-- panel.Show() not panel:Show()
```

**Module structure:**
- `local ModuleName = {}` at top, `return ModuleName` at bottom
- Module name must match the file name
- Public functions: `function ModuleName.FunctionName()`
- Private helpers: `local function camelCase()` above the public API

**Naming:**

| Thing | Convention | Example |
|---|---|---|
| Module names | PascalCase | `PlayerData`, `EventBus` |
| Public functions | PascalCase | `EventBus.Subscribe()` |
| Private functions | camelCase local | `local function deepCopy()` |
| Constants | UPPER_SNAKE_CASE | `AUTO_SAVE_INTERVAL` |
| Local variables | camelCase | `local playerData` |
| Type definitions | PascalCase | `type MultiplierSource`, `type ObjectiveDef` |
| Event names | PascalCase strings | `"WaveStarted"` |
| Tags | PascalCase with prefix | `"UI_MobShop"`, `"ShopPrompt"` |

**State:** Store module-level state in local variables above the public API. Key player data by `player.UserId` (number), not the Player instance. Comment the shape of tables inline:

```luau
local profiles: { [number]: Profile } = {} -- userId -> profile
local dirtyFlags: { [number]: boolean } = {}
```

**Type annotations:** Use `--!strict` on shared modules. Annotate all function parameters and returns. Define reusable types with `export type` at the top of the module. Use `:: Type` casts for TagManager/FindFirstChild results:

```luau
export type MultiplierSource = {
    name: string,
    getter: (Player) -> number,
}

local gui = TagManager.WaitForTagged("UI_Shop")[1] :: ScreenGui
local btn = gui:FindFirstChild("BuyBtn") :: GuiButton
```

## Communication Patterns

**Server ↔ Server:** Prefer direct `require` — it gives full intellisense and type safety. Use `EventBus` only when:
- A direct require would create a circular dependency
- One emitter needs to notify multiple independent consumers (e.g. achievements, analytics, and UI all reacting to `"PlayerDied"`)
- A low-level module needs to notify higher-level modules without depending on them

Avoid EventBus for simple point-to-point calls where a require works — event names are untyped strings, payloads aren't enforced, and subscribers are invisible to the type checker.

**Client ↔ Server:** All RemoteEvents/RemoteFunctions are defined in `src/shared/Events.luau` using `Net.CreateEvent()` / `Net.CreateFunction()`. These return the actual `RemoteEvent`/`RemoteFunction` instances, so you get full intellisense and the standard Roblox API. Never create Remotes manually or use `WaitForChild` strings. Group events by feature with a comment header.

```luau
-- src/shared/Events.luau
local Net = require(ReplicatedStorage.Shared.Net)
local Events = {}

-- Shop
Events.ShopBuy = Net.CreateEvent("ShopBuy") -- returns RemoteEvent

return Events
```

```luau
-- server
Events.ShopBuy.OnServerEvent:Connect(function(player, itemName) end)
Events.ShopBuy:FireClient(player, ...)

-- client
Events.ShopBuy.OnClientEvent:Connect(function(...) end)
Events.ShopBuy:FireServer(itemName)
```

## Key Shared Modules

| Module | Purpose |
|---|---|
| `EventBus` | Pub/sub for decoupled server-to-server communication |
| `Net` | Auto-creates RemoteEvents/RemoteFunctions and returns the actual typed instances |
| `ProfileStore` | Session-locked DataStore (by loleris) — all player persistence goes here |
| `TagManager` | CollectionService wrapper; filters StarterGui duplicates on client |
| `Panel` | Factory for toggleable UI screens (`Show/Hide/Toggle`) |
| `Multipliers` | Centralized multiplier stack (register sources, query combined value) |
| `Objectives` | Data-driven quest/tutorial system driven by EventBus events |

## Player Data

All persistent player data goes through `PlayerDataService`. Never use ProfileStore directly or create separate DataStores.

Add new fields to the `PlayerData` type and `template` in `PlayerDataService.luau` — `profile:Reconcile()` auto-fills missing keys for existing players.

**API:**
- `PlayerDataService.Get(player)` — returns `PlayerData?` (nil if not yet loaded)
- `PlayerDataService.IsLoaded(player)` — boolean check before accessing data
- `PlayerDataService.GetProfile(player)` — raw ProfileStore profile, for advanced use only

**In a `PlayerInit`** (data is guaranteed loaded by Priority 1 before your service runs):
```luau
function MyService.PlayerInit(player: Player)
    local data = PlayerDataService.Get(player)
    if not data then return end
    -- data.currency, etc.
end
```

**Mutating data** — edit `profile.Data` directly, ProfileStore auto-saves:
```luau
local data = PlayerDataService.Get(player)
if not data then return end
data.currency += 100
```

## UI Panels

Use `Panel.Create()` for any toggleable UI screen (shops, inventories, settings, etc.).

- Tag the ScreenGui (e.g. `"UI_Shop"`) and optionally the close button (e.g. `"UI_ShopClose"`)
- Pass `onShow`/`onHide` callbacks for custom logic
- Gamepad focus is handled automatically via `gamepadFocusTag`
- Call with dot syntax: `panel.Show()` / `panel.Hide()` / `panel.Toggle()`

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
