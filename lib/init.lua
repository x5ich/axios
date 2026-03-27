--!optimize 2
local Types = require(script.Types)

--[=[
    @class Axios

    Axios; contains the all user-facing functions and properties.
    A set of internal functions can be found in `Axios.Internal` (only use if you understand).

    In its simplest form, users may start Axios by using
    ```lua
    Axios.Init()

    Axios:Connect(function()
        Axios.Window({"My First Window!"})
            Axios.Text({"Hello, World"})
            Axios.Button({"Save"})
            Axios.InputNum({"Input"})
        Axios.End()
    end)
    ```
]=]
local Axios = {} :: Types.Axios

local Internal: Types.Internal = require(script.Internal)(Axios)

--[=[
    @within Axios
    @prop Disabled boolean

    While Axios.Disabled is true, execution of Axios and connected functions will be paused.
    The widgets are not destroyed, they are just frozen so no changes will happen to them.
]=]
Axios.Disabled = false

--[=[
    @within Axios
    @prop Args { [string]: { [string]: any } }

    Provides a list of every possible Argument for each type of widget to it's index.
    For instance, `Axios.Args.Window.NoResize`.
    The Args table is useful for using widget Arguments without remembering their order.
    ```lua
    Axios.Window({"My Window", [Axios.Args.Window.NoResize] = true})
    ```
]=]
Axios.Args = {}

--[=[
    @ignore
    @within Axios
    @prop Events table

    -todo: work out what this is used for.
]=]
Axios.Events = {}

--[=[
    @within Axios
    @function Init
    @param parentInstance Instance? -- where Axios will place widgets UIs under, defaulting to [PlayerGui]
    @param eventConnection (RBXScriptSignal | () -> () | false)? -- the event to determine an Axios cycle, defaulting to [Heartbeat]
    @param allowMultipleInits boolean? -- allows subsequent calls 'Axios.Init()' to do nothing rather than error about initialising again, defaulting to false
    @return Axios

    Initializes Axios and begins rendering. Can only be called once.
    See [Axios.Shutdown] to stop Axios, or [Axios.Disabled] to temporarily disable Axios.

    Once initialized, [Axios:Connect] can be used to create a widget.

    If the `eventConnection` is `false` then Axios will not create a cycle loop and the user will need to call [Internal._cycle] every frame.
]=]
function Axios.Init(parentInstance: BasePlayerGui | GuiBase2d?, eventConnection: (RBXScriptSignal | (() -> number) | false)?, allowMultipleInits: boolean): Types.Axios
    assert(Internal._shutdown == false, "Axios.Init() cannot be called once shutdown.")
    assert(Internal._started == false or allowMultipleInits == true, "Axios.Init() can only be called once.")

    if Internal._started then
        return Axios
    end

    if parentInstance == nil then
        -- coalesce to playerGui
        parentInstance = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end
    if eventConnection == nil then
        -- coalesce to Heartbeat
        eventConnection = game:GetService("RunService").Heartbeat
    end
    Internal.parentInstance = parentInstance :: BasePlayerGui | GuiBase2d
    Internal._started = true

    Internal._generateRootInstance()
    Internal._generateSelectionImageObject()

    for _, callback in Internal._initFunctions do
        callback()
    end

    -- spawns the connection to call `Internal._cycle()` within.
    task.spawn(function()
        if typeof(eventConnection) == "function" then
            while Internal._started do
                local deltaTime = eventConnection()
                Internal._cycle(deltaTime)
            end
        elseif eventConnection ~= nil and eventConnection ~= false then
            Internal._eventConnection = eventConnection:Connect(function(...)
                Internal._cycle(...)
            end)
        end
    end)

    return Axios
end

--[=[
    @within Axios
    @function Shutdown

    Shuts Axios down. This can only be called once, and Axios cannot be started once shut down.
]=]
function Axios.Shutdown()
    Internal._started = false
    Internal._shutdown = true

    if Internal._eventConnection then
        Internal._eventConnection:Disconnect()
    end
    Internal._eventConnection = nil

    if Internal._rootWidget then
        if Internal._rootWidget.Instance then
            Internal._widgets["Root"].Discard(Internal._rootWidget)
        end
        Internal._rootInstance = nil
    end

    if Internal.SelectionImageObject then
        Internal.SelectionImageObject:Destroy()
    end

    for _, connection in Internal._connections do
        connection:Disconnect()
    end
end

--[=[
    @within Axios
    @method Connect
    @param callback () -> () -- the callback containg the Axios code
    @return () -> () -- call to disconnect it

    Connects a function which will execute every Axios cycle. [Axios.Init] must be called before connecting.

    A cycle is determined by the `eventConnection` passed to [Axios.Init] (default to [RunService.Heartbeat]).

    Multiple callbacks can be added to Axios from many different scripts or modules.
]=]
function Axios:Connect(callback: () -> ()): () -> () -- this uses method syntax for no reason.
    if Internal._started == false then
        warn("Axios:Connect() was called before calling Axios.Init(); always initialise Axios first.")
    end
    local connectionIndex = #Internal._connectedFunctions + 1
    Internal._connectedFunctions[connectionIndex] = callback
    return function()
        Internal._connectedFunctions[connectionIndex] = nil
    end
end

--[=[
    @within Axios
    @function Append
    @param userInstance GuiObject -- the Roblox [Instance] to insert into Axios

    Inserts any Roblox [Instance] into Axios.

    The parent of the inserted instance can either be determined by the `_config.Parent`
    property or by the current parent widget from the stack.
]=]
function Axios.Append(userInstance: GuiObject)
    local parentWidget = Internal._GetParentWidget()
    local widgetInstanceParent: GuiObject
    if Internal._config.Parent then
        widgetInstanceParent = Internal._config.Parent :: any
    else
        widgetInstanceParent = Internal._widgets[parentWidget.type].ChildAdded(parentWidget, { type = "userInstance" } :: Types.Widget)
    end
    userInstance.Parent = widgetInstanceParent
end

--[=[
    @within Axios
    @function End

    Marks the end of any widgets which contain children. For example:
    ```lua
    -- Widgets placed here **will not** be inside the tree
    Axios.Text({"Above and outside the tree"})

    -- A Tree widget can contain children.
    -- We must therefore remember to call `Axios.End()`
    Axios.Tree({"My First Tree"})
        -- Widgets placed here **will** be inside the tree
        Axios.Text({"Tree item 1"})
        Axios.Text({"Tree item 2"})
    Axios.End()

    -- Widgets placed here **will not** be inside the tree
    Axios.Text({"Below and outside the tree"})
    ```
    :::caution Caution: Error
    Seeing the error `Callback has too few calls to Axios.End()` or `Callback has too many calls to Axios.End()`?
    Using the wrong amount of `Axios.End()` calls in your code will lead to an error.

    Each widget called which might have children should be paired with a call to `Axios.End()`, **even if the Widget doesnt currently have any children**.
    :::
]=]
function Axios.End()
    if Internal._stackIndex == 1 then
        error("Too many calls to Axios.End().", 2)
    end

    Internal._IDStack[Internal._stackIndex] = nil
    Internal._stackIndex -= 1
end

--[[
    ------------------------
        [SECTION] Config
    ------------------------
]]

--[=[
    @within Axios
    @function ForceRefresh

    Destroys and regenerates all instances used by Axios. Useful if you want to propogate state changes.
    :::caution Caution: Performance
    Because this function Deletes and Initializes many instances, it may cause **performance issues** when used with many widgets.
    In **no** case should it be called every frame.
    :::
]=]
function Axios.ForceRefresh()
    Internal._globalRefreshRequested = true
end

--[=[
    @within Axios
    @function UpdateGlobalConfig
    @param deltaStyle { [string]: any } -- a table containing the changes in style ex: `{ItemWidth = UDim.new(0, 100)}`

    Customizes the configuration which **every** widget will inherit from.

    It can be used along with [Axios.TemplateConfig] to easily swap styles, for example:
    ```lua
    Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorLight) -- use light theme
    ```
    :::caution Caution: Performance
    This function internally calls [Axios.ForceRefresh] so that style changes are propogated.

    As such, it may cause **performance issues** when used with many widgets.
    In **no** case should it be called every frame.
    :::
]=]
function Axios.UpdateGlobalConfig(deltaStyle: { [string]: any })
    for index, style in deltaStyle do
        Internal._rootConfig[index] = style
    end
    Axios.ForceRefresh()
end

--[=[
    @within Axios
    @function PushConfig
    @param deltaStyle { [string]: any } -- a table containing the changes in style ex: `{ItemWidth = UDim.new(0, 100)}`

    Allows cascading of a style by allowing styles to be locally and hierarchically applied.

    Each call to Axios.PushConfig must be paired with a call to [Axios.PopConfig], for example:
    ```lua
    Axios.Text({"boring text"})

    Axios.PushConfig({TextColor = Color3.fromRGB(128, 0, 256)})
        Axios.Text({"Colored Text!"})
    Axios.PopConfig()

    Axios.Text({"boring text"})
    ```
]=]
function Axios.PushConfig(deltaStyle: { [string]: any })
    local ID = Axios.State(-1)
    if ID.value == -1 then
        ID:set(deltaStyle)
    else
        -- compare tables
        if Internal._deepCompare(ID:get(), deltaStyle) == false then
            -- refresh local
            ID:set(deltaStyle)
            Internal._refreshStack[Internal._refreshLevel] = true
            Internal._refreshCounter += 1
        end
    end
    Internal._refreshLevel += 1

    Internal._config = setmetatable(deltaStyle, {
        __index = Internal._config,
    }) :: any
end

--[=[
    @within Axios
    @function PopConfig

    Ends a [Axios.PushConfig] style.

    Each call to [Axios.PopConfig] should match a call to [Axios.PushConfig].
]=]
function Axios.PopConfig()
    Internal._refreshLevel -= 1
    if Internal._refreshStack[Internal._refreshLevel] == true then
        Internal._refreshCounter -= 1
        Internal._refreshStack[Internal._refreshLevel] = nil
    end

    Internal._config = getmetatable(Internal._config :: any).__index
end

--[=[

    @within Axios
    @prop TemplateConfig { [string]: { [string]: any } }

    TemplateConfig provides a table of default styles and configurations which you may apply to your UI.
]=]
Axios.TemplateConfig = require(script.config)
Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorDark) -- use colorDark and sizeDefault themes by default
Axios.UpdateGlobalConfig(Axios.TemplateConfig.sizeDefault)
Axios.UpdateGlobalConfig(Axios.TemplateConfig.utilityDefault)
Internal._globalRefreshRequested = false -- UpdatingGlobalConfig changes this to true, leads to Root being generated twice.

--[[
    --------------------
        [SECTION] ID
    --------------------
]]

--[=[
    @within Axios
    @function PushId
    @param id ID -- custom id

    Pushes an id onto the id stack for all future widgets. Use [Axios.PopId] to pop it off the stack.
]=]
function Axios.PushId(ID: Types.ID)
    assert(typeof(ID) == "string", "The ID argument to Axios.PushId() to be a string.")

    Internal._newID = true
    table.insert(Internal._pushedIds, ID)
end

--[=[
    @within Axios
    @function PopID

    Removes the most recent pushed id from the id stack.
]=]
function Axios.PopId()
    if #Internal._pushedIds == 0 then
        return
    end

    table.remove(Internal._pushedIds)
end

--[=[
    @within Axios
    @function SetNextWidgetID
    @param id ID -- custom id.

    Sets the id for the next widget. Useful for using [Axios.Append] on the same widget.
    ```lua
    Axios.SetNextWidgetId("demo_window")
    Axios.Window({ "Window" })
        Axios.Text({ "Text one placed here." })
    Axios.End()

    -- later in the code

    Axios.SetNextWidgetId("demo_window")
    Axios.Window()
        Axios.Text({ "Text two placed here." })
    Axios.End()

    -- both text widgets will be placed under the same window despite being called separately.
    ```
]=]
function Axios.SetNextWidgetID(ID: Types.ID)
    Internal._nextWidgetId = ID
end

--[[
    -----------------------
        [SECTION] State
    -----------------------
]]

--[=[
    @within Axios
    @function State<T>
    @param initialValue T -- the initial value for the state
    @return State<T>
    @tag State

    Constructs a new [State] object. Subsequent ID calls will return the same object.
    :::info
    Axios.State allows you to create "references" to the same value while inside your UI drawing loop.
    For example:
    ```lua
    Axios:Connect(function()
        local myNumber = 5
        myNumber = myNumber + 1
        Axios.Text({"The number is: " .. myNumber})
    end)
    ```
    This is problematic. Each time the function is called, a new myNumber is initialized, instead of retrieving the old one.
    The above code will always display 6.
    ***
    Axios.State solves this problem:
    ```lua
    Axios:Connect(function()
        local myNumber = Axios.State(5)
        myNumber:set(myNumber:get() + 1)
        Axios.Text({"The number is: " .. myNumber})
    end)
    ```
    In this example, the code will work properly, and increment every frame.
    :::
]=]
function Axios.State<T>(initialValue: T)
    local ID = Internal._getID(2)
    if Internal._states[ID] then
        return Internal._states[ID]
    end
    local newState = {
        ID = ID,
        value = initialValue,
        lastChangeTick = Axios.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    } :: Types.State<T>
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState
    return newState
end

--[=[
    @within Axios
    @function WeakState<T>
    @param initialValue T -- the initial value for the state
    @return State<T>
    @tag State

    Constructs a new state object, subsequent ID calls will return the same object, except all widgets connected to the state are discarded, the state reverts to the passed initialValue
]=]
function Axios.WeakState<T>(initialValue: T)
    local ID = Internal._getID(2)
    if Internal._states[ID] then
        if next(Internal._states[ID].ConnectedWidgets) == nil then
            Internal._states[ID] = nil
        else
            return Internal._states[ID]
        end
    end
    local newState = {
        ID = ID,
        value = initialValue,
        lastChangeTick = Axios.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    } :: Types.State<T>
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState
    return newState
end

--[=[
    @within Axios
    @function VariableState<T>
    @param variable T -- the variable to track
    @param callback (T) -> () -- a function which sets the new variable locally
    @return State<T>
    @tag State

    Returns a state object linked to a local variable.

    The passed variable is used to check whether the state object should update. The callback method is used to change the local variable when the state changes.

    The existence of such a function is to make working with local variables easier.
    Since Axios cannot directly manipulate the memory of the variable, like in C++, it must instead rely on the user updating it through the callback provided.
    Additionally, because the state value is not updated when created or called we cannot return the new value back, instead we require a callback for the user to update.

    ```lua
    local myNumber = 5

    local state = Axios.VariableState(myNumber, function(value)
        myNumber = value
    end)
    Axios.DragNum({ "My number" }, { number = state })
    ```

    This is how Dear ImGui does the same in C++ where we can just provide the memory location to the variable which is then updated directly.
    ```cpp
    static int myNumber = 5;
    ImGui::DragInt("My number", &myNumber); // Here in C++, we can directly pass the variable.
    ```

    :::caution Caution: Update Order
    If the variable and state value are different when calling this, the variable value takes precedence.

    Therefore, if you update the state using `state.value = ...` then it will be overwritten by the variable value.
    You must use `state:set(...)` if you want the variable to update to the state's value.
    :::
]=]
function Axios.VariableState<T>(variable: T, callback: (T) -> ())
    local ID = Internal._getID(2)
    local state = Internal._states[ID]

    if state then
        if variable ~= state.value then
            state:set(variable)
        end
        return state
    end

    local newState = {
        ID = ID,
        value = variable,
        lastChangeTick = Axios.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    } :: Types.State<T>
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState

    newState:onChange(callback)

    return newState
end

--[=[
    @within Axios
    @function TableState<K, V>
    @param table { [K]: V } -- the table containing the value
    @param key K -- the key to the value in table
    @param callback ((newValue: V) -> false?)? -- a function called when the state is changed
    @return State<V>
    @tag State

    Similar to Axios.VariableState but takes a table and key to modify a specific value and a callback to determine whether to update the value.

    The passed table and key are used to check the value. The callback is called when the state changes value and determines whether we update the table.
    This is useful if we want to monitor a table value which needs to call other functions when changed.

    Since tables are pass-by-reference, we can modify the table anywhere and it will update all other instances. Therefore, we don't need a callback by default.
    ```lua
    local data = {
        myNumber = 5
    }

    local state = Axios.TableState(data, "myNumber")
    Axios.DragNum({ "My number" }, { number = state })
    ```

    Here the `data._started` should never be updated directly, only through the `toggle` function. However, we still want to monitor the value and be able to change it.
    Therefore, we use the callback to toggle the function for us and prevent Axios from updating the table value by returning false.
    ```lua
    local data = {
        _started = false
    }

    local function toggle(enabled: boolean)
        data._started = enabled
        if data._started then
            start(...)
        else
            stop(...)
        end
    end

    local state = Axios.TableState(data, "_started", function(stateValue: boolean)
       toggle(stateValue)
       return false
    end)
    Axios.Checkbox({ "Started" }, { isChecked = state })
    ```

    :::caution Caution: Update Order
    If the table value and state value are different when calling this, the table value value takes precedence.

    Therefore, if you update the state using `state.value = ...` then it will be overwritten by the table value.
    You must use `state:set(...)` if you want the table value to update to the state's value.
    :::
]=]
function Axios.TableState<K, V>(tab: { [K]: V }, key: K, callback: ((newValue: V) -> true?)?)
    local value = tab[key]
    local ID = Internal._getID(2)
    local state = Internal._states[ID]

    -- If the table values changes, then we update the state to match.
    if state then
        if value ~= state.value then
            state:set(value)
        end
        return state
    end

    local newState = {
        ID = ID,
        value = value,
        lastChangeTick = Axios.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    } :: Types.State<V>
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState

    -- When a change happens to the state, we update the table value.
    newState:onChange(function()
        if callback ~= nil then
            if callback(newState.value) then
                tab[key] = newState.value
            end
        else
            tab[key] = newState.value
        end
    end)
    return newState
end

--[=[
    @within Axios
    @function ComputedState<T, U>
    @param firstState State<T> -- State to bind to.
    @param onChangeCallback (firstValue: T) -> U -- callback which should return a value transformed from the firstState value
    @return State<U>

    Constructs a new State object, but binds its value to the value of another State.
    :::info
    A common use case for this constructor is when a boolean State needs to be inverted:
    ```lua
    Axios.ComputedState(otherState, function(newValue)
        return not newValue
    end)
    ```
    :::
]=]
function Axios.ComputedState<T, U>(firstState: Types.State<T>, onChangeCallback: (firstValue: T) -> U)
    local ID = Internal._getID(2)

    if Internal._states[ID] then
        return Internal._states[ID]
    else
        local newState = {
            ID = ID,
            value = onChangeCallback(firstState.value),
            lastChangeTick = Axios.Internal._cycleTick,
            ConnectedWidgets = {},
            ConnectedFunctions = {},
        } :: Types.State<T>
        setmetatable(newState, Internal.StateClass)
        Internal._states[ID] = newState

        firstState:onChange(function(newValue: T)
            newState:set(onChangeCallback(newValue))
        end)
        return newState
    end
end

--[=[
    @within Axios
    @function ShowDemoWindow

    ShowDemoWindow is a function which creates a Demonstration window. this window contains many useful utilities for coders,
    and serves as a refrence for using each part of the library. Ideally, the DemoWindow should always be available in your UI.
    It is the same as any other callback you would connect to Axios using [Axios.Connect]
    ```lua
    Axios:Connect(Axios.ShowDemoWindow)
    ```
]=]
Axios.ShowDemoWindow = require(script.demoWindow)(Axios)

require(script.widgets)(Internal)
require(script.API)(Axios)

return Axios
