# Axios UI Library for Roblox Exploits

## Usage

In your exploit script:

```lua
local Axios = loadstring(game:HttpGet("https://load.axios.x5i.ch"))()

Axios:Init()

Axios:Connect(function()
    Axios.Window({"Axios UI Demo"})
        Axios.Text({"Hello, users."})
        Axios.Button({"Save Changes"})
    Axios.End()
end)
```

## Features
- **Standalone**: All-in-one bundle, no game hierarchy dependencies.
- **Supports Method Call**: `Axios:Init()` works seamlessly.
- **Global Table**: Automatically assigns to `getgenv().Axios`.

## Credits
- Maintained as **Axios** by x5ich.

---

[AI-friendly documentation available in llms.txt](llms.txt)
