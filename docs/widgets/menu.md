# Menu and Navigation Widgets

Axios supports desktop-style menu bars and interactive dropdown systems, typically placed at the top of a window for application-wide navigation and settings.

---

## MenuBar Widget

Creates the primary menu strip context. This must be the first widget declared within a `Window` scope, before any other interactive elements.

```lua
Axios.Window({"Application Shell"})
    Axios.MenuBar()
        -- Individual menus and toggles are declared here
    Axios.End()
Axios.End()
```

The `MenuBar` acts purely as a layout container and does not accept arguments or triggers.

---

## Menu Widget

A standard dropdown menu that expands when clicked. Menus can contain nested `MenuItems`, `MenuToggles`, or even other `Menu` widgets for hierarchical sub-menu structures.

```lua
Axios.Menu({"File Options"})
    Axios.MenuItem({"New Project"})
    Axios.Menu({"Recent Projects"})
        -- Nested sub-menu for project history
        Axios.MenuItem({"alpha_build.lua"})
        Axios.MenuItem({"stable_release.lua"})
    Axios.End()
Axios.End()
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The descriptive label for the menu dropdown. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `isOpened` | `State<boolean>?` | Tracks the visibility/open status of the dropdown. |

### Interaction Events

Supported events: `clicked()`, `opened()`, `closed()`, `hovered()`

---

## MenuItem Widget

A standard button component specifically styled for use within a menu or sub-menu.

```lua
local saveProject = Axios.MenuItem({"Save Database", Enum.KeyCode.S, Enum.ModifierKey.Ctrl})

-- trigger logic when the menu item is clicked
if saveProject.clicked() then
    commitDatabaseChanges()
end
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The label displayed inside the menu item. |
| 2 | `KeyCode` | `Enum.KeyCode?` | A visual shortcut key label (display only). |
| 3 | `ModifierKey` | `Enum.ModifierKey?` | A visual modifier key label (display only). |

**Note:** The `KeyCode` and `ModifierKey` arguments strictly serve as visual indicators and do not automatically bind keyboard shortcuts to the action.

### Interaction Events

Supported events: `clicked()`, `hovered()`

---

## MenuToggle Widget

A specialized toggle element within a menu, functionally identical to a [Checkbox](basic.md#checkbox-widget) but optimized for menu row formatting.

```lua
local isAutoSaveActive = Axios.State(true)

-- Bound directly to the auto-save state
Axios.MenuToggle({"Enable Auto-Save"}, {isChecked = isAutoSaveActive})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The descriptive label for the toggle. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `isChecked` | `State<boolean>?` | The underlying boolean state being toggled. |

### Interaction Events

Supported events: `checked()`, `unchecked()`, `hovered()`

---

## Comprehensive Implementation Example

Building a functional editor menu system.

```lua
Axios.Window({"Script Editor"})
    Axios.MenuBar()
        -- The primary 'File' navigation
        Axios.Menu({"File"})
            if Axios.MenuItem({"New Archive"}).clicked() then resetWorkspace() end
            if Axios.MenuItem({"Quick Save", Enum.KeyCode.S, Enum.ModifierKey.Ctrl}).clicked() then saveWorkspace() end
            
            Axios.Separator() -- visual divider for safety
            
            if Axios.MenuItem({"Shutdown Editor"}).clicked() then Axios.Shutdown() end
        Axios.End()

        -- Application 'View' settings
        Axios.Menu({"View"})
            Axios.MenuToggle({"Dark Visuals"}, {isChecked = darkModeState})
            Axios.MenuToggle({"Display Console"}, {isChecked = consoleVisibleState})
        Axios.End()
    Axios.End()
Axios.End()
```
