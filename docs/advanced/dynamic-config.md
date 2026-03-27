# Dynamic Configuration

Axios allows you to change the entire library's look and feel on the fly. This includes switching themes, overriding individual colors, and modifying fonts dynamically.

---

## TemplateConfig

You can use `TemplateConfig` to quickly swap out built-in themes and sizes.

```lua
-- apply global light mode
Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorLight)

-- reset back to default dark mode
Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorDark)
Axios.UpdateGlobalConfig(Axios.TemplateConfig.sizeDefault)
Axios.UpdateGlobalConfig(Axios.TemplateConfig.utilityDefault)
```

**Note:** Avoid calling `UpdateGlobalConfig` every frame. It triggers a full UI rebuild, which can be computationally expensive.

---

## Local Style Overrides

For more granular control, use `PushConfig` and `PopConfig`. This is the recommended approach for styling individual widgets or small sections of your UI.

```lua
local isHovering = Axios.State(false)

Axios.PushConfig({
    -- Change the button color based on its hovering state
    ButtonBgColor = isHovering:get() and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
})
    local btn = Axios.Button({"Dynamic Style"})
    isHovering:set(btn.hovered())
Axios.PopConfig()
```

### Cascading Styles

Configurations merge as you nest them, allowing for modular styling.

```lua
-- Apply red text globally
Axios.PushConfig({TextColor = Color3.new(1, 0, 0)})
    Axios.Text({"Red Text"})
    
    -- Increase text size inside the current scope (still red)
    Axios.PushConfig({TextSize = 25})
        Axios.Text({"Big Red Text"})
    Axios.PopConfig()
Axios.PopConfig()
```

---

## Pattern: Global Theme Management

A standard pattern for managing custom themes is to store overrides in a table and swap them as needed.

```lua
local themes = {
    Dracula = {
        WindowBgColor = Color3.fromRGB(40, 42, 54),
        TextColor = Color3.fromRGB(248, 248, 242),
    },
    Monokai = {
        WindowBgColor = Color3.fromRGB(39, 40, 34),
        TextColor = Color3.fromRGB(248, 248, 242),
    }
}

-- Switch to the Monokai theme
local currentTheme = themes.Monokai
Axios.UpdateGlobalConfig(currentTheme)
```
