# Combo and Selection Widgets

Interactive dropdown selectors and selection groups for picking one or more values from a list.

---

## Selectable Widget

A single selectable item within a list. Multiple `Selectable` widgets sharing the same `index` state object form a unified selection group, where only one item can be active at a time.

```lua
local selectedFruit = Axios.State("Apple")

-- These selectables are bound to the 'selectedFruit' state
Axios.Selectable({"Apple", "Apple"}, {index = selectedFruit})
Axios.Selectable({"Banana", "Banana"}, {index = selectedFruit})
Axios.Selectable({"Cherry", "Cherry"}, {index = selectedFruit})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The label displayed for this item. |
| 2 | `Index` | `any` | The value written to the shared state when this item is selected. |
| 3 | `NoClick` | `boolean?` | If true, disables user interaction with this specific item. |

### Interaction Events

Supported events: `selected()`, `unselected()`, `active()`, `clicked()`, `rightClicked()`, `hovered()`

---

## Combo Widget (Dropdown)

A container widget that opens a dropdown menu when clicked. Use child `Selectable` widgets within a `Combo` to provide choices to the user.

```lua
local choice = Axios.State("Active")

-- Initial dropdown declaration
Axios.Combo({"System Mode"}, {index = choice})
    Axios.Selectable({"Active Status", "Active"}, {index = choice})
    Axios.Selectable({"Standby Mode", "Standby"}, {index = choice})
    Axios.Selectable({"Power Off", "Off"}, {index = choice})
Axios.End() -- explicitly close the dropdown container
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The descriptive label beside the dropdown. |
| 2 | `NoButton` | `boolean?` | If true, hides the interactive dropdown arrow. |
| 3 | `NoPreview` | `boolean?` | If true, hides the text preview of the currently selected item. |

### Interaction Events

Supported events: `opened()`, `closed()`, `changed()`, `hovered()`

---

## Helper Widgets: ComboArray and ComboEnum

These convenience wrappers automatically populate a `Combo` from a Lua array or a Roblox `Enum` object. These do **not** require an `End()` call.

### ComboArray

Automatically generates list items from a provided Lua array.

```lua
local colors = {"Crimson", "Emerald", "Azure"}
local selectedColor = Axios.State("Crimson")

-- This single call handles the container and all internal list items
Axios.ComboArray({"Theme Color"}, {index = selectedColor}, colors)
```

### ComboEnum

Generates list items directly from a standard Roblox `Enum` library.

```lua
local chosenMaterial = Axios.State(Enum.Material.SmoothPlastic)

-- Automatically builds items for all valid values in Enum.Material
Axios.ComboEnum({"Set Material"}, {index = chosenMaterial}, Enum.Material)
```

### Additional Parameters

| Widget | Parameter | Description |
|---|---|---|
| `ComboArray` | `selectionArray` | An array containing any valid Lua values as choices. |
| `ComboEnum` | `enumType` | The Roblox `Enum` object to reference (e.g., `Enum.Font`). |
