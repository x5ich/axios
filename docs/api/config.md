# Configuration & Styling

Axios implements a cascading configuration system, allowing you to modify styles globally or restrict them to specific sections of your UI using a push/pop stack.

---

## Axios.TemplateConfig

These pre-built style presets define the library's visual foundation. By default, Axios loads with a dark theme and standard sizing.

```lua
-- Apply standard styling presets
Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorDark)    -- dark mode
Axios.UpdateGlobalConfig(Axios.TemplateConfig.sizeDefault)   -- default widget sizing
Axios.UpdateGlobalConfig(Axios.TemplateConfig.utilityDefault) -- default utility layouts
```

Supported presets include `colorDark`, `colorLight`, `sizeDefault`, and `utilityDefault`.

---

## Axios.UpdateGlobalConfig(deltaStyle)

Use this to modify the appearance of every widget in the application. Calling this function internally triggers `ForceRefresh()`, causing the entire UI to be rebuilt with the new parameters.

```lua
-- completely switch the library to light mode
Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorLight)

-- or manually override individual properties
Axios.UpdateGlobalConfig({
    TextColor = Color3.fromRGB(230, 230, 230),
    WindowBgColor = Color3.fromRGB(25, 25, 35),
})
```

**CAUTION:** Do not call this function within a high-frequency loop (like your render cycle). It is computationally expensive as it destroys and regenerates every active UI component.

---

## Local Scoping: PushConfig and PopConfig

Rather than global changes, you can scope style overrides to specific segments of your UI. Any widgets declared between `PushConfig` and `PopConfig` inherit these overrides, and the configuration stack supports proper nesting.

```lua
Axios.Text({"Default appearance."})

Axios.PushConfig({TextColor = Color3.fromRGB(255, 100, 100)})
    Axios.Text({"This text is now red."})

    Axios.PushConfig({TextColor = Color3.fromRGB(100, 255, 100)})
        Axios.Text({"This nested text is now green."})
    Axios.PopConfig()

    Axios.Text({"Returning to the previous red scope."})
Axios.PopConfig()

Axios.Text({"Back to global default styling."})
```

**REMINDER:** Every `PushConfig` call must be eventually matched with a `PopConfig` call to prevent stack overflow issues.

---

## Axios.ForceRefresh()

Triggers a complete demolition and regeneration of all active widget instances in the next render cycle. Use this sparingly, typically after significant global style changes.

```lua
Axios.ForceRefresh()
```

---

## Axios.Args

For improved code readability, use the `Axios.Args` lookup table. This allows you to provide descriptive keys for widget arguments instead of relying on fixed positions.

```lua
-- Example: Creating a window that cannot be resized
Axios.Window({"Locked Window", [Axios.Args.Window.NoResize] = true})
```

---

## Common Configuration Tokens

While many more exist within the theme system, these are the style tokens you will interact with most frequently:

| Key | Type | Description |
|---|---|---|
| `TextColor` | `Color3` | The default color for all text-based widgets. |
| `TextSize` | `number` | The base font size for text elements. |
| `WindowBgColor` | `Color3` | Background color for window frames. |
| `WindowBgTransparency` | `number` | Transparency of the window background. |
| `ItemWidth` | `UDim` | The default width for inputs, sliders, and drag widgets. |
| `ItemSpacing` | `Vector2` | The layout gap (vertical and horizontal) between adjacent widgets. |
| `IndentSpacing` | `number` | The pixel-width used for the `Indent()` widget. |
| `TextWrapped` | `boolean` | Globally enables or disables text wrapping. |
| `RichText` | `boolean` | Globally enables or disables RichText formatting. |
