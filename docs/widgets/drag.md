# Draggable Numeric Widgets

Click and drag to adjust numeric values. These widgets prioritize precision and speed, also supporting direct text input when clicking while holding the `Control` key.

- **Shift Key:** Increases the drag speed for rapid adjustments.
- **Alt Key:** Reduces the drag speed for high-precision fine-tuning.

---

## Shared Parameter Structure

All drag-based widgets use a consistent argument layout, identical to [Input Widgets](input-widgets.md):

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string?` | The descriptive label displayed alongside the widget. |
| 2 | `Increment` | `DataType?` | Specifies the base speed or step for the drag operation. |
| 3 | `Min` | `DataType?` | The lower bound constraint for the numeric value. |
| 4 | `Max` | `DataType?` | The upper bound constraint for the numeric value. |
| 5 | `Format` | `string? \| {string}?` | Custom string formatting (e.g., `"%.2f ms"`). |

---

## DragNum Widget

The primary widget for adjusting a single numeric value.

```lua
local movementSpeed = Axios.State(1.0)

-- Allows adjusting 'movementSpeed' between 0 and 100 with a 0.5 step
Axios.DragNum({"Walk Speed", 0.5, 0, 100}, {number = movementSpeed})
```

---

## Multi-Component Drag Widgets

Axios provides specialized widgets for more complex Roblox data types.

| Widget | Data Type | Components |
|---|---|---|
| `DragVector2` | `Vector2` | Two-component vector (X, Y). |
| `DragVector3` | `Vector3` | Three-component vector (X, Y, Z). |
| `DragUDim` | `UDim` | A scale and offset pair. |
| `DragUDim2` | `UDim2` | Four components (X Scale/Offset, Y Scale/Offset). |
| `DragRect` | `Rect` | Four-component rectangle definition. |

---

## Implementation Example: Physics Settings

Combine multiple drag widgets to manage complex configuration states.

```lua
local spawnPosition = Axios.State(Vector3.new(0, 0, 0))
local enginePower = Axios.State(16.0)

-- User can drag the position components or the power number
Axios.DragVector3({"Target Position", 0.1}, {number = spawnPosition})
Axios.DragNum({"Engine Power", 1.0, 0, 100}, {number = enginePower})

if Axios.Button({"Apply Physics Profile"}).clicked() then
    -- Retrieve the current state values and apply them
    applyProfiles(spawnPosition:get(), enginePower:get())
end
```
