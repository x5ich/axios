# Windows and Tooltips

The `Window` is the primary layout container in Axios. **All widgets must be declared within the scope of a Window.**

---

## Window Widget

The core container for your UI. Windows are interactive by default, allowing users to move, resize, collapse, and close them unless these features are explicitly disabled.

```lua
Axios.Window({"System Dashboard"})
    -- Nested widgets go here
Axios.End()
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Title` | `string` | The text label displayed in the title bar. |
| 2 | `NoTitleBar` | `boolean?` | If true, hides the entire upper title bar. |
| 3 | `NoBackground` | `boolean?` | If true, makes the window background transparent. |
| 4 | `NoCollapse` | `boolean?` | Disables the collapse button and interaction. |
| 5 | `NoClose` | `boolean?` | Disables the close button (prevents hiding). |
| 6 | `NoMove` | `boolean?` | Disables the ability to click and drag the window. |
| 7 | `NoScrollbar` | `boolean?` | Disables the vertical scrollbar for content. |
| 8 | `NoResize` | `boolean?` | Disables the ability to resize the window manually. |
| 9 | `NoNav` | `boolean?` | Disables the internal navigation system. |
| 10 | `NoMenu` | `boolean?` | Hides the window's internal menu bar. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `size` | `State<Vector2>` | Tracks the current width and height of the window. |
| `position` | `State<Vector2>` | Tracks the window's screen-space coordinates. |
| `isUncollapsed` | `State<boolean>` | Tracks whether the window is expanded or collapsed. |
| `isOpened` | `State<boolean>` | Tracks the current visibility/open status of the window. |
| `scrollDistance` | `State<number>` | Tracks the current vertical scroll offset. |

### Interaction Events

Supported events: `opened()`, `closed()`, `collapsed()`, `uncollapsed()`, `hovered()`

---

## Tooltip Widget

Displays a contextual floating text label adjacent to the mouse cursor. Tooltips are typically triggered via a hover check on another widget.

```lua
local btn = Axios.Button({"Check Status"})

-- trigger the tooltip when the user hovers over the button
if btn.hovered() then
    Axios.Tooltip({"Displays the current system uptime and status."})
end
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The message to display within the tooltip. |

---

## Design Pattern: Rendering Optimization

For interfaces with high widget counts, you can optimize performance by skipping the rendering of children when the window is collapsed or closed.

```lua
local dashWindow = Axios.Window({"Telemetry Dashboard"})

-- Only process expensive loops or complex widgets if the window is visible
if dashWindow.state.isOpened.value and dashWindow.state.isUncollapsed.value then
    for i = 1, 500 do
        Axios.Text({"Log entry: " .. i})
    end
end

Axios.End() -- remember: End() must always be called regardless of visibility
```

---

## Programmatic Window Management

Use `Axios.SetFocusedWindow(window)` to bring a specific window instance to the front of the display stack and make it the primary focused element.

```lua
local myWin = Axios.Window({"Background Task"})
Axios.End()

-- pull the window to the front programmatically
Axios.SetFocusedWindow(myWin)
```
