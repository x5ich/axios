# Custom Rendering Cycles

By default, `Axios:Init()` uses `RunService.Heartbeat` to drive the render loop. If you need finer control over when or how often Axios updates, you can provide a custom event or drive the cycle manually.

---

## Driving the cycle manually

To take full control, pass `false` as the second argument to `Init()`. This disables the automatic heartbeat, and you'll need to call `Axios.Internal._cycle(deltaTime)` yourself during your loop.

```lua
Axios:Init(nil, false) -- disables the automatic render loop

while true do
    -- manually trigger a render cycle with the elapsed time
    Axios.Internal._cycle(task.wait())
end
```

### Common use cases

- **Strict loop ordering:** Run Axios at a specific point in your script's execution pipeline.
- **Throttling:** Reduce the update frequency to every other frame or lock it to 30 FPS for performance.
- **Synchronized updates:** Ensure Axios updates precisely alongside your input handling or physics logic.

---

## Custom Events and Signals

You can also pass a standard Roblox event or any signal-like object to `Init()`. Axios will connect to this signal and execute a cycle every time it fires.

```lua
-- render only when RenderStepped fires
Axios:Init(nil, game:GetService("RunService").RenderStepped)

-- drive rendering with a custom BindableEvent
local mySignal = Instance.new("BindableEvent")
Axios:Init(nil, mySignal.Event)

while true do
    mySignal:Fire(task.wait())
end
```

### Using a function as a signal

If you provide a function instead of a signal, Axios handles the loop for you, calling your function and using its return value as the `deltaTime`.

```lua
Axios:Init(nil, function()
    -- the returned value is used as the cycle delta
    return task.wait() 
end)
```
