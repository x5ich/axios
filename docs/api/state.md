# State Management

In an immediate-mode environment, the `Connect` callback executes every frame, meaning standard local variables are recreated on each pass. To handle persistent data, Axios uses state objects that remain consistent across render cycles, allowing widgets to read and write values seamlessly.

---

## Axios.State

This is the standard state object. The first time it's called, it creates a new state; subsequent calls with the same internal ID return the existing persistent object.

```lua
Axios:Connect(function()
    -- Initialize or retrieve the value for 'counter'
    local counter = Axios.State(0)
    
    -- Update the state value each frame
    counter:set(counter:get() + 1)
    
    Axios.Text({"Total Frames: " .. counter:get()})
end)
```

### State methods and properties

| Member | Description |
|---|---|
| `state.value` | Direct, raw access to the stored value. |
| `state:get()` | Retrieves the current state value. |
| `state:set(newValue)` | Updates the value and triggers updates for any connected widgets. |
| `state:onChange(callback)` | Registers a callback that fires whenever the state value is modified. |

---

## Axios.WeakState

Functionally identical to `Axios.State`, expect that it automatically reverts to its `initialValue` once no widgets are actively referencing it. This is ideal for ephemeral UI states that should not persist once the associated widgets are closed.

```lua
local tempValue = Axios.WeakState("Default Setting")
```

---

## Axios.VariableState

Binds an Axios state object to an existing local variable. You provide a callback that Axios triggers whenever the state changes, allowing you to synchronize the variable with the UI.

```lua
local playerSpeed = 16

Axios:Connect(function()
    -- Bind the UI state to our 'playerSpeed' variable
    local speedState = Axios.VariableState(playerSpeed, function(newValue)
        playerSpeed = newValue
    end)
    
    Axios.DragNum({"Walk Speed"}, {number = speedState})
end)
```

**Note:** If the local variable and the state object have conflicting values, the **local variable takes precedence**.

---

## Axios.TableState

Similar to `VariableState`, but specifically for keys within a Lua table. Since tables are passed by reference, Axios can update the table entry directly without requiring a manual callback.

```lua
local sessionData = { score = 100 }

Axios:Connect(function()
    -- Bind directly to 'sessionData.score'
    local scoreState = Axios.TableState(sessionData, "score")
    Axios.DragNum({"Current Score"}, {number = scoreState})
end)
-- sessionData.score is updated automatically on interaction
```

Using a callback for custom logic or validation:

```lua
local config = { audioEnabled = true }

local audioState = Axios.TableState(config, "audioEnabled", function(isEnabled)
    updateAudioEngine(isEnabled)
    return false -- prevents Axios from writing directly to the table
end)

Axios.Checkbox({"Toggle Sound"}, {isChecked = audioState})
```

---

## Axios.ComputedState

Computed states are read-only values derived from one or more parent states. They automatically recalculate their value whenever the source state changes.

```lua
local isVisible = Axios.State(true)
-- Invert the boolean value automatically
local isHidden = Axios.ComputedState(isVisible, function(v) return not v end)

local xp = Axios.State(500)
-- Create a formatted string from the raw number
local xpDisplay = Axios.ComputedState(xp, function(v) return "Experience: " .. v end)
```

---

## Binding States to Widgets

Most widgets accept a `states` table as the second argument. This enables two-way binding: the widget displays the current state and updates that state based on user interaction.

```lua
local toggleState = Axios.State(false)

-- Two-way binding: checking the box updates 'toggleState'
Axios.Checkbox({"Enable Feature"}, {isChecked = toggleState})

if toggleState:get() then
    Axios.Text({"Feature is currently active."})
end
```

---

## State Type Comparison

| Function | Persistence | Cleanup | Binding Type |
|---|---|---|---|
| `State` | Persistent | Manual | Internal Identifier (ID) |
| `WeakState` | Temporary | Automatic | Internal Identifier (ID) |
| `VariableState` | Supported | Manual | Local variable via callback |
| `TableState` | Supported | Manual | Table key reference |
| `ComputedState` | Automatic | Automatic | Derived from parent state |
