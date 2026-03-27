# Widgets

Axios provides a comprehensive set of widgets specifically designed for building complex and performant user interfaces. Remember that all widgets must be declared within a [Window](window.md) or a top-level container.

---

## Widget Categories

| Category | Widget List | Primary Purpose |
|---|---|---|
| [Windows](window.md) | Window, Tooltip | Root containers and contextual popups. |
| [Basic](basic.md) | Button, SmallButton, Checkbox, RadioButton | Core interactive elements for clicks and toggles. |
| [Text](text.md) | Text, SeparatorText, InputText | Labels, text formatting, and string data entry. |
| [Image](image.md) | Image, ImageButton | Rendering Roblox assets, textures, and icons. |
| [Menu](menu.md) | MenuBar, Menu, MenuItem, MenuToggle | Desktop-style navigation bars and dropdown menus. |
| [Format](format.md) | Separator, Indent, SameLine, Group | Advanced layout management and positioning. |
| [Tree](tree.md) | Tree, CollapsingHeader | Hierarchical data and collapsible sections. |
| [Tab](tab.md) | TabBar, Tab | Horizontal navigation bars for switching views. |
| [Input](input-widgets.md) | InputNum, InputVector, InputUDim, InputRect, InputColor | Type-specific numeric entry fields. |
| [Drag](drag.md) | DragNum, DragVector, DragUDim, DragRect | Interaction via click-and-drag for numeric types. |
| [Slider](slider.md) | SliderNum, SliderVector, SliderUDim, SliderRect | Constrained visual sliders for value selection. |
| [Combo](combo.md) | Selectable, Combo, ComboArray, ComboEnum | Dropdown selections and list picking. |
| [Plot](plot.md) | ProgressBar, PlotLines, PlotHistogram | Data visualization and status indication. |
| [Table](table.md) | Table, NextColumn, NextRow | Multi-column grid systems and complex layouts. |

---

## Widget Structure and Syntax

All Axios widget calls follow a consistent implementation pattern:

```lua
local widget = Axios.WidgetName(arguments?, states?)
```

- **`arguments`**: A table containing the widget's positional parameters (e.g., `{"Click Me", Vector2.new(120, 40)}`).
- **`states`**: An optional table of named state objects used for two-way data binding (e.g., `{isChecked = myRef}`).

The object returned by the widget call provides access to various **events** (boolean status functions):

```lua
if Axios.Button({"Apply Changes"}).clicked() then
    -- perform the logic here
end
```

---

## Widget Metadata and Tags

These tags indicate specific functional requirements or capabilities for a widget:

| Tag | Requirement |
|---|---|
| `HasChildren` | This is a container widget and must be explicitly closed with `Axios.End()`. |
| `HasState` | This widget supports two-way data binding through the `states` argument table. |
