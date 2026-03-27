# Slider Widgets

Visual selection sliders with a primary draggable grip, constrained within a fixed minimum and maximum range. Like many Axios inputs, these also support direct numeric text entry when clicking while holding the `Control` key.

---

## Shared Parameter and Default Values

Slider widgets use a parameter structure identical to [Input Widgets](input-widgets.md), using the `Min` and `Max` values to define the functional boundaries of the slider.

| Widget | Default Min | Default Max | Default Step |
|---|---|---|---|
| `SliderNum` | `0` | `100` | `1` |
| `SliderVector2` | `{0, 0}` | `{100, 100}` | `{1, 1}` |
| `SliderVector3` | `{0, 0, 0}` | `{100, 100, 100}` | `{1, 1, 1}` |
| `SliderUDim` | `{0, 0}` | `{1, 960}` | `{0.01, 1}` |
| `SliderUDim2` | `{0, 0, 0, 0}` | `{1, 960, 1, 960}` | `{0.01, 1, 0.01, 1}` |
| `SliderRect` | `{0, 0, 0, 0}` | `{960, 960, 960, 960}` | `{1, 1, 1, 1}` |

---

## SliderNum Widget

The primary widget for selecting a single numeric value via a horizontal slider.

```lua
local systemVolume = Axios.State(50)

-- A volume slider from 0% to 100% with a whole-number step
Axios.SliderNum({"Master Volume", 1, 0, 100, "%d%%"}, {number = systemVolume})
```

---

## Multi-Component Sliders

Manage complex data types (vectors, UDims, Rects) with multiple synchronized slider components.

```lua
local objectScale = Axios.State(Vector2.new(1.0, 1.0))

-- Adjust both X and Y object scales simultaneously
Axios.SliderVector2({
    "Interface Scale", 
    Vector2.new(0.1, 0.1), 
    Vector2.new(0.5, 0.5), 
    Vector2.new(2.5, 2.5)
}, {number = objectScale})
```

### Interaction Events

Supported events: `numberChanged()`, `hovered()`
