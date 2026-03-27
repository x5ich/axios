# Input Handling

Axios processes inputs through widget events, which are primarily functions that return a boolean value (`true` or `false`).

---

## The Immediate Mode Pattern

Since Axios follows an immediate-mode architecture, events like `clicked()` only return `true` for the single frame in which the action occurred. Standard Lua conditional blocks are the most efficient way to handle these interactions.

```lua
if Axios.Button({"Confirm Action"}).clicked() then
    -- this logic executes exactly once on the frame the button is clicked
    performCriticalAction()
end
```

---

## Discrete Events (One-frame firing)

These events return `true` for exactly one render cycle immediately following the specified user action.

| Event | Trigger Condition |
|---|---|
| `clicked()` | Triggered by a standard left mouse click. |
| `rightClicked()` | Triggered by a standard right mouse click. |
| `doubleClicked()` | Triggered by two rapid left mouse clicks. |
| `ctrlClicked()` | Triggered by a left click while holding the `Control` key. |
| `checked()` | Returns true when a checkbox is toggled to an active state. |
| `unchecked()` | Returns true when a checkbox is toggled to an inactive state. |
| `selected()` | Returns true when a Selectable or RadioButton is picked. |
| `unselected()` | Returns true when a Selectable or RadioButton is deselected. |
| `opened()` | Returns true when a Window, Menu, or Tab becomes visible. |
| `closed()` | Returns true when a Window, Menu, or Tab is hidden. |
| `collapsed()` | Returns true when a Tree or Window is minimized/collapsed. |
| `uncollapsed()` | Returns true when a Tree or Window is expanded. |
| `textChanged()` | Returns true when an InputText widget loses focus after an edit. |
| `numberChanged()` | Returns true when a numeric input value is modified. |
| `changed()` | Generic event for updates in Combos, ProgressBars, and similar widgets. |

---

## Continuous Events

These events remain `true` for every render cycle as long as the specified condition is maintained by the user.

| Event | Status Condition |
|---|---|
| `hovered()` | Returns true as long as the mouse pointer is within the widget's bounds. |
| `active()` | Returns true while the widget is in its primary active state (e.g., a selected RadioButton). |

---

## Practical Implementation Patterns

### Inline Conditionals

This is the most common pattern for simple, one-off interactions.

```lua
if Axios.Button({"Submit"}).clicked() then
    submitData()
end
```

### Reference Management

When you need to check multiple interaction types for a single widget, storing the widget's return value is a cleaner approach.

```lua
local btn = Axios.Button({"Interaction Area"})

-- handle different click types
if btn.clicked() then print("Primary action triggered") end
if btn.rightClicked() then print("Secondary action triggered") end

-- provide contextual feedback through tooltips while hovering
if btn.hovered() then
    Axios.Tooltip({"Displays additional information about this action."})
end
```
