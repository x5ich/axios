# Table Widget

The `Table` widget provides a grid-based layout system with full support for configurable columns, rows, headers, and cell borders. It allows for precise control over column widths and interactive resizing.

---

## Creating a Table

A table is initialized by defining the number of columns and its visual properties. Content is then distributed across cells using navigation functions like `NextColumn` and `NextRow`.

```lua
-- Table setup: 3 columns with headers, row backgrounds, and all borders enabled
Axios.Table({3, true, true, true, true})

    -- Define the header row first
    Axios.SetHeaderColumnIndex(1)
    Axios.Text({"Username"})
    Axios.NextHeaderColumn()
    Axios.Text({"Experience"})
    Axios.NextHeaderColumn()
    Axios.Text({"Global Rank"})

    -- Populate the table with dynamic data
    for i, player in ipairs(currentPlayers) do
        -- Each call to NextColumn moves to the following cell in the grid
        Axios.NextColumn()
        Axios.Text({player.name})
        
        Axios.NextColumn()
        Axios.Text({tostring(player.xp)})
        
        Axios.NextColumn()
        Axios.Text({tostring(player.rank)})
    end

Axios.End() -- explicitly close the table container
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `NumColumns` | `number` | The total number of columns (static after creation). |
| 2 | `Header` | `boolean?` | When true, renders a dedicated header row at the top. |
| 3 | `RowBackground` | `boolean?` | Toggles alternating background colors for row visibility. |
| 4 | `OuterBorders` | `boolean?` | Displays a border around the entire table frame. |
| 5 | `InnerBorders` | `boolean?` | Displays borders between individual rows and columns. |
| 6 | `Resizable` | `boolean?` | Allows users to manually drag and adjust column widths. |
| 7 | `FixedWidth` | `boolean?` | Uses fixed pixel dimensions instead of proportional scaling. |
| 8 | `ProportionalWidth`| `boolean?` | Automatically scales columns proportionally based on content. |

---

## Table Navigation and Placement

Use these functions to control exactly where UI elements are placed within the table's grid system.

- **`Axios.NextColumn()`**: Advances to the next cell. If the current row is full, it automatically wraps to the first column of a new row.
- **`Axios.NextRow()`**: Immediately starts a new row, placing the cursor back in the first column.
- **`Axios.SetColumnIndex(index)`**: Moves the current cursor to a specific column (1-indexed) within the active row.
- **`Axios.SetHeaderColumnIndex(index)`**: Targets a specific column index within the header row scope.
- **`Axios.SetColumnWidth(index, width)`**: Overrides the width of a specific column. Use a decimal (0.0–1.0) for proportional scaling, or a value greater than 2 for fixed pixel width.

---

## Implementation Pattern: Dynamic Column Counts

Since the number of columns in a table is static once initialized, you must trigger a UI rebuild if your data requires a different column count. This is easily achieved by wrapping the table in a configuration scope.

```lua
local dynamicColCount = 5

-- Forcing a full table refresh to accommodate the new column count
Axios.PushConfig({columns = dynamicColCount})
    Axios.Table({dynamicColCount, true})
        -- populate with dynamic columns...
    Axios.End()
Axios.PopConfig()
```
