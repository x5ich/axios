# Text Presentation and Input Widgets

Axios provides specialized text widgets for displaying static information, structural section headers, and capturing string data from the user.

---

## Text Widget (Label)

The primary widget for displaying static or dynamic text information. It supports wrapping, custom coloring, and Roblox-standard RichText formatting.

```lua
-- Simple message display
Axios.Text({"System successfully initialized."})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The string content to be displayed. |
| 2 | `Wrapped` | `boolean?` | If true, automatically wraps text to fit the parent container's width. |
| 3 | `Color` | `Color3?` | Overrides the default text color with a custom `Color3` value. |
| 4 | `RichText` | `boolean?` | Enables standard Roblox RichText formatting tags (e.g., `<b>`, `<i>`). |

### Interaction Events

Supported events: `hovered()`

### Implementation Example: Status Messages

```lua
-- Using inline coloring for status feedback
Axios.Text({"Critical Alert!", nil, Color3.fromRGB(255, 45, 45)})
Axios.Text({"Operational Status: OK", nil, Color3.fromRGB(45, 255, 45)})
```

---

## SeparatorText Widget

Renders a horizontal rule with a centered text label clipping through the middle. This is the recommended pattern for defining new sections within a window.

```lua
Axios.SeparatorText({"Module Configuration"})
-- ... widget fields following the separator ...
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string` | The title text displayed in the center of the separator. |

---

## InputText Widget

A dedicated field that allows users to type and edit string-based information.

```lua
local userProfileName = Axios.State("Guest")

-- Bind the input field directly to our profile state
Axios.InputText({"Profile Name:", "Enter your name here..."}, {text = userProfileName})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string?` | A descriptive label displayed beside the input field. |
| 2 | `TextHint` | `string?` | Placeholder text shown when the input field is empty. |
| 3 | `ReadOnly` | `boolean?` | Prevents the user from modifying the text content. |
| 4 | `MultiLine` | `boolean?` | Allows the user to enter and edit multiple lines of text. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `text` | `State<string>` | The persistent state object that tracks the current text content. |

### Interaction Events

Supported events: `textChanged()`, `hovered()`

---

## Migration and Deprecation Notes

For users upgrading from older versions of the library, please note the following changes:

- **`TextWrapped` (Removed in v2.0.0):** Please use the standard `Text` widget with the `Wrapped` argument set to `true`.
- **`TextColored` (Removed in v2.0.0):** Please use the standard `Text` widget with a custom `Color3` provided in the third argument.
