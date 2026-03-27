# Recipes & Design Patterns

Common practical tasks and layout patterns in Axios.

---

## Multiple Windows

Axios can handle as many windows as you need. Each window is simply declared during the render cycle.

```lua
Axios:Connect(function()
    Axios.Window({"Window 1"})
        Axios.Text({"Content for the first window."})
    Axios.End()

    Axios.Window({"Window 2"})
        Axios.Text({"Content for the second window."})
    Axios.End()
end)
```

By default, windows stack in the order they were first created. Use `Axios.SetFocusedWindow(win)` to programmatically bring a specific window to the front.

---

## Centering a Window

The window `position` state defaults to the center of the screen on its first frame. To force a window to center, you can manually override its position state.

```lua
-- Central position assuming 1080p resolution
local pos = Axios.State(Vector2.new(960, 540))

Axios.Window({"Centered Window"}, {position = pos})
Axios.End()
```

---

## Dynamic Tab Content and Performance

Tabs only render their child widgets when they are active. This is an efficient way to manage performance in heavy UIs with many elements.

```lua
Axios.TabBar()
    Axios.Tab({"Performance"})
        -- These widgets only update while the "Performance" tab is active.
        for i = 1, 100 do
            Axios.Text({"FPS: " .. math.random(60)})
        end
    Axios.End()

    Axios.Tab({"Other Settings"})
        Axios.Checkbox({"Enable Sound"})
    Axios.End()
Axios.End()
```

---

## Custom Layouts with Group and SameLine

Use the `Group` and `SameLine` widgets to build more complex, multi-column layouts.

```lua
Axios.Group()
    Axios.Text({"Label A:"})
    Axios.SameLine()
    Axios.InputText({"Value A"})
Axios.End()

Axios.Group()
    Axios.Text({"Label B:"})
    Axios.SameLine()
    Axios.InputText({"Value B"})
Axios.End()
```

---

## ID Overrides in Loops

When generating widgets inside a loop, always push a unique ID. If you don't, Axios can't distinguish between the widgets, leading to buggy behavior.

```lua
for i, item in ipairs(myData) do
    Axios.PushId("item_" .. i)
        -- The unique ID ensures each checkbox behaves independently
        Axios.Checkbox({item.name}, {isChecked = item.enabled})
    Axios.PopId()
end
```

Without `PushId`, all checkboxes would share the same automatically generated ID, causing them to all toggle simultaneously.
