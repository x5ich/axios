# Basic Interactive Widgets

Fundamental clickable controls used for standard user interactions within your UI.

---

## Button Widget

A standard, versatile button that automatically scales to its text content.

```lua
if Axios.Button({"Confirm Action"}).clicked() then
    processData()
end
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The label displayed inside the button. |
| 2 | `Size` | `UDim2?` | Optional manual size specification (defaults to auto-scaling). |

### Interaction Events

Supported events: `clicked()`, `rightClicked()`, `doubleClicked()`, `ctrlClicked()`, `hovered()`

---

## SmallButton Widget

A compact version of the standard `Button` with minimal internal padding. This is ideal for close buttons, tight navigation strips, or high-density layouts.

```lua
if Axios.SmallButton({"[x]"}).clicked() then
    -- perform a quick action, like closing a window
    Axios.Shutdown()
end
```

### Positional Arguments and Events

Same as the standard [Button](#button-widget).

---

## Checkbox Widget

A toggle control used to manage boolean state values.

```lua
local featureEnabled = Axios.State(false)
-- Bind the checkbox directly to our 'featureEnabled' state
Axios.Checkbox({"Enable Laboratory Features"}, {isChecked = featureEnabled})

if featureEnabled:get() then
    -- Execute feature-specific logic here
end
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The descriptive label displayed alongside the checkbox. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `isChecked` | `State<boolean>?` | The underlying boolean state being toggled. |

### Interaction Events

Supported events: `checked()`, `unchecked()`, `hovered()`

---

## RadioButton Widget

A circular selector used to pick a single value from a specific group. Multiple RadioButtons sharing the same state object form an exclusive selection group.

```lua
local currentSelection = Axios.State("Standard")

-- Each button sets 'currentSelection' to its own unique value when clicked
Axios.RadioButton({"Standard Engine", "Standard"}, {index = currentSelection})
Axios.RadioButton({"Turbocharged Engine", "Turbo"}, {index = currentSelection})
Axios.RadioButton({"Experimental Reactor", "Experimental"}, {index = currentSelection})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The descriptive label for this specific option. |
| 2 | `Index` | `any` | The value that will be written to the shared state when this option is selected. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `index` | `State<any>?` | The shared state object that tracks the currently selected value. |

### Interaction Events

Supported events: `selected()`, `unselected()`, `active()`, `hovered()`
