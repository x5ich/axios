# Tree and Collapsible Widgets

Axios provides hierarchical tree nodes and collapsible headers to organize your UI into dynamic, expandable sections.

---

## Tree Widget

A standard, nestable collapsible node that supports child widgets.

```lua
Axios.Tree({"Primary Module"})
    Axios.Text({"Content for the primary module."})
    
    Axios.Tree({"Sub-module B"})
        Axios.Text({"Even deeper nested content."})
    Axios.End() -- closes Sub-module B
Axios.End() -- closes Primary Module
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The label displayed for the tree node. |
| 2 | `Span` | `boolean?` | If true, clicking anywhere on the entire row will toggle the tree's expansion. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `isUncollapsed` | `State<boolean>?` | Tracks whether the node is currently expanded. |

### Interaction Events

Supported events: `opened()`, `closed()`, `collapsed()`, `uncollapsed()`, `hovered()`

---

## CollapsingHeader Widget

Functionally identical to a [Tree](#tree-widget), but styled as a full-width header bar. This is a common pattern for top-level category dividers.

```lua
Axios.CollapsingHeader({"Advanced System Configurations"})
    Axios.Checkbox({"Experimental Features"}, {isChecked = expState})
Axios.End() -- explicitly close the header container
```

### Parameters and Events

The `CollapsingHeader` uses the same arguments, states, and event handlers as the standard [Tree Widget](#tree-widget).

---

## Performance Pattern: Conditional Child Rendering

For sections containing a large number of widgets, you can optimize performance by skipping child declarations when the tree is collapsed.

```lua
local heavyTree = Axios.Tree({"Heavy Asset Load"})

-- Only process the internal loop if the section is expanded
if heavyTree.state.isUncollapsed.value then
    for i = 1, 100 do
        Axios.Text({"Asset entry ID: " .. i})
    end
end

-- Remember: The container must be formally closed regardless of its expansion state
Axios.End()
```
