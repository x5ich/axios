# Tabbed Navigation Widgets

Axios provides a horizontal navigation system, allowing you to organize window content into distinct, selectable views.

---

## TabBar Widget

The primary container for a series of tabs. It manages the alignment and spacing of all nested `Tab` widgets.

```lua
Axios.TabBar()
    Axios.Tab({"General Settings"})
        Axios.Text({"Primary application configuration options."})
    Axios.End() -- closes the General tab scope

    Axios.Tab({"Advanced Settings"})
        Axios.Text({"Low-level engine and debug parameters."})
    Axios.End() -- closes the Advanced tab scope
Axios.End() -- closes the TabBar container
```

---

## Tab Widget

An individual selectable button within a `TabBar`. To optimize performance, any child widgets declared inside a `Tab` are only rendered when that specific tab is active.

```lua
Axios.Tab({"Active Tab"})
    -- This logic only executes when the tab is currently selected
    Axios.Text({"Displaying dynamic content."})
Axios.End()
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The label displayed on the tab button. |
| 2 | `NoClose` | `boolean?` | If true, hides the interactive close `[x]` button on the tab. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `index` | `State<any>?` | Shared with the parent `TabBar` to manage the currently selected tab. |
| `isOpened` | `State<boolean>?` | Tracks the visibility/open status of the tab (if `NoClose` is false). |

### Interaction Events

Supported events: `opened()`, `closed()`, `selected()`, `unselected()`, `active()`, `hovered()`

---

## Design Pattern: Mutually Exclusive Selection Groups

For advanced tab control, you can share a single state object across the `TabBar` and all its `Tab` children to manage the active selection programmatically.

```lua
local currentSelectedTab = Axios.State("General")

Axios.TabBar()
    Axios.Tab({"General Options", "General"}, {index = currentSelectedTab})
        -- render general content
    Axios.End()

    Axios.Tab({"Advanced Options", "Advanced"}, {index = currentSelectedTab})
        -- render advanced content
    Axios.End()
Axios.End()
```
