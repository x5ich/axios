# Image and Texture Widgets

Axios provides specialized widgets for rendering standard Roblox asset textures, icons, and interactive visual elements.

---

## Image Widget

Displays an image from any valid Roblox asset identifier or temporary texture ID.

```lua
-- simple 100x100 texture display
Axios.Image({"rbxassetid://1234567890", UDim2.fromOffset(100, 100)})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Image` | `string` | The Roblox texture asset ID (e.g., `"rbxassetid://..."`). |
| 2 | `Size` | `UDim2` | The display dimensions of the image. |
| 3 | `Rect` | `Rect?` | Crop region for displaying a specific portion of the texture. |
| 4 | `ScaleType` | `Enum.ScaleType?` | Specifies how the image handles stretching and scaling. |
| 5 | `ResampleMode` | `Enum.ResampleMode?` | Texture sampling algorithm (e.g., `Pixelated` or `Linear`). |
| 6 | `TileSize` | `UDim2?` | The size of individual tiles for tiled scaling. |
| 7 | `SliceCenter` | `Rect?` | Nine-slice cropping region for responsive scaling. |
| 8 | `SliceScale` | `number?` | The scale factor for the nine-slice effect. |

### Interaction Events

Supported events: `hovered()`

---

## ImageButton Widget

Combines functionality from both [Image](#image-widget) and [Button](basic.md#button-widget) into a single, clickable graphical element.

```lua
local closeIcon = Axios.ImageButton({"rbxassetid://1234567890", UDim2.fromOffset(32, 32)})

-- trigger logic when the image is clicked
if closeIcon.clicked() then
    print("Dashboard closed.")
end
```

### Positional Arguments and Events

This widget supports all the standard parameters and event handlers from both the [Image](#image-widget) and [Button](basic.md#button-widget) documentation.
