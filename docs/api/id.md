# ID Management and Scoping

Axios automatically tracks widgets by generating unique IDs derived from the Lua call stack. While this standard approach works for most conventional UIs, certain implementation patterns require manual control over the ID generation process.

---

## Scoping with PushId and PopId

When generating widgets inside a loop, Axios may assign identical IDs to each iteration, potentially leading to state-related bugs. To resolve this, wrap each iteration with `PushId` using a unique key or index.

```lua
for i = 1, 10 do
    Axios.PushId("button_item_" .. i)
        -- each button now possesses a truly unique identifier
        Axios.Button({"Action " .. i})
    Axios.PopId()
end
```

**IMPORTANT:** Every `PushId` must be correctly closed with a matching `PopId` to maintain the integrity of the identifier stack.

---

## Overriding IDs with SetNextWidgetID

Use `SetNextWidgetID` when you need to manually specify the identifier for the very next widget created. This is particularly useful when you want to append content to the same widget from disparate locations in your codebase.

```lua
-- In the first script
Axios.SetNextWidgetID("unified_interface")
Axios.Window({"Main Dashboard"})
    Axios.Text({"Core system status: Operational."})
Axios.End()

-- In a completely separate script
Axios.SetNextWidgetID("unified_interface")
Axios.Window() -- targets the existing window from the first script
    Axios.Text({"Additional logs loaded."})
Axios.End()
```

In this example, both `Text` components will render within the same single "Main Dashboard" window, regardless of where they were declared.

---

## Practical Applications

| Scenario | Solution |
|---|---|
| Creating widgets inside a `for` loop | Use `PushId` with the loop index or a unique key. |
| Accessing the same widget across different modules | Use `SetNextWidgetID` with a persistent, shared string. |
| Generating UI elements from dynamic data | Use `PushId` with the data's unique key or ID field. |
| Overriding default auto-generation | Use either `PushId` for a block or `SetNextWidgetID` for a single widget. |
