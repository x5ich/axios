# API Reference

An overview of everything Axios exposes. Each section provides more comprehensive details on its own dedicated documentation page.

---

## Core Lifecycle Functions

| Function | Description |
|---|---|
| [`Axios:Init()`](initialize.md) | Initial setup of the library, driving the render engine and ScreenGui creation. |
| [`Axios.Shutdown()`](lifecycle.md) | Gracefully shuts down Axios and cleans up UI assets. |
| [`Axios:Connect(callback)`](lifecycle.md) | The main entry point for your UI logic; hooks your code into the render loop. |
| [`Axios.Append(instance)`](lifecycle.md) | Injects a pre-existing, raw Roblox GUI instance into the current Axios container. |
| [`Axios.End()`](lifecycle.md) | Closes the most recently opened container widget (Window, Tree, Tab, etc.). |
| [`Axios.ShowDemoWindow()`](lifecycle.md) | Displays a comprehensive demo window showing every widget in the library. |

---

## State Management

| Function | Description |
|---|---|
| [`Axios.State(value)`](state.md) | Creates a persistent state object that remains consistent across render frames. |
| [`Axios.WeakState(value)`](state.md) | A state object that automatically resets to its default value when no longer in use. |
| [`Axios.VariableState(var, cb)`](state.md) | Synchronizes an Axios state object with an existing local variable. |
| [`Axios.TableState(tbl, key, cb?)`](state.md) | Links state directly to a value in a provided Lua table. |
| [`Axios.ComputedState(state, fn)`](state.md) | Creates a read-only state derived from one or more parent state objects. |

---

## Configuration & Styling

| Function | Description |
|---|---|
| [`Axios.UpdateGlobalConfig(delta)`](config.md) | Modifies library-wide style tokens (colors, fonts, sizes). |
| [`Axios.PushConfig(delta)`](config.md) | Opens a local configuration scope, applying specific styles to nested widgets. |
| [`Axios.PopConfig()`](config.md) | Closes a local configuration scope, reverting styles to the previous state. |
| [`Axios.ForceRefresh()`](config.md) | Re-renders every active widget; useful for full theme swaps. |
| [`Axios.TemplateConfig`](config.md) | A collection of built-in styling presets (e.g., Light and Dark modes). |

---

## ID Scoping

| Function | Description |
|---|---|
| [`Axios.PushId(id)`](id.md) | Enters a custom ID namespace for generating unique widget identifiers. |
| [`Axios.PopId()`](id.md) | Exits the current custom ID namespace. |
| [`Axios.SetNextWidgetID(id)`](id.md) | Manually forces the ID of the next widget to be created. |

---

## Public Properties

| Property | Type | Description |
|---|---|---|
| `Axios.Disabled` | `boolean` | When set to `true`, Axios ignores rendering and input processing. |
| `Axios.Args` | `table` | Metadata storage for named widget argument mapping. |
| `Axios.Internal` | `Internal` | Low-level engine internals; use with caution. |
