# Coding Practises

Rules and conventions used across this StarterKit. Follow these when building on top of it.

## Module Structure

Every module is a plain table with PascalCase public functions. No OOP, no metatables, no `self`.

```luau
local MyService = {}

function MyService.Init()
end

function MyService.DoSomething(player: Player, value: number)
end

return MyService
```

- One module per file
- Module name matches the file name
- Module is created as `local Name = {}` at the top
- Module is returned at the bottom with `return Name`
- All public functions are defined as `function Name.FunctionName()`
- Private/internal helpers are `local function` above the public API

## Naming

| Thing | Convention | Example |
|-------|-----------|---------|
| Module names | PascalCase | `PlayerData`, `EventBus` |
| Public functions | PascalCase | `EventBus.Subscribe()`, `Net.CreateEvent()` |
| Private functions | camelCase local | `local function deepCopy()` |
| Constants | UPPER_SNAKE_CASE | `AUTO_SAVE_INTERVAL`, `IS_SERVER` |
| Local variables | camelCase | `local playerData`, `local loadedCount` |
| Type definitions | PascalCase | `type MultiplierSource`, `type ObjectiveDef` |
| Event names (EventBus) | PascalCase strings | `"WaveStarted"`, `"EnemyKilled"` |
| Tags (TagManager) | PascalCase with prefix | `"UI_MobShop"`, `"ShopPrompt"`, `"Mob"` |

## No OOP

Never use metatables, `__index`, `setmetatable`, or colon syntax (`:`) for custom code.

Instead of classes, use **factory functions** that return plain tables with closures:

```luau
-- Good: factory function returning a plain table
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
```

Call with dot syntax: `panel.Show()` not `panel:Show()`

## State

Module-level state is stored in local variables above the public functions. Use typed table annotations.

```luau
local profiles: { [number]: { [string]: any } } = {} -- userId -> profile
local dirtyFlags: { [number]: boolean } = {}
```

- Key player data by `player.UserId` (number), not by the Player instance
- Clean up player state in `PlayerRemoving` to prevent memory leaks
- Comment the shape of tables inline: `-- userId -> profile`

## Type Annotations

Use Luau type annotations on function parameters and return types. Use `--!strict` at the top of shared modules.

```luau
function Multipliers.Get(player: Player, category: string): number
```

Use `:: Type` casts when getting instances from TagManager or FindFirstChild:

```luau
local gui = TagManager.WaitForTagged("UI_Shop")[1] :: ScreenGui
local btn = gui:FindFirstChild("BuyBtn") :: GuiButton
```

Define reusable types with `type` or `export type` at the top of the module:

```luau
type MultiplierSource = {
    name: string,
    getter: (Player) -> number,
}
```

## Error Handling

- Wrap DataStore calls in `pcall` - they can fail due to network issues
- Use `warn()` with a `[ModuleName]` prefix for errors: `warn("[PlayerData] Failed to load")`
- Use string interpolation for warn messages: `` warn(`[PlayerData] Failed: {err}`) ``
- Don't silently swallow errors. Always warn when a pcall fails
- Guard against nil: check `if not profile then return end` before accessing data

## Events and Communication

**Server-to-server**: Prefer direct `require` — it gives full intellisense and type safety. Use `EventBus.Publish()` / `EventBus.Subscribe()` only when:
- A direct require would create a circular dependency
- One emitter needs to notify multiple independent consumers (e.g. achievements, analytics, and UI all reacting to the same event)
- A low-level module needs to notify higher-level modules without depending on them

**Client-server**: Use `Net.CreateEvent()` / `Net.CreateFunction()` defined in a shared events file. Never create RemoteEvents manually or use `WaitForChild` strings.

```luau
-- shared/GameEvents.luau
local Net = require(shared.Net)
local Events = {}
Events.WaveStart = Net.CreateEvent("WaveStart")
Events.ShopBuy   = Net.CreateEvent("ShopBuy")
return Events
```

## Init Pattern

Every service/controller exports an `Init()` function. The auto-init scripts handle discovery and calling.

- Don't manually add require lines to init scripts
- Use `.Priority` (number) on a module to control init order. Lower = earlier. Default is 100
- Server inits sequentially (safe for dependencies). Client inits in parallel (faster loading)

```luau
local ExampleService = {}
ExampleService.Priority = 1 -- loads before everything else

function ExampleService.Init()
    -- setup
end

return ExampleService
```

## Player Data

All player data goes through `ProfileStore` (by loleris) - session-locked DataStore with auto-save.

- Create a store with `ProfileStore.New(store_name, template)`
- Start a session per player with `store:StartSessionAsync(profile_key)`
- Access data via `profile.Data` - changes are automatically saved
- End a session on player leave with `profile:EndSession()`
- Never create separate DataStores for individual features

## UI Panels

Use `Panel.Create()` for any toggleable UI screen (shops, inventories, settings, etc.).

- Tag the ScreenGui (e.g. `"UI_MobShop"`) and optionally the close button (`"UI_MobShopClose"`)
- Pass `onShow`/`onHide` callbacks in the config for custom logic
- Gamepad focus is handled automatically via `gamepadFocusTag`
- Call `panel.Show()` / `panel.Hide()` / `panel.Toggle()` with dot syntax

## File Organisation

```
shared/          -- Modules used by both server and client
server/          -- Server services (auto-discovered by init.server.luau)
client/          -- Client controllers (auto-discovered by init.client.luau)
```

- Shared modules go in `shared/` - never put server-only logic here
- Server files are named `XxxService.luau`
- Client files are named `XxxController.luau`
- Config/data tables go in `shared/` (e.g. `Constants.luau`, `MobConfig.luau`)

## General

- Keep modules short and focused. One responsibility per file
- Prefer data-driven config tables over hardcoded logic scattered across files
- Use `task.spawn` for non-blocking operations, `task.delay` for deferred work
- Use `table.clear()` instead of reassigning `{}` when reusing a table
- Use generalized iteration (`for k, v in table do`) not `pairs()`/`ipairs()`
- Use string interpolation (`` `text {var}` ``) not concatenation (`"text " .. var`)