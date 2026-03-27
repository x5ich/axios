# UI Layout and Formatting

Axios provides a collection of utility widgets specifically designed for controlling vertical spacing, horizontal alignment, and indentation within your UI.

---

## Separator Widget

Draws a simple horizontal line across the entire width of its parent container. This is a common pattern for visually grouping related content.

```lua
Axios.Text({"Primary Configuration"})
Axios.Separator()
Axios.Text({"Advanced Settings Below"})
```

---

## Indent Widget

Shifts all nested widgets to the right by a specified width. This is particularly useful for indicating hierarchy or secondary information.

```lua
Axios.Text({"Main Module"})
Axios.Indent()
    -- These items will be visually nested
    Axios.Text({"Sub-task A"})
    Axios.Text({"Sub-task B"})
Axios.End() -- closes the indentation scope
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Width` | `number?` | Specifies the indent width in pixels (defaults to the value set in the theme config). |

---

## SameLine Widget

Forces the next widget onto the same horizontal line as the previous one, overriding the default behavior that places each widget on a new row.

```lua
Axios.Button({"Save Changes"})
Axios.SameLine()
Axios.Button({"Cancel Operation"})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Offset` | `number?` | The exact X-coordinate starting position for the next widget. |
| 2 | `Spacing` | `number?` | The horizontal pixel gap between the previous widget and the next one. |

---

## Group Widget

Combines multiple widgets into a single logical layout block. This allows multiple elements to behave as a single item for positioning and alignment across subsequent layout calls.

```lua
Axios.Group()
    Axios.Text({"Current Uptime:"})
    Axios.Text({"12:45:32"})
Axios.End() -- closes the logical group
```

**Common Pattern:** Wrap multiple widgets in a `Group` so they can collectively follow a `SameLine()` call or align together inside a table.
