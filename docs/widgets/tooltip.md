# Tooltip Widget

The `Tooltip` widget provides a way to display descriptive text and contextual help when a user hovers their mouse over a specific UI element.

```lua
Axios.Tooltip({ textContent })
```

---

## Technical Overview

A tooltip renders its message content immediately adjacent to the current mouse cursor position. Under the hood, Axios handles the positioning and visibility of the tooltip based on the frame-by-frame declarations.

```lua
local infoButton = Axios.Button({"Help"})

-- Trigger the tooltip when the user's mouse enters the button's bounds
if infoButton.hovered() then
    Axios.Tooltip({"Displays the help menu and system diagnostics."})
end
```

---

## Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The text message to be displayed within the tooltip frame. |

---

## Implementation Best Practices

- **Connect to Hover Events:** Always declare the `Tooltip` widget within a `.hovered()` conditional block for the target element. 
- **Immediate-Mode Lifecycle:** Since Axios is an immediate-mode library, the tooltip must be "re-declared" in every render frame while the user is actively hovering. If the hover check returns `false`, the tooltip will automatically stop rendering in the next cycle.
- **Rich Content:** Tooltips are ideal for providing extra clarity on complex configuration labels or explaining non-obvious button actions.
