# Initializing Axios

`Axios:Init()` is the primary entry point for the library. It must be called before declaring any widgets or UI code. This function handles the setup of the internal rendering engine and creates the root `ScreenGui` required for display.

```lua
Axios:Init(parentInstance?, eventConnection?, allowMultipleInits?): Axios
```

---

## Arguments

| # | Argument | Type | Default | Description |
|---|---|---|---|---|
| 1 | `parentInstance` | `BasePlayerGui \| GuiBase2d` | `PlayerGui` | The location where the Axios root UI container is created. |
| 2 | `eventConnection` | `RBXScriptSignal \| (() -> number) \| false` | `Heartbeat` | The event or mechanism that drives every render cycle. |
| 3 | `allowMultipleInits` | `boolean` | `false` | When enabled, subsequent `Init()` calls will be ignored instead of throwing an error. |

The function returns the main `Axios` table for chaining or immediate use.

---

## Internal Logic

- This function should typically be called only once. If you need to re-initialize safely, set `allowMultipleInits` to `true`.
- Initialization is not possible if `Axios.Shutdown()` has already been executed.
- If an `eventConnection` function is provided, Axios calls it in a loop and uses its return value (if numeric) as the `deltaTime` for that cycle.
- Providing `false` for the `eventConnection` disables the automatic loop entirely, requiring you to manually call `Axios.Internal._cycle(deltaTime)`.

---

## Implementation Examples

### Standard Initialization

Use this approach for the majority of use cases.

```lua
local Axios = loadstring(game:HttpGet("https://load.axios.x5i.ch"))()
Axios:Init()
```

### Custom Parenting

Useful for placing the GUI in `CoreGui` or a specific folder.

```lua
local myGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
Axios:Init(myGui)
```

### Manual Render Loop

Gives you full control over exactly when Axios updates.

```lua
-- Disable the internal automatic cycle
Axios:Init(nil, false)

while true do
    -- Manually trigger the Axios update loop
    Axios.Internal._cycle(task.wait())
end
```

### Custom Refresh Timing

Connect Axios to `RenderStepped` for the smoothest visual updates in high-frame-rate environments.

```lua
Axios:Init(nil, game:GetService("RunService").RenderStepped)
```
