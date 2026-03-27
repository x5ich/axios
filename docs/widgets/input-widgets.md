# Numeric and Color Input Widgets

Axios provides a series of specialized text-based inputs designed specifically for managing numeric data types and color values.

> **Additional Input Types:** For interactive dragging, refer to [Drag Widgets](drag.md). For bounded range selections, see [Slider Widgets](slider.md).

---

## Shared Parameter Pattern

Standard numeric input widgets use a consistent argument structure for labeling and constraints.

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string?` | The descriptive label displayed alongside the input field. |
| 2 | `Increment` | `DataType?` | The step size used for logic-based increments or decrements. |
| 3 | `Min` | `DataType?` | The minimum allowable value for the input. |
| 4 | `Max` | `DataType?` | The maximum allowable value for the input. |
| 5 | `Format` | `string? \| {string}?` | A Lua-standard `string.format` pattern (defaults to `"%g"`). |

---

## InputNum Widget

A single input field for entering standard Lua numbers, supporting both integers and floating-point values.

```lua
local movementSpeed = Axios.State(16.0)

-- Allows entering a number between 0 and 100
Axios.InputNum({"WalkSpeed", 1.0, 0, 100}, {number = movementSpeed})
```

---

## Vector Inputs: InputVector2 and InputVector3

Multiple adjacent input fields for managing 2D and 3D Roblox vector coordinates.

```lua
local worldPosition = Axios.State(Vector3.new(0, 0, 0))

-- Creates three input fields (X, Y, Z) automatically
Axios.InputVector3({"World Position"}, {number = worldPosition})
```

---

## Interface Sizing: InputUDim and InputUDim2

Dedicated fields for managing Roblox `UDim` and `UDim2` values, specifically for UI positioning and sizing.

```lua
local elementSize = Axios.State(UDim2.new(0.5, 0, 0.5, 0))

-- Handles Scale and Offset components for X and Y axes
Axios.InputUDim2({"Panel Dimensions"}, {number = elementSize})
```

---

## InputRect Widget

Four input fields for defining a rectangular region (Min X/Y and Max X/Y).

```lua
local cropArea = Axios.State(Rect.new(0, 0, 200, 200))

Axios.InputRect({"Texture Crop Area"}, {number = cropArea})
```

---

## Color Inputs: InputColor3 and InputColor4

Advanced numeric inputs for managing `Color3` values. Supports standard RGB (0-255) and HSV modes, as well as an optional transparency channel.

```lua
local primaryColor = Axios.State(Color3.fromRGB(45, 140, 255))
Axios.InputColor3({"Primary Accent"}, {color = primaryColor})

local opacity = Axios.State(0.5)
-- Input for both color components and an alpha transparency value
Axios.InputColor4({"Glass Overlay"}, {color = primaryColor, transparency = opacity})
```

### Color-Specific Parameters

| # | Argument | Type | Description |
|---|---|---|---|
| 2 | `UseFloats` | `boolean?` | When true, uses a 0.0-1.0 range instead of the standard 0-255 RGB range. |
| 3 | `UseHSV` | `boolean?` | toggles the input mode to use Hue, Saturation, and Value instead of RGB. |
| 4 | `FormatColors` | `{string}?` | Custom `string.format` patterns for the internal color labels. |
