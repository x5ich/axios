--[[

                                                      █████╗ 
                                                     ██╔══██╗
                                                     ███████║
                                                     ██╔══██║
                                                     ██║  ██║
                                                     ╚═╝  ╚═╝
]]--

local url = "https://api.github.com/repos/x5ich/axios/releases/latest"

-- current version
local version = {
	major = 1,
	normal = 0,
	mini = 0
}

local function versionToString(v)
	return v.major .. "." .. v.normal .. "." .. v.mini
end

local function updateVersion(note, v)
	note = string.lower(note)

	if string.find(note, "major") then
		v.major += 1
		v.normal = 0
		v.mini = 0

	elseif string.find(note, "normal") then
		v.normal += 1
		v.mini = 0

	elseif string.find(note, "mini") then
		v.mini += 1
	end

	return v
end

local success, response = pcall(function()
	return game:HttpGet(url)
end)

if not success then
	warn("Version check failed:", response)
	return
end

local HttpService = game:GetService("HttpService")
local data = HttpService:JSONDecode(response)

local note = data.body or ""

version = updateVersion(note, version)

local _modules = {}
local _cache = {}

local function _require(path)
    if _cache[path] then return _cache[path] end
    local mod = _modules[path]
    if not mod then
        error("Module not found: " .. tostring(path), 2)
    end
    local res = mod()
    _cache[path] = res
    return res
end

-- string.split helper
local function split(str, sep)
    local res = {}
    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(res, s)
    end
    return res
end

-- Mock script objects
local create_mock_script
create_mock_script = function(path)
    local parts = split(path, ".")
    local name = parts[#parts] or ""
    local s = { Name = name }
    
    setmetatable(s, {
        __index = function(t, k)
            if k == "Parent" then
                if #parts <= 1 then return nil end
                local parent_path = ""
                for i=1, #parts-1 do
                    parent_path = parent_path .. (i > 1 and "." or "") .. parts[i]
                end
                return create_mock_script(parent_path)
            end
            return create_mock_script(path .. "." .. k)
        end,
        __tostring = function() return path end
    })
    return s
end

local function axios_require(path_obj)
    local path = tostring(path_obj)
    return _require(path)
end

_modules["Axios"] = function()
    local script = create_mock_script("Axios")
    local require = axios_require
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

end

_modules["Axios.API"] = function()
    local script = create_mock_script("Axios.API")
    local require = axios_require
local Types = require(script.Parent.Types)

return function(Axios: Types.Axios)
    -- basic wrapper for nearly every widget, saves space.
    local function wrapper(name)
        return function(arguments, states)
            return Axios.Internal._Insert(name, arguments, states)
        end
    end

    --[[
        ----------------------------
            [SECTION] Window API
        ----------------------------
    ]]
    --[=[
        @class Window
        
        Windows are the fundamental widget for Axios. Every other widget must be a descendant of a window.

        ```lua
        Axios.Window({ "Example Window" })
            Axios.Text({ "This is an example window!" })
        Axios.End()
        ```

        ![Example window](/Axios/assets/api/window/basicWindow.png)

        If you do not want the code inside a window to run unless it is open then you can use the following:
        ```lua
        local window = Axios.Window({ "Many Widgets Window" })

        if window.state.isOpened.value and window.state.isUncollapsed.value then
            Axios.Text({ "I will only be created when the window is open." })
        end
        Axios.End() -- must always call Axios.End(), regardless of whether the window is open or not.
        ```
    ]=]

    --[=[
        @within Window
        @prop Window Axios.Window
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        The top-level container for all other widgets to be created within.
        Can be moved and resized across the screen. Cannot contain embedded windows.
        Menus can be appended to windows creating a menubar.
        
        ```lua
        hasChildren = true
        hasState = true
        Arguments = {
            Title: string,
            NoTitleBar: boolean? = false,
            NoBackground: boolean? = false, -- the background behind the widget container.
            NoCollapse: boolean? = false,
            NoClose: boolean? = false,
            NoMove: boolean? = false,
            NoScrollbar: boolean? = false, -- the scrollbar if the window is too short for all widgets.
            NoResize: boolean? = false,
            NoNav: boolean? = false, -- unimplemented.
            NoMenu: boolean? = false -- whether the menubar will show if created.
        }
        Events = {
            opened: () -> boolean, -- once when opened.
            closed: () -> boolean, -- once when closed.
            collapsed: () -> boolean, -- once when collapsed.
            uncollapsed: () -> boolean, -- once when uncollapsed.
            hovered: () -> boolean -- fires when the mouse hovers over any of the window.
        }
        States = {
            size: State<Vector2>? = Vector2.new(400, 300),
            position: State<Vector2>?,
            isUncollapsed: State<boolean>? = true,
            isOpened: State<boolean>? = true,
            scrollDistance: State<number>? -- vertical scroll distance, if too short.
        }
        ```
    ]=]
    Axios.Window = wrapper("Window")

    --[=[
        @within Axios
        @function SetFocusedWindow
        @param window Types.Window -- the window to focus.

        Sets the focused window to the window provided, which brings it to the front and makes it active.
    ]=]
    Axios.SetFocusedWindow = Axios.Internal.SetFocusedWindow

    --[=[
        @within Window
        @prop Tooltip Axios.Tooltip
        @tag Widget

        Displays a text label next to the cursor

        ```lua
        Axios.Tooltip({"My custom tooltip"})
        ```

        ![Basic tooltip example](/Axios/assets/api/window/basicTooltip.png)
        
        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string
        }
        ```
    ]=]
    Axios.Tooltip = wrapper("Tooltip")

    --[[
        ---------------------------------
            [SECTION] Menu Widget API
        ---------------------------------
    ]]
    --[=[
        @class Menu
        Menu API
    ]=]

    --[=[
        @within Menu
        @prop MenuBar Axios.MenuBar
        @tag Widget
        @tag HasChildren
        
        Creates a MenuBar for the current window. Must be called directly under a Window and not within a child widget.
        :::info
            This does not create any menus, just tells the window that we going to add menus within.
        :::
        
        ```lua
        hasChildren = true
        hasState = false
        ```
    ]=]
    Axios.MenuBar = wrapper("MenuBar")

    --[=[
        @within Menu
        @prop Menu Axios.Menu
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        Creates an collapsable menu. If the Menu is created directly under a MenuBar, then the widget will
        be placed horizontally below the window title. If the menu Menu is created within another menu, then
        it will be placed vertically alongside MenuItems and display an arrow alongside.

        The opened menu will be a vertically listed box below or next to the button.

        ```lua
            Axios.Window({"Menu Demo"})
                Axios.MenuBar()
                    Axios.Menu({"Test Menu"})
                        Axios.Button({"Menu Option 1"})
                        Axios.Button({"Menu Option 2"})
                    Axios.End()
                Axios.End()
            Axios.End()
        ```

        ![Example menu](/Axios/assets/api/menu/basicMenu.gif)

        :::info
        There are widgets which are designed for being parented to a menu whilst other happens to work. There is nothing
        preventing you from adding any widget as a child, but the behaviour is unexplained and not intended.
        :::
        
        ```lua
        hasChildren = true
        hasState = true
        Arguments = {
            Text: string -- menu text.
        }
        Events = {
            clicked: () -> boolean,
            opened: () -> boolean, -- once when opened.
            closed: () -> boolean, -- once when closed.
            hovered: () -> boolean
        }
        States = {
            isOpened: State<boolean>? -- whether the menu is open, including any sub-menus within.
        }
        ```
    ]=]
    Axios.Menu = wrapper("Menu")

    --[=[
        @within Menu
        @prop MenuItem Axios.MenuItem
        @tag Widget
        
        Creates a button within a menu. The optional KeyCode and ModiferKey arguments will show the keys next
        to the title, but **will not** bind any connection to them. You will need to do this yourself.

        ```lua
        Axios.Window({"MenuToggle Demo"})
            Axios.MenuBar()
                Axios.MenuToggle({"Menu Item"})
            Axios.End()
        Axios.End()
        ```

        ![Example Menu Item](/Axios/assets/api/menu/basicMenuItem.gif)

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string,
            KeyCode: Enum.KeyCode? = nil, -- an optional keycode, does not actually connect an event.
            ModifierKey: Enum.ModifierKey? = nil -- an optional modifer key for the key code.
        }
        Events = {
            clicked: () -> boolean,
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.MenuItem = wrapper("MenuItem")

    --[=[
        @within Menu
        @prop MenuToggle Axios.MenuToggle
        @tag Widget
        @tag HasState
        
        Creates a togglable button within a menu. The optional KeyCode and ModiferKey arguments act the same
        as the MenuItem. It is not visually the same as a checkbox, but has the same functionality.
        
        ```lua
        Axios.Window({"MenuToggle Demo"})
            Axios.MenuBar()
                Axios.MenuToggle({"Menu Toggle"})
            Axios.End()
        Axios.End()
        ```

        ![Example Menu Toggle](/Axios/assets/api/menu/basicMenuToggle.gif)

        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string,
            KeyCode: Enum.KeyCode? = nil, -- an optional keycode, does not actually connect an event.
            ModifierKey: Enum.ModifierKey? = nil -- an optional modifer key for the key code.
        }
        Events = {
            checked: () -> boolean, -- once on check.
            unchecked: () -> boolean, -- once on uncheck.
            hovered: () -> boolean
        }
        States = {
            isChecked: State<boolean>?
        }
        ```
    ]=]
    Axios.MenuToggle = wrapper("MenuToggle")

    --[[
        -----------------------------------
            [SECTION] Format Widget Axios
        -----------------------------------
    ]]
    --[=[
        @class Format
        Format API
    ]=]

    --[=[
        @within Format
        @prop Separator Axios.Separator
        @tag Widget

        A vertical or horizonal line, depending on the context, which visually seperates widgets.
        
        ```lua
        Axios.Window({"Separator Demo"})
            Axios.Text({"Some text here!"})
            Axios.Separator()
            Axios.Text({"This text has been separated!"})
        Axios.End()
        ```

        ![Example Separator](/Axios/assets/api/format/basicSeparator.png)

        ```lua
        hasChildren = false
        hasState = false
        ```
    ]=]
    Axios.Separator = wrapper("Separator")

    --[=[
        @within Format
        @prop Indent Axios.Indent
        @tag Widget
        @tag HasChildren
        
        Indents its child widgets.

        ```lua
        Axios.Window({"Indent Demo"})
            Axios.Text({"Unindented text!"})
            Axios.Indent()
                Axios.Text({"This text has been indented!"})
            Axios.End()
        Axios.End()
        ```

        ![Example Indent](/Axios/assets/api/format/basicIndent.png)

        ```lua
        hasChildren = true
        hasState = false
        Arguments = {
            Width: number? = Axios._config.IndentSpacing -- indent width ammount.
        }
        ```
    ]=]
    Axios.Indent = wrapper("Indent")

    --[=[
        @within Format
        @prop SameLine Axios.SameLine
        @tag Widget
        @tag HasChildren
        
        Positions its children in a row, horizontally.

        ```lua
        Axios.Window({"Same Line Demo"})
            Axios.Text({"All of these buttons are on the same line!"})
            Axios.SameLine()
                Axios.Button({"Button 1"})
                Axios.Button({"Button 2"})
                Axios.Button({"Button 3"})
            Axios.End()
        Axios.End()
        ```

        ![Example SameLine](/Axios/assets/api/format/basicSameLine.png)
        
        ```lua
        hasChildren = true
        hasState = false
        Arguments = {
            Width: number? = Axios._config.ItemSpacing.X, -- horizontal spacing between child widgets.
            VerticalAlignment: Enum.VerticalAlignment? = Enum.VerticalAlignment.Center -- how widgets vertically to each other.
            HorizontalAlignment: Enum.HorizontalAlignment? = Enum.HorizontalAlignment.Center -- how widgets are horizontally.
        }
        ```
    ]=]
    Axios.SameLine = wrapper("SameLine")

    --[=[
        @within Format
        @prop Group Axios.Group
        @tag Widget
        @tag HasChildren
        
        Layout widget which contains its children as a single group.
        
        ```lua
        hasChildren = true
        hasState = false
        ```
    ]=]
    Axios.Group = wrapper("Group")

    --[[
        ---------------------------------
            [SECTION] Text Widget API
        ---------------------------------
    ]]
    --[=[
        @class Text
        Text Widget API
    ]=]

    --[=[
        @within Text
        @prop Text Axios.Text
        @tag Widget
        
        A text label to display the text argument.
        The Wrapped argument will make the text wrap around if it is cut off by its parent.
        The Color argument will change the color of the text, by default it is defined in the configuration file.

        ```lua
        Axios.Window({"Text Demo"})
            Axios.Text({"This is regular text"})
        Axios.End()
        ```

        ![Example Text](/Axios/assets/api/text/basicText.png)

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string,
            Wrapped: boolean? = [CONFIG] = false, -- whether the text will wrap around inside the parent container. If not specified, then equal to the config
            Color: Color3? = Axios._config.TextColor, -- the colour of the text.
            RichText: boolean? = [CONFIG] = false -- enable RichText. If not specified, then equal to the config
        }
        Events = {
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.Text = wrapper("Text")

    --[=[
        @within Text
        @prop TextWrapped Axios.Text
        @tag Widget
        @deprecated v2.0.0 -- Use 'Text' with the Wrapped argument or change the config.

        An alias for [Axios.Text](Text#Text) with the Wrapped argument set to true, and the text will wrap around if cut off by its parent.

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string,
        }
        Events = {
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.TextWrapped = function(arguments: Types.WidgetArguments)
        arguments[2] = true
        return Axios.Internal._Insert("Text", arguments)
    end

    --[=[
        @within Text
        @prop TextColored Axios.Text
        @tag Widget
        @deprecated v2.0.0 -- Use 'Text' with the Color argument or change the config.
        
        An alias for [Axios.Text](Text#Text) with the color set by the Color argument.

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string,
            Color: Color3 -- the colour of the text.
        }
        Events = {
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.TextColored = function(arguments: Types.WidgetArguments)
        arguments[3] = arguments[2]
        arguments[2] = nil
        return Axios.Internal._Insert("Text", arguments)
    end

    --[=[
        @within Text
        @prop SeparatorText Axios.SeparatorText
        @tag Widget
        
        Similar to [Axios.Separator](Format#Separator) but with a text label to be used as a header
        when an [Axios.Tree](Tree#Tree) or [Axios.CollapsingHeader](Tree#CollapsingHeader) is not appropriate.

        Visually a full width thin line with a text label clipping out part of the line.

        ```lua
        Axios.Window({"Separator Text Demo"})
            Axios.Text({"Regular Text"})
            Axios.SeparatorText({"This is a separator with text"})
            Axios.Text({"More Regular Text"})
        Axios.End()
        ```

        ![Example Separator Text](/Axios/assets/api/text/basicSeparatorText.png)
        
        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string
        }
        ```
    ]=]
    Axios.SeparatorText = wrapper("SeparatorText")

    --[=[
        @within Text
        @prop InputText Axios.InputText
        @tag Widget
        @tag HasState

        A field which allows the user to enter text.

        ```lua
        Axios.Window({"Input Text Demo"})
            local inputtedText = Axios.State("")

            Axios.InputText({"Enter text here:"}, {text = inputtedText})
            Axios.Text({"You entered: " .. inputtedText:get()})
        Axios.End()
        ```

        ![Example Input Text](/Axios/assets/api/text/basicInputText.gif)

        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputText",
            TextHint: string? = "", -- a hint to display when the text box is empty.
            ReadOnly: boolean? = false,
            MultiLine: boolean? = false
        }
        Events = {
            textChanged: () -> boolean, -- whenever the textbox looses focus and a change was made.
            hovered: () -> boolean
        }
        States = {
            text: State<string>?
        }
        ```
    ]=]
    Axios.InputText = wrapper("InputText")

    --[[
        ----------------------------------
            [SECTION] Basic Widget API
        ----------------------------------
    ]]
    --[=[
        @class Basic
        Basic Widget API
    ]=]

    --[=[
        @within Basic
        @prop Button Axios.Button
        @tag Widget
        
        A clickable button the size of the text with padding. Can listen to the `clicked()` event to determine if it was pressed.

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string,
            Size: UDim2? = UDim2.fromOffset(0, 0),
        }
        Events = {
            clicked: () -> boolean,
            rightClicked: () -> boolean,
            doubleClicked: () -> boolean,
            ctrlClicked: () -> boolean, -- when the control key is down and clicked.
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.Button = wrapper("Button")

    --[=[
        @within Basic
        @prop SmallButton Axios.SmallButton
        @tag Widget
        
        A smaller clickable button, the same as a [Axios.Button](Basic#Button) but without padding. Can listen to the `clicked()` event to determine if it was pressed.

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Text: string,
            Size: UDim2? = 0,
        }
        Events = {
            clicked: () -> boolean,
            rightClicked: () -> boolean,
            doubleClicked: () -> boolean,
            ctrlClicked: () -> boolean, -- when the control key is down and clicked.
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.SmallButton = wrapper("SmallButton")

    --[=[
        @within Basic
        @prop Checkbox Axios.Checkbox
        @tag Widget
        @tag HasState
        
        A checkable box with a visual tick to represent a boolean true or false state.

        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string
        }
        Events = {
            checked: () -> boolean, -- once when checked.
            unchecked: () -> boolean, -- once when unchecked.
            hovered: () -> boolean
        }
        State = {
            isChecked = State<boolean>? -- whether the box is checked.
        }
        ```
    ]=]
    Axios.Checkbox = wrapper("Checkbox")

    --[=[
        @within Basic
        @prop RadioButton Axios.RadioButton
        @tag Widget
        @tag HasState
        
        A circular selectable button, changing the state to its index argument. Used in conjunction with multiple other RadioButtons sharing the same state to represent one value from multiple options.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string,
            Index: any -- the state object is set to when clicked.
        }
        Events = {
            selected: () -> boolean,
            unselected: () -> boolean,
            active: () -> boolean, -- if the state index equals the RadioButton's index.
            hovered: () -> boolean
        }
        State = {
            index = State<any>? -- the state set by the index of a RadioButton.
        }
        ```
    ]=]
    Axios.RadioButton = wrapper("RadioButton")

    --[[
        ----------------------------------
            [SECTION] Image Widget API
        ----------------------------------
    ]]
    --[=[
        @class Image
        Image Widget API

        Provides two widgets for Images and ImageButtons, which provide the same control as a an ImageLabel instance.
    ]=]

    --[=[
        @within Image
        @prop Image Axios.Image
        @tag Widget

        An image widget for displaying an image given its texture ID and a size. The widget also supports Rect Offset and Size allowing cropping of the image and the rest of the ScaleType properties.
        Some of the arguments are only used depending on the ScaleType property, such as TileSize or Slice which will be ignored.

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Image: string, -- the texture asset id
            Size: UDim2,
            Rect: Rect? = Rect.new(), -- Rect structure which is used to determine the offset or size. An empty, zeroed rect is equivalent to nil
            ScaleType: Enum.ScaleType? = Enum.ScaleType.Stretch, -- used to determine whether the TileSize, SliceCenter and SliceScale arguments are used
            ResampleMode: Enum.ResampleMode? = Enum.ResampleMode.Default,
            TileSize: UDim2? = UDim2.fromScale(1, 1), -- only used if the ScaleType is set to Tile
            SliceCenter: Rect? = Rect.new(), -- only used if the ScaleType is set to Slice
            SliceScale: number? = 1 -- only used if the ScaleType is set to Slice
        }
        Events = {
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.Image = wrapper("Image")

    --[=[
        @within Image
        @prop ImageButton Axios.ImageButton
        @tag Widget

        An image button widget for a button as an image given its texture ID and a size. The widget also supports Rect Offset and Size allowing cropping of the image, and the rest of the ScaleType properties.
        Supports all of the events of a regular button.

        ```lua
        hasChildren = false
        hasState = false
        Arguments = {
            Image: string, -- the texture asset id
            Size: UDim2,
            Rect: Rect? = Rect.new(), -- Rect structure which is used to determine the offset or size. An empty, zeroed rect is equivalent to nil
            ScaleType: Enum.ScaleType? = Enum.ScaleType.Stretch, -- used to determine whether the TileSize, SliceCenter and SliceScale arguments are used
            ResampleMode: Enum.ResampleMode? = Enum.ResampleMode.Default,
            TileSize: UDim2? = UDim2.fromScale(1, 1), -- only used if the ScaleType is set to Tile
            SliceCenter: Rect? = Rect.new(), -- only used if the ScaleType is set to Slice
            SliceScale: number? = 1 -- only used if the ScaleType is set to Slice
        }
        Events = {
            clicked: () -> boolean,
            rightClicked: () -> boolean,
            doubleClicked: () -> boolean,
            ctrlClicked: () -> boolean, -- when the control key is down and clicked.
            hovered: () -> boolean
        }
        ```
    ]=]
    Axios.ImageButton = wrapper("ImageButton")

    --[[
        ---------------------------------
            [SECTION] Tree Widget API
        ---------------------------------
    ]]
    --[=[
        @class Tree
        Tree Widget API
    ]=]

    --[=[
        @within Tree
        @prop Tree Axios.Tree
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        A collapsable container for other widgets, to organise and hide widgets when not needed. The state determines whether the child widgets are visible or not. Clicking on the widget will collapse or uncollapse it.
        
        ```lua
        hasChildren: true
        hasState: true
        Arguments = {
            Text: string,
            SpanAvailWidth: boolean? = false, -- the tree title will fill all horizontal space to the end its parent container.
            NoIndent: boolean? = false, -- the child widgets will not be indented underneath.
            DefaultOpen: boolean? = false -- initially opens the tree if no state is provided
        }
        Events = {
            collapsed: () -> boolean,
            uncollapsed: () -> boolean,
            hovered: () -> boolean
        }
        State = {
            isUncollapsed: State<boolean>? -- whether the widget is collapsed.
        }
        ```
    ]=]
    Axios.Tree = wrapper("Tree")

    --[=[
        @within Tree
        @prop CollapsingHeader Axios.CollapsingHeader
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        The same as a Tree Widget, but with a larger title and clearer, used mainly for organsing widgets on the first level of a window.
        
        ```lua
        hasChildren: true
        hasState: true
        Arguments = {
            Text: string,
            DefaultOpen: boolean? = false -- initially opens the tree if no state is provided
        }
        Events = {
            collapsed: () -> boolean,
            uncollapsed: () -> boolean,
            hovered: () -> boolean
        }
        State = {
            isUncollapsed: State<boolean>? -- whether the widget is collapsed.
        }
        ```
    ]=]
    Axios.CollapsingHeader = wrapper("CollapsingHeader")

    --[[
        --------------------------------
            [SECTION] Tab Widget API
        --------------------------------
    ]]
    --[=[
        @class Tab
        Tab Widget API
    ]=]

    --[=[
        @within Tab
        @prop TabBar Axios.TabBar
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        Creates a TabBar for putting tabs under. This does not create the tabs but just the container for them to be in.
        The index state is used to control the current tab and is based on an index starting from 1 rather than the
        text provided to a Tab. The TabBar will replicate the index to the Tab children .
        
        ```lua
        hasChildren: true
        hasState: true
        Arguments = {}
        Events = {}
        State = {
            index: State<number>? -- whether the widget is collapsed.
        }
        ```
    ]=]
    Axios.TabBar = wrapper("TabBar")

    --[=[
        @within Tab
        @prop Tab Axios.Tab
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        The tab item for use under a TabBar. The TabBar must be the parent and determines the index value. You cannot
        provide a state for this tab. The optional Hideable argument determines if a tab can be closed, which is
        controlled by the isOpened state.

        A tab will take up the full horizontal width of the parent and hide any other tabs in the TabBar.
        
        ```lua
        hasChildren: true
        hasState: true
        Arguments = {
            Text: string,
            Hideable: boolean? = nil -- determines whether a tab can be closed/hidden
        }
        Events = {
            clicked: () -> boolean,
            hovered: () -> boolean
            selected: () -> boolean
            unselected: () -> boolean
            active: () -> boolean
            opened: () -> boolean
            closed: () -> boolean
        }
        State = {
            isOpened: State<boolean>?
        }
        ```
    ]=]
    Axios.Tab = wrapper("Tab")

    --[[
        ----------------------------------
            [SECTION] Input Widget API
        ----------------------------------
    ]]
    --[=[
        @class Input
        Input Widget API

        Input Widgets are textboxes for typing in specific number values. See [Drag], [Slider] or [InputText](Text#InputText) for more input types.

        Axios provides a set of specific inputs for the datatypes:
        Number,
        [Vector2](https://create.roblox.com/docs/reference/engine/datatypes/Vector2),
        [Vector3](https://create.roblox.com/docs/reference/engine/datatypes/Vector3),
        [UDim](https://create.roblox.com/docs/reference/engine/datatypes/UDim),
        [UDim2](https://create.roblox.com/docs/reference/engine/datatypes/UDim2),
        [Rect](https://create.roblox.com/docs/reference/engine/datatypes/Rect),
        [Color3](https://create.roblox.com/docs/reference/engine/datatypes/Color3)
        and the custom [Color4](https://create.roblox.com/docs/reference/engine/datatypes/Color3).
        
        Each Input widget has the same arguments but the types depend of the DataType:
        1. Text: string? = "Input{type}" -- the text to be displayed to the right of the textbox.
        2. Increment: DataType? = nil, -- the increment argument determines how a value will be rounded once the textbox looses focus.
        3. Min: DataType? = nil, -- the minimum value that the widget will allow, no clamping by default.
        4. Max: DataType? = nil, -- the maximum value that the widget will allow, no clamping by default.
        5. Format: string | { string }? = [DYNAMIC] -- uses `string.format` to customise visual display.

        The format string can either by a single value which will apply to every box, or a table allowing specific text.

        :::note
        If you do not specify a format option then Axios will dynamically calculate a relevant number of sigifs and format option.
        For example, if you have Increment, Min and Max values of 1, 0 and 100, then Axios will guess that you are only using integers
        and will format the value as an integer.
        As another example, if you have Increment, Min and max values of 0.005, 0, 1, then Axios will guess you are using a float of 3
        significant figures.

        Additionally, for certain DataTypes, Axios will append an prefix to each box if no format option is provided.
        For example, a Vector3 box will have the append values of "X: ", "Y: " and "Z: " to the relevant input box.
        :::
    ]=]

    --[=[
        @within Input
        @prop InputNum Axios.InputNum
        @tag Widget
        @tag HasState
        
        An input box for numbers. The number can be either an integer or a float.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputNum",
            Increment: number? = nil,
            Min: number? = nil,
            Max: number? = nil,
            Format: string? | { string }? = [DYNAMIC], -- Axios will dynamically generate an approriate format.
            NoButtons: boolean? = false -- whether to display + and - buttons next to the input box.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<number>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputNum = wrapper("InputNum")

    --[=[
        @within Input
        @prop InputVector2 Axios.InputVector2
        @tag Widget
        @tag HasState
        
        An input box for Vector2. The numbers can be either integers or floats.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputVector2",
            Increment: Vector2? = nil,
            Min: Vector2? = nil,
            Max: Vector2? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Vector2>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputVector2 = wrapper("InputVector2")

    --[=[
        @within Input
        @prop InputVector3 Axios.InputVector3
        @tag Widget
        @tag HasState
        
        An input box for Vector3. The numbers can be either integers or floats.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputVector3",
            Increment: Vector3? = nil,
            Min: Vector3? = nil,
            Max: Vector3? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Vector3>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputVector3 = wrapper("InputVector3")

    --[=[
        @within Input
        @prop InputUDim Axios.InputUDim
        @tag Widget
        @tag HasState
        
        An input box for UDim. The Scale box will be a float and the Offset box will be
        an integer, unless specified differently.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputUDim",
            Increment: UDim? = nil,
            Min: UDim? = nil,
            Max: UDim? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<UDim>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputUDim = wrapper("InputUDim")

    --[=[
        @within Input
        @prop InputUDim2 Axios.InputUDim2
        @tag Widget
        @tag HasState
        
        An input box for UDim2. The Scale boxes will be floats and the Offset boxes will be
        integers, unless specified differently.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputUDim2",
            Increment: UDim2? = nil,
            Min: UDim2? = nil,
            Max: UDim2? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<UDim2>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputUDim2 = wrapper("InputUDim2")

    --[=[
        @within Input
        @prop InputRect Axios.InputRect
        @tag Widget
        @tag HasState
        
        An input box for Rect. The numbers will default to integers, unless specified differently.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputRect",
            Increment: Rect? = nil,
            Min: Rect? = nil,
            Max: Rect? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Rect>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputRect = wrapper("InputRect")

    --[[
        ---------------------------------
            [SECTION] Drag Widget API
        ---------------------------------
    ]]
    --[=[
        @class Drag
        Drag Widget API

        A draggable widget for each datatype. Allows direct typing input but also dragging values by clicking and holding.
        
        See [Input] for more details on the arguments.
    ]=]

    --[=[
        @within Drag
        @prop DragNum Axios.DragNum
        @tag Widget
        @tag HasState
        
        A field which allows the user to click and drag their cursor to enter a number.
        You can ctrl + click to directly input a number, like InputNum.
        You can hold Shift to increase speed, and Alt to decrease speed when dragging.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "DragNum",
            Increment: number? = nil,
            Min: number? = nil,
            Max: number? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<number>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.DragNum = wrapper("DragNum")

    --[=[
        @within Drag
        @prop DragVector2 Axios.DragVector2
        @tag Widget
        @tag HasState
        
        A field which allows the user to click and drag their cursor to enter a Vector2.
        You can ctrl + click to directly input a Vector2, like InputVector2.
        You can hold Shift to increase speed, and Alt to decrease speed when dragging.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "DragVector2",
            Increment: Vector2? = nil,
            Min: Vector2? = nil,
            Max: Vector2? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Vector2>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.DragVector2 = wrapper("DragVector2")

    --[=[
        @within Drag
        @prop DragVector3 Axios.DragVector3
        @tag Widget
        @tag HasState
        
        A field which allows the user to click and drag their cursor to enter a Vector3.
        You can ctrl + click to directly input a Vector3, like InputVector3.
        You can hold Shift to increase speed, and Alt to decrease speed when dragging.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "DragVector3",
            Increment: Vector3? = nil,
            Min: Vector3? = nil,
            Max: Vector3? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Vector3>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.DragVector3 = wrapper("DragVector3")

    --[=[
        @within Drag
        @prop DragUDim Axios.DragUDim
        @tag Widget
        @tag HasState
        
        A field which allows the user to click and drag their cursor to enter a UDim.
        You can ctrl + click to directly input a UDim, like InputUDim.
        You can hold Shift to increase speed, and Alt to decrease speed when dragging.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "DragUDim",
            Increment: UDim? = nil,
            Min: UDim? = nil,
            Max: UDim? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<UDim>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.DragUDim = wrapper("DragUDim")

    --[=[
        @within Drag
        @prop DragUDim2 Axios.DragUDim2
        @tag Widget
        @tag HasState
        
        A field which allows the user to click and drag their cursor to enter a UDim2.
        You can ctrl + click to directly input a UDim2, like InputUDim2.
        You can hold Shift to increase speed, and Alt to decrease speed when dragging.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "DragUDim2",
            Increment: UDim2? = nil,
            Min: UDim2? = nil,
            Max: UDim2? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<UDim2>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.DragUDim2 = wrapper("DragUDim2")

    --[=[
        @within Drag
        @prop DragRect Axios.DragRect
        @tag Widget
        @tag HasState
        
        A field which allows the user to click and drag their cursor to enter a Rect.
        You can ctrl + click to directly input a Rect, like InputRect.
        You can hold Shift to increase speed, and Alt to decrease speed when dragging.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "DragRect",
            Increment: Rect? = nil,
            Min: Rect? = nil,
            Max: Rect? = nil,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Rect>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.DragRect = wrapper("DragRect")

    --[=[
        @within Input
        @prop InputColor3 Axios.InputColor3
        @tag Widget
        @tag HasState
        
        An input box for Color3. The input boxes are draggable between 0 and 255 or if UseFloats then between 0 and 1.
        Input can also be done using HSV instead of the default RGB.
        If no format argument is provided then a default R, G, B or H, S, V prefix is applied.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputColor3",
            UseFloats: boolean? = false, -- constrain the values between floats 0 and 1 or integers 0 and 255.
            UseHSV: boolean? = false, -- input using HSV instead.
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            color: State<Color3>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputColor3 = wrapper("InputColor3")

    --[=[
        @within Input
        @prop InputColor4 Axios.InputColor4
        @tag Widget
        @tag HasState
        
        An input box for Color4. Color4 is a combination of Color3 and a fourth transparency argument.
        It has two states for this purpose.
        The input boxes are draggable between 0 and 255 or if UseFloats then between 0 and 1.
        Input can also be done using HSV instead of the default RGB.
        If no format argument is provided then a default R, G, B, T or H, S, V, T prefix is applied.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputColor4",
            UseFloats: boolean? = false, -- constrain the values between floats 0 and 1 or integers 0 and 255.
            UseHSV: boolean? = false, -- input using HSV instead.
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            color: State<Color3>?,
            transparency: State<number>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.InputColor4 = wrapper("InputColor4")

    --[[
        -----------------------------------
            [SECTION] Slider Widget API
        -----------------------------------
    ]]
    --[=[
        @class Slider
        Slider Widget API

        A draggable widget with a visual bar constrained between a min and max for each datatype.
        Allows direct typing input but also dragging the slider by clicking and holding anywhere in the box.
        
        See [Input] for more details on the arguments.
    ]=]

    --[=[
        @within Slider
        @prop SliderNum Axios.SliderNum
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a number within a range.
        You can ctrl + click to directly input a number, like InputNum.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "SliderNum",
            Increment: number? = 1,
            Min: number? = 0,
            Max: number? = 100,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<number>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.SliderNum = wrapper("SliderNum")

    --[=[
        @within Slider
        @prop SliderVector2 Axios.SliderVector2
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a Vector2 within a range.
        You can ctrl + click to directly input a Vector2, like InputVector2.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "SliderVector2",
            Increment: Vector2? = { 1, 1 },
            Min: Vector2? = { 0, 0 },
            Max: Vector2? = { 100, 100 },
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Vector2>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.SliderVector2 = wrapper("SliderVector2")

    --[=[
        @within Slider
        @prop SliderVector3 Axios.SliderVector3
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a Vector3 within a range.
        You can ctrl + click to directly input a Vector3, like InputVector3.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "SliderVector3",
            Increment: Vector3? = { 1, 1, 1 },
            Min: Vector3? = { 0, 0, 0 },
            Max: Vector3? = { 100, 100, 100 },
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Vector3>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.SliderVector3 = wrapper("SliderVector3")

    --[=[
        @within Slider
        @prop SliderUDim Axios.SliderUDim
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a UDim within a range.
        You can ctrl + click to directly input a UDim, like InputUDim.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "SliderUDim",
            Increment: UDim? = { 0.01, 1 },
            Min: UDim? = { 0, 0 },
            Max: UDim? = { 1, 960 },
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<UDim>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.SliderUDim = wrapper("SliderUDim")

    --[=[
        @within Slider
        @prop SliderUDim2 Axios.SliderUDim2
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a UDim2 within a range.
        You can ctrl + click to directly input a UDim2, like InputUDim2.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "SliderUDim2",
            Increment: UDim2? = { 0.01, 1, 0.01, 1 },
            Min: UDim2? = { 0, 0, 0, 0 },
            Max: UDim2? = { 1, 960, 1, 960 },
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<UDim2>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.SliderUDim2 = wrapper("SliderUDim2")

    --[=[
        @within Slider
        @prop SliderRect Axios.SliderRect
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a Rect within a range.
        You can ctrl + click to directly input a Rect, like InputRect.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "SliderRect",
            Increment: Rect? = { 1, 1, 1, 1 },
            Min: Rect? = { 0, 0, 0, 0 },
            Max: Rect? = { 960, 960, 960, 960 },
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<Rect>?,
            editingText: State<boolean>?
        }
        ```
    ]=]
    Axios.SliderRect = wrapper("SliderRect")

    --[[
        ----------------------------------
            [SECTION] Combo Widget API
        ----------------------------------
    ]]
    --[=[
        @class Combo
        Combo Widget API
    ]=]

    --[=[
        @within Combo
        @prop Selectable Axios.Selectable
        @tag Widget
        @tag HasState
        
        An object which can be selected.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string,
            Index: any, -- index of selectable value.
            NoClick: boolean? = false -- prevents the selectable from being clicked by the user.
        }
        Events = {
            selected: () -> boolean,
            unselected: () -> boolean,
            active: () -> boolean,
            clicked: () -> boolean,
            rightClicked: () -> boolean,
            doubleClicked: () -> boolean,
            ctrlClicked: () -> boolean,
            hovered: () -> boolean,
        }
        States = {
            index: State<any> -- a shared state between all selectables.
        }
        ```
    ]=]
    Axios.Selectable = wrapper("Selectable")

    --[=[
        @within Combo
        @prop Combo Axios.Combo
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        A dropdown menu box to make a selection from a list of values.
        
        ```lua
        hasChildren = true
        hasState = true
        Arguments = {
            Text: string,
            NoButton: boolean? = false, -- hide the dropdown button.
            NoPreview: boolean? = false -- hide the preview field.
        }
        Events = {
            opened: () -> boolean,
            closed: () -> boolean,
            changed: () -> boolean,
            clicked: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            index: State<any>,
            isOpened: State<boolean>?
        }
        ```
    ]=]
    Axios.Combo = wrapper("Combo")

    --[=[
        @within Combo
        @prop ComboArray Axios.Combo
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        A selection box to choose a value from an array.
        
        ```lua
        hasChildren = true
        hasState = true
        Arguments = {
            Text: string,
            NoButton: boolean? = false, -- hide the dropdown button.
            NoPreview: boolean? = false -- hide the preview field.
        }
        Events = {
            opened: () -> boolean,
            closed: () -> boolean,
            clicked: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            index: State<any>,
            isOpened: State<boolean>?
        }
        Extra = {
            selectionArray: { any } -- the array to generate a combo from.
        }
        ```
    ]=]
    Axios.ComboArray = function<T>(arguments: Types.WidgetArguments, states: Types.WidgetStates?, selectionArray: { T })
        local defaultState
        if states == nil then
            defaultState = Axios.State(selectionArray[1])
        else
            defaultState = states
        end
        local thisWidget = Axios.Internal._Insert("Combo", arguments, defaultState)
        local sharedIndex = thisWidget.state.index
        for _, Selection in selectionArray do
            Axios.Internal._Insert("Selectable", { Selection, Selection }, { index = sharedIndex })
        end
        Axios.End()

        return thisWidget
    end

    --[=[
        @within Combo
        @prop ComboEnum Axios.Combo
        @tag Widget
        @tag HasChildren
        @tag HasState
        
        A selection box to choose a value from an Enum.
        
        ```lua
        hasChildren = true
        hasState = true
        Arguments = {
            Text: string,
            NoButton: boolean? = false, -- hide the dropdown button.
            NoPreview: boolean? = false -- hide the preview field.
        }
        Events = {
            opened: () -> boolean,
            closed: () -> boolean,
            clicked: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            index: State<any>,
            isOpened: State<boolean>?
        }
        Extra = {
            enumType: Enum -- the enum to generate a combo from.
        }
        ```
    ]=]
    Axios.ComboEnum = function(arguments: Types.WidgetArguments, states: Types.WidgetStates?, enumType: Enum)
        local defaultState
        if states == nil then
            defaultState = Axios.State(enumType:GetEnumItems()[1])
        else
            defaultState = states
        end
        local thisWidget = Axios.Internal._Insert("Combo", arguments, defaultState)
        local sharedIndex = thisWidget.state.index
        for _, Selection in enumType:GetEnumItems() do
            Axios.Internal._Insert("Selectable", { Selection.Name, Selection }, { index = sharedIndex })
        end
        Axios.End()

        return thisWidget
    end

    --[=[
        @private
        @within Slider
        @prop InputEnum Axios.InputEnum
        @tag Widget
        @tag HasState
        
        A field which allows the user to slide a grip to enter a number within a range.
        You can ctrl + click to directly input a number, like InputNum.
        
        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "InputEnum",
            Increment: number? = 1,
            Min: number? = 0,
            Max: number? = 100,
            Format: string? | { string }? = [DYNAMIC] -- Axios will dynamically generate an approriate format.
        }
        Events = {
            numberChanged: () -> boolean,
            hovered: () -> boolean
        }
        States = {
            number: State<number>?,
            editingText: State<boolean>?,
            enumItem: EnumItem
        }
        ```
    ]=]
    Axios.InputEnum = Axios.ComboEnum

    --[[
        ---------------------------------
            [SECTION] Plot Widget API
        ---------------------------------
    ]]
    --[=[
        @class Plot
        Plot Widget API
    ]=]

    --[=[
        @within Plot
        @prop ProgressBar Axios.ProgressBar
        @tag Widget
        @tag HasState

        A progress bar line with a state value to show the current state.

        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "Progress Bar",
            Format: string? = nil -- optional to override with a custom progress such as `29/54`
        }
        Events = {
            hovered: () -> boolean,
            changed: () -> boolean
        }
        States = {
            progress: State<number>?
        }
        ```
    ]=]
    Axios.ProgressBar = wrapper("ProgressBar")

    --[=[
        @within Plot
        @prop PlotLines Axios.PlotLines
        @tag Widget
        @tag HasState

        A line graph for plotting a single line. Includes hovering to see a specific value on the graph,
        and automatic scaling. Has an overlay text option at the top of the plot for displaying any
        information.

        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "Plot Lines",
            Height: number? = 0,
            Min: number? = min, -- Axios will use the minimum value from the values
            Max: number? = max, -- Axios will use the maximum value from the values
            TextOverlay: string? = ""
        }
        Events = {
            hovered: () -> boolean
        }
        States = {
            values: State<{number}>?,
            hovered: State<{number}>? -- read-only property
        }
        ```
    ]=]
    Axios.PlotLines = wrapper("PlotLines")

    --[=[
        @within Plot
        @prop PlotHistogram Axios.PlotHistogram
        @tag Widget
        @tag HasState

        A hisogram graph for showing values. Includes hovering to see a specific block on the graph,
        and automatic scaling. Has an overlay text option at the top of the plot for displaying any
        information. Also supports a baseline option, which determines where the blocks start from.

        ```lua
        hasChildren = false
        hasState = true
        Arguments = {
            Text: string? = "Plot Histogram",
            Height: number? = 0,
            Min: number? = min, -- Axios will use the minimum value from the values
            Max: number? = max, -- Axios will use the maximum value from the values
            TextOverlay: string? = "",
            BaseLine: number? = 0 -- by default, blocks swap side at 0
        }
        Events = {
            hovered: () -> boolean
        }
        States = {
            values: State<{number}>?,
            hovered: State<{number}>? -- read-only property
        }
        ```
    ]=]
    Axios.PlotHistogram = wrapper("PlotHistogram")

    --[[
        ----------------------------------
            [SECTION] Table Widget API
        ----------------------------------
    ]]
    --[=[
        @class Table
        Table Widget API

        Example usage for creating a simple table:
        ```lua
        Axios.Table({ 4, true })
        do
            Axios.SetHeaderColumnIndex(1)

            -- for each row
            for i = 0, 10 do

                -- for each column
                for j = 1, 4 do
                    if i == 0 then
                        -- 
                        Axios.Text({ `H: {j}` })
                    else
                        Axios.Text({ `R: {i}, C: {j}` })
                    end

                    -- move the next column (and row when necessary)
                    Axios.NextColumn()
                end
            end
        ```
    ]=]

    --[=[
        @within Table
        @prop Table Axios.Table
        @tag Widget
        @tag HasChildren
        
        A layout widget which allows children to be displayed in configurable columns and rows. Highly configurable for many different
        options, with options for custom width columns as configured by the user, or automatically use the best size.

        When Resizable is enabled, the vertical columns can be dragged horizontally to increase or decrease space. This is linked to
        the widths state, which controls the width of each column. This is also dependent on whether the FixedWidth argument is enabled.
        By default, the columns will scale with the width of the table overall, therefore taking up a percentage, and the widths will be
        in the range of 0 to 1 as a float. If FixedWidth is enabled, then the widths will be in pixels and have a value of > 2 as an
        integer.

        ProportionalWidth determines whether each column has the same width, or individual. By default, each column will take up an equal
        proportion of the total table width. If true, then the columns will be allocated a width proportional to their total content size,
        meaning wider columns take up a greater share of the total available space. For a fixed width table, by default each column will
        take the max width of all the columns. When true, each column width will the minimum to fit the children within.

        LimitTableWidth is used when FixedWidth is true. It will cut off the table horizontally after the last column.

        :::info
        Once the NumColumns is set, it is not possible to change it without some extra code. The best way to do this is by using
        `Axios.PushConfig()` and `Axios.PopConfig()` which will automatically redraw the widget when the columns change.

        ```lua
        local numColumns = 4
        Axios.PushConfig({ columns = numColumns })
        Axios.Table({ numColumns, ...})
        do
            ...
        end
        Axios.End()
        Axios.PopConfig()
        ```

        :::danger Error: nil
        Always ensure that the number of elements in the widths state is greater or equal to the
        new number of columns when changing the number of columns.
        :::
        :::
        
        ```lua
        hasChildren = true
        hasState = false
        Arguments = {
            NumColumns: number, -- number of columns in the table, cannot be changed
            Header: boolean? = false, -- display a header row for each column
            RowBackground: boolean? = false, -- alternating row background colours
            OuterBorders: boolean? = false, -- outer border on the entire table
            InnerBorders: boolean? = false, -- inner bordres on the entire table
            Resizable: boolean? = false, -- the columns can be resized by dragging or state
            FixedWidth: boolean? = false, -- columns takes up a fixed pixel width, rather than a proportion of the total available
            ProportionalWidth: boolean? = false, -- minimises the width of each column individually
            LimitTableWidth: boolean? = false, -- when a fixed width, cut of any unused space
        }
        Events = {
            hovered: () -> boolean
        }
        States = {
            widths: State<{ number }>? -- the widths of each column if Resizable
        }
        ```
    ]=]
    Axios.Table = wrapper("Table")

    --[=[
        @within Table
        @function NextColumn
        
        In a table, moves to the next available cell. If the current cell is in the last column,
        then moves to the cell in the first column of the next row.
    ]=]
    Axios.NextColumn = function()
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.NextColumn() can only called when directly within a table.")

        local columnIndex = Table._columnIndex
        if columnIndex == Table.arguments.NumColumns then
            Table._columnIndex = 1
            Table._rowIndex += 1
        else
            Table._columnIndex += 1
        end
        return Table._columnIndex
    end

    --[=[
        @within Table
        @function NextRow
        
        In a table, moves to the cell in the first column of the next row.
    ]=]
    Axios.NextRow = function()
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.NextRow() can only called when directly within a table.")
        Table._columnIndex = 1
        Table._rowIndex += 1
        return Table._rowIndex
    end

    --[=[
        @within Table
        @function SetColumnIndex
        @param index number
        
        In a table, moves to the cell in the given column in the same previous row.

        Will erorr if the given index is not in the range of 1 to NumColumns.
    ]=]
    Axios.SetColumnIndex = function(index: number)
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.SetColumnIndex() can only called when directly within a table.")
        assert((index >= 1) and (index <= Table.arguments.NumColumns), `The index must be between 1 and {Table.arguments.NumColumns}, inclusive.`)
        Table._columnIndex = index
    end

    --[=[
        @within Table
        @function SetRowIndex
        @param index number

        In a table, moves to the cell in the given row with the same previous column.
    ]=]
    Axios.SetRowIndex = function(index: number)
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.SetRowIndex() can only called when directly within a table.")
        assert(index >= 1, "The index must be greater or equal to 1.")
        Table._rowIndex = index
    end

    --[=[
        @within Table
        @function NextHeaderColumn

        In a table, moves to the cell in the next column in the header row (row index 0). Will loop around
        from the last column to the first.
    ]=]
    Axios.NextHeaderColumn = function()
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.NextHeaderColumn() can only called when directly within a table.")

        Table._rowIndex = 0
        Table._columnIndex = (Table._columnIndex % Table.arguments.NumColumns) + 1

        return Table._columnIndex
    end

    --[=[
        @within Table
        @function SetHeaderColumnIndex
        @param index number

        In a table, moves to the cell in the given column in the header row (row index 0).

        Will erorr if the given index is not in the range of 1 to NumColumns.
    ]=]
    Axios.SetHeaderColumnIndex = function(index: number)
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.SetHeaderColumnIndex() can only called when directly within a table.")
        assert((index >= 1) and (index <= Table.arguments.NumColumns), `The index must be between 1 and {Table.arguments.NumColumns}, inclusive.`)

        Table._rowIndex = 0
        Table._columnIndex = index
    end

    --[=[
        @within Table
        @function SetColumnWidth
        @param index number
        @param width number

        In a table, sets the width of the given column to the given value by changing the
        Table's widths state. When the FixedWidth argument is true, the width should be in
        pixels >2, otherwise as a float between 0 and 1.

        Will erorr if the given index is not in the range of 1 to NumColumns.
    ]=]
    Axios.SetColumnWidth = function(index: number, width: number)
        local Table = Axios.Internal._GetParentWidget() :: Types.Table
        assert(Table ~= nil, "Axios.SetColumnWidth() can only called when directly within a table.")
        assert((index >= 1) and (index <= Table.arguments.NumColumns), `The index must be between 1 and {Table.arguments.NumColumns}, inclusive.`)

        local oldValue = Table.state.widths.value[index]
        Table.state.widths.value[index] = width
        Table.state.widths:set(Table.state.widths.value, width ~= oldValue)
    end
end

end

_modules["Axios.Internal"] = function()
    local script = create_mock_script("Axios.Internal")
    local require = axios_require
local Types = require(script.Parent.Types)

return function(Axios: Types.Axios): Types.Internal
    --[=[
        @class Internal
        An internal class within Axios containing all the backend data and functions for Axios to operate.
        It is recommended that you don't generally interact with Internal unless you understand what you are doing.
    ]=]
    local Internal = {} :: Types.Internal

    --[[
        ---------------------------------
            [SECTION] Properties
        ---------------------------------
    ]]

    Internal._version = [[ 2.5.1 ]]

    Internal._started = false -- has Axios.connect been called yet
    Internal._shutdown = false
    Internal._cycleTick = 0 -- increments for each call to Cycle, used to determine the relative age and freshness of generated widgets
    Internal._deltaTime = 0

    -- Refresh
    Internal._globalRefreshRequested = false -- refresh means that all GUI is destroyed and regenerated, usually because a style change was made and needed to be propogated to all UI
    Internal._refreshCounter = 0 -- if true, when _Insert is called, the widget called will be regenerated
    Internal._refreshLevel = 1
    Internal._refreshStack = table.create(16)

    -- Widgets & Instances
    Internal._widgets = {}
    Internal._stackIndex = 1 -- Points to the index that IDStack is currently in, when computing cycle
    Internal._rootInstance = nil
    Internal._rootWidget = {
        ID = "R",
        type = "Root",
        Instance = Internal._rootInstance,
        ZIndex = 0,
        ZOffset = 0,
    }
    Internal._lastWidget = Internal._rootWidget -- widget which was most recently rendered

    -- Config
    Internal._rootConfig = {} -- root style which all widgets derive from
    Internal._config = Internal._rootConfig

    -- ID
    Internal._IDStack = { "R" }
    Internal._usedIDs = {} -- hash of IDs which are already used in a cycle, value is the # of occurances so that getID can assign a unique ID for each occurance
    Internal._pushedIds = {}
    Internal._newID = false
    Internal._nextWidgetId = nil

    -- State
    Internal._states = {} -- Axios.States

    -- Callback
    Internal._postCycleCallbacks = {}
    Internal._connectedFunctions = {} -- functions which run each Axios cycle, connected by the user
    Internal._connections = {}
    Internal._initFunctions = {}

    -- Error
    Internal._fullErrorTracebacks = game:GetService("RunService"):IsStudio()

    --[=[
        @within Internal
        @prop _cycleCoroutine thread

        The thread which handles all connected functions. Each connection is within a pcall statement which prevents
        Axios from crashing and instead stopping at the error.
    ]=]
    Internal._cycleCoroutine = coroutine.create(function()
        while Internal._started do
            for _, callback in Internal._connectedFunctions do
                debug.profilebegin("Axios/Connection")
                local status, _error: string = pcall(callback)
                debug.profileend()
                if not status then
                    -- any error reserts the _stackIndex for the next frame and yields the error.
                    Internal._stackIndex = 1
                    coroutine.yield(false, _error)
                end
            end
            -- after all callbacks, we yield so it only runs once a frame.
            coroutine.yield(true)
        end
    end)

    --[[
        -----------------------
            [SECTION] State
        -----------------------
    ]]

    --[=[
        @class State
        This class wraps a value in getters and setters, its main purpose is to allow primatives to be passed as objects.
        Constructors for this class are available in [Axios]

        ```lua
        local state = Axios.State(0) -- we initialise the state with a value of 0

        -- these are equivalent. Ideally you should use `:get()` and ignore `.value`.
        print(state:get())
        print(state.value)

        state:set(state:get() + 1) -- increments the state by getting the current value and adding 1.

        state:onChange(function(newValue)
            print(`The value of the state is now: {newValue}`)
        end)
        ```

        :::caution Caution: Callbacks
        Never call `:set()` on a state when inside the `:onChange()` callback of the same state. This will cause a continous callback.

        Never chain states together so that each state changes the value of another state in a cyclic nature. This will cause a continous callback.
        :::
    ]=]
    local StateClass = {}
    StateClass.__index = StateClass

    --[=[
        @within State
        @method get<T>
        @return T

        Returns the states current value.
    ]=]
    function StateClass:get<T>() -- you can also simply use .value
        return self.value
    end

    --[=[
        @within State
        @method set<T>
        @param newValue T
        @param force boolean? -- force an update to all connections
        @return T

        Allows the caller to assign the state object a new value, and returns the new value.
    ]=]
    function StateClass:set<T>(newValue: T, force: true?)
        if newValue == self.value and force ~= true then
            -- no need to update on no change.
            return self.value
        end
        self.value = newValue
        self.lastChangeTick = Axios.Internal._cycleTick
        for _, thisWidget: Types.Widget in self.ConnectedWidgets do
            if thisWidget.lastCycleTick ~= -1 then
                Internal._widgets[thisWidget.type].UpdateState(thisWidget)
            end
        end

        for _, callback in self.ConnectedFunctions do
            callback(newValue)
        end
        return self.value
    end

    --[=[
        @within State
        @method onChange<T>
        @param callback (newValue: T) -> ()
        @return () -> ()

        Allows the caller to connect a callback which is called when the states value is changed.

        :::caution Caution: Single
        Calling `:onChange()` every frame will add a new function every frame.
        You must ensure you are only calling `:onChange()` once for each callback for the state's entire lifetime.
        :::
    ]=]
    function StateClass:onChange<T>(callback: (newValue: T) -> ())
        local connectionIndex: number = #self.ConnectedFunctions + 1
        self.ConnectedFunctions[connectionIndex] = callback
        return function()
            self.ConnectedFunctions[connectionIndex] = nil
        end
    end

    --[=[
        @within State
        @method changed<T>
        @return boolean

        Returns true if the state was changed on this frame.
    ]=]
    function StateClass:changed<T>()
        return self.lastChangeTick + 1 == Internal._cycleTick
    end

    Internal.StateClass = StateClass

    --[[
        ---------------------------
            [SECTION] Functions
        ---------------------------
    ]]

    --[=[
        @within Internal
        @function _cycle

        Called every frame to handle all of the widget management. Any previous frame data is ammended and everything updates.
    ]=]
    function Internal._cycle(deltaTime: number)
        -- debug.profilebegin("Axios/Cycle")
        if Axios.Disabled then
            return -- Stops all rendering, effectively freezes the current frame with no interaction.
        end

        Internal._rootWidget.lastCycleTick = Internal._cycleTick
        if Internal._rootInstance == nil or Internal._rootInstance.Parent == nil then
            Axios.ForceRefresh()
        end

        for _, widget in Internal._lastVDOM do
            if widget.lastCycleTick ~= Internal._cycleTick and (widget.lastCycleTick ~= -1) then
                -- a widget which used to be rendered was not called last frame, so we discard it.
                -- if the cycle tick is -1 we have already discarded it.
                Internal._DiscardWidget(widget)
            end
        end

        -- represents all widgets created last frame. We keep the _lastVDOM to reuse widgets from the previous frame
        -- rather than creating a new instance every frame.
        setmetatable(Internal._lastVDOM, { __mode = "kv" })
        Internal._lastVDOM = Internal._VDOM
        Internal._VDOM = Internal._generateEmptyVDOM()

        -- anything that wnats to run before the frame.
        task.spawn(function()
            -- debug.profilebegin("Axios/PostCycleCallbacks")
            for _, callback in Internal._postCycleCallbacks do
                callback()
            end
            -- debug.profileend()
        end)

        if Internal._globalRefreshRequested then
            -- rerender every widget
            --debug.profilebegin("Axios Refresh")
            Internal._generateSelectionImageObject()
            Internal._globalRefreshRequested = false
            for _, widget in Internal._lastVDOM do
                Internal._DiscardWidget(widget)
            end
            Internal._generateRootInstance()
            Internal._lastVDOM = Internal._generateEmptyVDOM()
            --debug.profileend()
        end

        -- update counters
        Internal._cycleTick += 1
        Internal._deltaTime = deltaTime
        table.clear(Internal._usedIDs)

        -- if Internal.parentInstance:IsA("GuiBase2d") and math.min(Internal.parentInstance.AbsoluteSize.X, Internal.parentInstance.AbsoluteSize.Y) < 100 then
        --     error("Axios Parent Instance is too small")
        -- end
        local compatibleParent = (Internal.parentInstance:IsA("GuiBase2d") or Internal.parentInstance:IsA("BasePlayerGui"))
        if compatibleParent == false then
            error("The Axios parent instance will not display any GUIs.")
        end

        -- if we are running in Studio, we want full error tracebacks, so we don't have
        -- any pcall to protect from an error.
        if Internal._fullErrorTracebacks then
            -- debug.profilebegin("Axios/Cycle/Callback")
            for _, callback in Internal._connectedFunctions do
                callback()
            end
        else
            -- debug.profilebegin("Axios/Cycle/Coroutine")

            -- each frame we check on our thread status.
            local coroutineStatus = coroutine.status(Internal._cycleCoroutine)
            if coroutineStatus == "suspended" then
                -- suspended means it yielded, either because it was a complete success
                -- or it caught an error in the code. We run it again for this frame.
                local _, success, result = coroutine.resume(Internal._cycleCoroutine)
                if success == false then
                    -- Connected function code errored
                    error(result, 0)
                end
            elseif coroutineStatus == "running" then
                -- still running (probably because of an asynchronous method inside a connection).
                error("Axios cycleCoroutine took to long to yield. Connected functions should not yield.")
            else
                -- should never reach this (nothing you can do).
                error("unrecoverable state")
            end
            -- debug.profileend()
        end

        if Internal._stackIndex ~= 1 then
            -- has to be larger than 1 because of the check that it isnt below 1 in Axios.End
            Internal._stackIndex = 1
            error("Too few calls to Axios.End().", 0)
        end

        -- Errors if the end user forgot to pop all their ids as they would leak over into the next frame
        -- could also just clear, but that might be confusing behaviour.
        if #Internal._pushedIds ~= 0 then
            error("Too few calls to Axios.PopId().", 0)
        end

        -- debug.profileend()
    end

    --[=[
        @within Internal
        @ignore
        @function _NoOp

        A dummy function which does nothing. Used as a placeholder for optional methods in a widget class.
        Used in `Internal.WidgetConstructor`
    ]=]
    function Internal._NoOp() end

    --  Widget

    --[=[
        @within Internal
        @function WidgetConstructor
        @param type string -- name used to denote the widget class.
        @param widgetClass Types.WidgetClass -- table of methods for the new widget.

        For each widget, a widget class is created which handles all the operations of a widget. This removes the class nature
        of widgets, and simplifies the available functions which can be applied to any widget. The widgets themselves are
        dumb tables containing all the data but no methods to handle any of the data apart from events.
    ]=]
    function Internal.WidgetConstructor(type: string, widgetClass: Types.WidgetClass)
        local Fields = {
            All = {
                Required = {
                    "Generate", -- generates the instance.
                    "Discard",
                    "Update",

                    -- not methods !
                    "Args",
                    "Events",
                    "hasChildren",
                    "hasState",
                },
                Optional = {},
            },
            IfState = {
                Required = {
                    "GenerateState",
                    "UpdateState",
                },
                Optional = {},
            },
            IfChildren = {
                Required = {
                    "ChildAdded", -- returns the parent of the child widget.
                },
                Optional = {
                    "ChildDiscarded",
                },
            },
        }

        -- we ensure all essential functions and properties are present, otherwise the code will break later.
        -- some functions will only be needed if the widget has children or has state.
        local thisWidget = {} :: Types.WidgetClass
        for _, field in Fields.All.Required do
            assert(widgetClass[field] ~= nil, `field {field} is missing from widget {type}, it is required for all widgets`)
            thisWidget[field] = widgetClass[field]
        end

        for _, field in Fields.All.Optional do
            if widgetClass[field] == nil then
                -- assign a dummy function which does nothing.
                thisWidget[field] = Internal._NoOp
            else
                thisWidget[field] = widgetClass[field]
            end
        end

        if widgetClass.hasState then
            for _, field in Fields.IfState.Required do
                assert(widgetClass[field] ~= nil, `field {field} is missing from widget {type}, it is required for all widgets with state`)
                thisWidget[field] = widgetClass[field]
            end
            for _, field in Fields.IfState.Optional do
                if widgetClass[field] == nil then
                    thisWidget[field] = Internal._NoOp
                else
                    thisWidget[field] = widgetClass[field]
                end
            end
        end

        if widgetClass.hasChildren then
            for _, field in Fields.IfChildren.Required do
                assert(widgetClass[field] ~= nil, `field {field} is missing from widget {type}, it is required for all widgets with children`)
                thisWidget[field] = widgetClass[field]
            end
            for _, field in Fields.IfChildren.Optional do
                if widgetClass[field] == nil then
                    thisWidget[field] = Internal._NoOp
                else
                    thisWidget[field] = widgetClass[field]
                end
            end
        end

        -- an internal table of all widgets to the widget class.
        Internal._widgets[type] = thisWidget
        -- allowing access to the index for each widget argument.
        Axios.Args[type] = thisWidget.Args

        local ArgNames = {}
        for index, argument in thisWidget.Args do
            ArgNames[argument] = index
        end
        thisWidget.ArgNames = ArgNames

        for index, _ in thisWidget.Events do
            if Axios.Events[index] == nil then
                Axios.Events[index] = function()
                    return Internal._EventCall(Internal._lastWidget, index)
                end
            end
        end
    end

    --[=[
        @within Internal
        @function _Insert
        @param widgetType: string -- name of widget class.
        @param arguments { [string]: number } -- arguments of the widget.
        @param states { [string]: States<any> }? -- states of the widget.
        @return Widget -- the widget.

        Every widget is created through _Insert. An ID is generated based on the line of the calling code and is used to
        find the previous frame widget if it exists. If no widget exists, a new one is created.
    ]=]
    function Internal._Insert(widgetType: string, args: Types.WidgetArguments?, states: Types.WidgetStates?)
        local ID = Internal._getID(3)
        --debug.profilebegin(ID)

        -- fetch the widget class which contains all the functions for the widget.
        local thisWidgetClass = Internal._widgets[widgetType]

        if Internal._VDOM[ID] then
            -- widget already created once this frame, so we can append to it.
            return Internal._ContinueWidget(ID, widgetType)
        end

        local arguments = {} :: Types.Arguments
        if args ~= nil then
            if type(args) ~= "table" then
                args = { args }
            end

            -- convert the arguments to a key-value dictionary so arguments can be referred to by their name and not index.
            for index, argument in args do
                assert(index > 0, `Widget Arguments must be a positive number, not {index} of type {typeof(index)} for {argument}.`)
                arguments[thisWidgetClass.ArgNames[index]] = argument
            end
        end
        -- prevents tampering with the arguments which are used to check for changes.
        table.freeze(arguments)

        local lastWidget = Internal._lastVDOM[ID]
        if lastWidget and widgetType == lastWidget.type then
            -- found a matching widget from last frame.
            if Internal._refreshCounter > 0 then
                -- we are redrawing every widget.
                Internal._DiscardWidget(lastWidget)
                lastWidget = nil
            end
        end
        local thisWidget = if lastWidget == nil then Internal._GenNewWidget(widgetType, arguments, states, ID) else lastWidget

        local parentWidget = thisWidget.parentWidget

        if thisWidget.type ~= "Window" and thisWidget.type ~= "Tooltip" then
            if thisWidget.ZIndex ~= parentWidget.ZOffset then
                parentWidget.ZUpdate = true
            end

            if parentWidget.ZUpdate then
                thisWidget.ZIndex = parentWidget.ZOffset
                if thisWidget.Instance then
                    thisWidget.Instance.ZIndex = thisWidget.ZIndex
                    thisWidget.Instance.LayoutOrder = thisWidget.ZIndex
                end
            end
        end

        -- since rows are not instances, but will be removed if not updated, we have to add specific table code.
        if parentWidget.type == "Table" then
            local Table = parentWidget :: Types.Table
            Table._rowCycles[Table._rowIndex] = Internal._cycleTick
        end

        if Internal._deepCompare(thisWidget.providedArguments, arguments) == false then
            -- the widgets arguments have changed, the widget should update to reflect changes.
            -- providedArguments is the frozen table which will not change.
            -- the arguments can be altered internally, which happens for the input widgets.
            thisWidget.arguments = Internal._deepCopy(arguments)
            thisWidget.providedArguments = arguments
            thisWidgetClass.Update(thisWidget)
        end

        thisWidget.lastCycleTick = Internal._cycleTick
        parentWidget.ZOffset += 1

        if thisWidgetClass.hasChildren then
            local thisParent = thisWidget :: Types.ParentWidget
            -- a parent widget, so we increase our depth.
            thisParent.ZOffset = 0
            thisParent.ZUpdate = false
            Internal._stackIndex += 1
            Internal._IDStack[Internal._stackIndex] = thisWidget.ID
        end

        Internal._VDOM[ID] = thisWidget
        Internal._lastWidget = thisWidget

        --debug.profileend()

        return thisWidget
    end

    --[=[
        @within Internal
        @function _GenNewWidget
        @param widgetType string
        @param arguments { [string]: any } -- arguments of the widget.
        @param states { [string]: State<any> }? -- states of the widget.
        @param ID ID -- id of the new widget. Determined in `Internal._Insert`
        @return Widget -- the newly created widget.

        All widgets are created as tables with properties. The widget class contains the functions to create the UI instances and
        update the widget or change state.
    ]=]
    function Internal._GenNewWidget(widgetType: string, arguments: Types.Arguments, states: Types.WidgetStates?, ID: Types.ID)
        local parentId = Internal._IDStack[Internal._stackIndex]
        local parentWidget: Types.ParentWidget = Internal._VDOM[parentId]
        local thisWidgetClass = Internal._widgets[widgetType]

        -- widgets are just tables with properties.
        local thisWidget = {} :: Types.Widget
        setmetatable(thisWidget, thisWidget)

        thisWidget.ID = ID
        thisWidget.type = widgetType
        thisWidget.parentWidget = parentWidget
        thisWidget.trackedEvents = {}
        -- thisWidget.UID = HttpService:GenerateGUID(false):sub(0, 8)

        -- widgets have lots of space to ensure they are always visible.
        thisWidget.ZIndex = parentWidget.ZOffset

        thisWidget.Instance = thisWidgetClass.Generate(thisWidget)
        -- tooltips set their parent in the generation method, so we need to udpate it here
        parentWidget = thisWidget.parentWidget

        if Internal._config.Parent then
            thisWidget.Instance.Parent = Internal._config.Parent
        else
            thisWidget.Instance.Parent = Internal._widgets[parentWidget.type].ChildAdded(parentWidget, thisWidget)
        end

        -- we can modify the arguments table, but keep a frozen copy to compare for user-end changes.
        thisWidget.providedArguments = arguments
        thisWidget.arguments = Internal._deepCopy(arguments)
        thisWidgetClass.Update(thisWidget)

        local eventMTParent
        if thisWidgetClass.hasState then
            local stateWidget = thisWidget :: Types.StateWidget
            if states then
                for index, state in states do
                    if not (type(state) == "table" and getmetatable(state :: any) == Internal.StateClass) then
                        -- generate a new state.
                        states[index] = Internal._widgetState(stateWidget, index, state)
                    end
                    states[index].lastChangeTick = Internal._cycleTick
                end

                stateWidget.state = states
                for _, state in states do
                    state.ConnectedWidgets[stateWidget.ID] = stateWidget
                end
            else
                stateWidget.state = {}
            end

            thisWidgetClass.GenerateState(stateWidget)
            thisWidgetClass.UpdateState(stateWidget)

            -- the state MT can't be itself because state has to explicitly only contain stateClass objects
            stateWidget.stateMT = {}
            setmetatable(stateWidget.state, stateWidget.stateMT)

            stateWidget.__index = stateWidget.state
            eventMTParent = stateWidget.stateMT
        else
            eventMTParent = thisWidget
        end

        eventMTParent.__index = function(_, eventName)
            return function()
                return Internal._EventCall(thisWidget, eventName)
            end
        end
        return thisWidget
    end

    --[=[
        @within Internal
        @function _ContinueWidget
        @param ID ID -- id of the widget.
        @param widgetType string
        @return Widget -- the widget.

        Since the widget has already been created this frame, we can just add it back to the stack. There is no checking of
        arguments or states.
        Basically equivalent to the end of `Internal._Insert`.
    ]=]
    function Internal._ContinueWidget(ID: Types.ID, widgetType: string)
        local thisWidgetClass = Internal._widgets[widgetType]
        local thisWidget = Internal._VDOM[ID]

        if thisWidgetClass.hasChildren then
            -- a parent widget so we increase our depth.
            Internal._stackIndex += 1
            Internal._IDStack[Internal._stackIndex] = thisWidget.ID
        end

        Internal._lastWidget = thisWidget
        return thisWidget
    end

    --[=[
        @within Internal
        @function _DiscardWidget
        @param widgetToDiscard Widget

        Destroys the widget instance and updates any parent. This happens if the widget was not called in the
        previous frame. There is no code which needs to update any widget tables since they are already reset
        at the start before discarding happens.
    ]=]
    function Internal._DiscardWidget(widgetToDiscard: Types.Widget)
        local widgetParent = widgetToDiscard.parentWidget
        if widgetParent then
            -- if the parent needs to update it's children.
            Internal._widgets[widgetParent.type].ChildDiscarded(widgetParent, widgetToDiscard)
        end

        -- using the widget class discard function.
        Internal._widgets[widgetToDiscard.type].Discard(widgetToDiscard)

        -- mark as discarded
        widgetToDiscard.lastCycleTick = -1
    end

    --[=[
        @within Internal
        @function _widgetState
        @param thisWidget Widget -- widget the state belongs to.
        @param stateName string
        @param initialValue any
        @return State<any> -- the state for the widget.

        Connects the state to the widget. If no state exists then a new one is created. Called for every state in every
        widget if the user does not provide a state.
    ]=]
    function Internal._widgetState<T>(thisWidget: Types.StateWidget, stateName: string, initialValue: T)
        local ID = thisWidget.ID .. stateName
        if Internal._states[ID] then
            Internal._states[ID].ConnectedWidgets[thisWidget.ID] = thisWidget
            Internal._states[ID].lastChangeTick = Internal._cycleTick
            return Internal._states[ID]
        else
            local newState = {
                ID = ID,
                value = initialValue,
                lastChangeTick = Internal._cycleTick,
                ConnectedWidgets = { [thisWidget.ID] = thisWidget },
                ConnectedFunctions = {},
            } :: Types.State<T>
            setmetatable(newState, Internal.StateClass)
            Internal._states[ID] = newState
            return newState
        end
    end

    --[=[
        @within Internal
        @function _EventCall
        @param thisWidget Widget
        @param evetName string
        @return boolean -- the value of the event.

        A wrapper for any event on any widget. Automatically, Axios does not initialize events unless they are explicitly
        called so in the first frame, the event connections are set up. Every event is a function which returns a boolean.
    ]=]
    function Internal._EventCall(thisWidget: Types.Widget, eventName: string)
        local Events = Internal._widgets[thisWidget.type].Events
        local Event = Events[eventName]
        assert(Event ~= nil, `widget {thisWidget.type} has no event of name {eventName}`)

        if thisWidget.trackedEvents[eventName] == nil then
            Event.Init(thisWidget)
            thisWidget.trackedEvents[eventName] = true
        end
        return Event.Get(thisWidget)
    end

    --[=[
        @within Internal
        @function _GetParentWidget
        @return Widget -- the parent widget

        Returns the parent widget of the currently active widget, based on the stack depth.
    ]=]
    function Internal._GetParentWidget(): Types.ParentWidget
        return Internal._VDOM[Internal._IDStack[Internal._stackIndex]]
    end

    -- Generate

    --[=[
        @ignore
        @within Internal
        @function _generateEmptyVDOM
        @return { [ID]: Widget }

        Creates the VDOM at the start of each frame containing just the root instance.
    ]=]
    function Internal._generateEmptyVDOM()
        return {
            ["R"] = Internal._rootWidget,
        }
    end

    --[=[
        @ignore
        @within Internal
        @function _generateRootInstance

        Creates the root instance.
    ]=]
    function Internal._generateRootInstance()
        -- unsafe to call before Internal.connect
        Internal._rootInstance = Internal._widgets["Root"].Generate(Internal._widgets["Root"])
        Internal._rootInstance.Parent = Internal.parentInstance
        Internal._rootWidget.Instance = Internal._rootInstance
    end

    --[=[
        @ignore
        @within Internal
        @function _generateSelctionImageObject

        Creates the selection object for buttons.
    ]=]
    function Internal._generateSelectionImageObject()
        if Internal.SelectionImageObject then
            Internal.SelectionImageObject:Destroy()
        end

        local SelectionImageObject = Instance.new("Frame")
        SelectionImageObject.Position = UDim2.fromOffset(-1, -1)
        SelectionImageObject.Size = UDim2.new(1, 2, 1, 2)
        SelectionImageObject.BackgroundColor3 = Internal._config.SelectionImageObjectColor
        SelectionImageObject.BackgroundTransparency = Internal._config.SelectionImageObjectTransparency
        SelectionImageObject.BorderSizePixel = 0

        Internal._utility.UIStroke(SelectionImageObject, 1, Internal._config.SelectionImageObjectBorderColor, Internal._config.SelectionImageObjectBorderTransparency)
        Internal._utility.UICorner(SelectionImageObject, 2)

        Internal.SelectionImageObject = SelectionImageObject
    end

    -- Utility

    --[=[
        @within Internal
        @function _getID
        @param levelsToIgnore number -- used to skip over internal calls to `_getID`.
        @return ID

        Generates a unique ID for each widget which is based on the line that the widget is
        created from. This ensures that the function is heuristic and always returns the same
        id for the same widget.
    ]=]
    function Internal._getID(levelsToIgnore: number)
        if Internal._nextWidgetId then
            local ID = Internal._nextWidgetId
            Internal._nextWidgetId = nil
            return ID
        end

        local i = 1 + (levelsToIgnore or 1)
        local ID = ""
        local levelInfo = debug.info(i, "l")
        while levelInfo ~= -1 and levelInfo ~= nil do
            ID ..= "+" .. levelInfo
            i += 1
            levelInfo = debug.info(i, "l")
        end

        local discriminator = Internal._usedIDs[ID]
        if discriminator then
            Internal._usedIDs[ID] += 1
            discriminator += 1
        else
            Internal._usedIDs[ID] = 1
            discriminator = 1
        end

        if #Internal._pushedIds == 0 then
            return ID .. ":" .. discriminator
        elseif Internal._newID then
            Internal._newID = false
            return ID .. "::" .. table.concat(Internal._pushedIds, "\\")
        else
            return ID .. ":" .. discriminator .. ":" .. table.concat(Internal._pushedIds, "\\")
        end
    end

    --[=[
        @ignore
        @within Internal
        @function _deepCompare
        @param t1 {}
        @param t2 {}
        @return boolean

        Compares two tables to check if they are the same. It uses a recursive iteration through one table
        to compare against the other. Used to determine if the arguments of a widget have changed since last
        frame.
    ]=]
    function Internal._deepCompare(t1: {}, t2: {})
        -- unoptimized ?
        for i, v1 in t1 do
            local v2 = t2[i]
            if type(v1) == "table" then
                if v2 and type(v2) == "table" then
                    if Internal._deepCompare(v1, v2) == false then
                        return false
                    end
                else
                    return false
                end
            else
                if type(v1) ~= type(v2) or v1 ~= v2 then
                    return false
                end
            end
        end

        return true
    end

    --[=[
        @ignore
        @within Internal
        @function _deepCopy
        @param t {}
        @return {}

        Performs a deep copy of a table so that neither table contains a shared reference.
    ]=]
    function Internal._deepCopy(t: {}): {}
        local copy: {} = table.clone(t)

        for k, v in t do
            if type(v) == "table" then
                copy[k] = Internal._deepCopy(v)
            end
        end

        return copy
    end

    -- VDOM
    Internal._lastVDOM = Internal._generateEmptyVDOM()
    Internal._VDOM = Internal._generateEmptyVDOM()

    Axios.Internal = Internal
    Axios._config = Internal._config
    return Internal
end

end

_modules["Axios.PubTypes"] = function()
    local script = create_mock_script("Axios.PubTypes")
    local require = axios_require
local Types = require(script.Parent.Types)

export type ID = Types.ID
export type State<T> = Types.State<T>

export type Widget = Types.Widget
export type Root = Types.Root
export type Window = Types.Window
export type Tooltip = Types.Tooltip
export type MenuBar = Types.MenuBar
export type Menu = Types.Menu
export type MenuItem = Types.MenuItem
export type MenuToggle = Types.MenuToggle
export type Separator = Types.Separator
export type Indent = Types.Indent
export type SameLine = Types.SameLine
export type Group = Types.Group
export type Text = Types.Text
export type SeparatorText = Types.SeparatorText
export type Button = Types.Button
export type Checkbox = Types.Checkbox
export type RadioButton = Types.RadioButton
export type Image = Types.Image
export type ImageButton = Types.ImageButton
export type Tree = Types.Tree
export type CollapsingHeader = Types.CollapsingHeader
export type TabBar = Types.TabBar
export type Tab = Types.Tab
export type Input<T> = Types.Input<T>
export type InputColor3 = Types.InputColor3
export type InputColor4 = Types.InputColor4
export type InputEnum = Types.InputEnum
export type InputText = Types.InputText
export type Selectable = Types.Selectable
export type Combo = Types.Combo
export type ProgressBar = Types.ProgressBar
export type PlotLines = Types.PlotLines
export type PlotHistogram = Types.PlotHistogram
export type Table = Types.Table

export type Axios = Types.Axios

return {}

end

_modules["Axios.Types"] = function()
    local script = create_mock_script("Axios.Types")
    local require = axios_require
local WidgetTypes = require(script.Parent.WidgetTypes)

export type ID = WidgetTypes.ID
export type State<T> = WidgetTypes.State<T>

export type Hovered = WidgetTypes.Hovered
export type Clicked = WidgetTypes.Clicked
export type RightClicked = WidgetTypes.RightClicked
export type DoubleClicked = WidgetTypes.DoubleClicked
export type CtrlClicked = WidgetTypes.CtrlClicked
export type Active = WidgetTypes.Active
export type Checked = WidgetTypes.Checked
export type Unchecked = WidgetTypes.Unchecked
export type Opened = WidgetTypes.Opened
export type Closed = WidgetTypes.Closed
export type Collapsed = WidgetTypes.Collapsed
export type Uncollapsed = WidgetTypes.Uncollapsed
export type Selected = WidgetTypes.Selected
export type Unselected = WidgetTypes.Unselected
export type Changed = WidgetTypes.Changed
export type NumberChanged = WidgetTypes.NumberChanged
export type TextChanged = WidgetTypes.TextChanged

export type Widget = WidgetTypes.Widget
export type ParentWidget = WidgetTypes.ParentWidget
export type StateWidget = WidgetTypes.StateWidget

export type Root = WidgetTypes.Root
export type Window = WidgetTypes.Window
export type Tooltip = WidgetTypes.Tooltip
export type MenuBar = WidgetTypes.MenuBar
export type Menu = WidgetTypes.Menu
export type MenuItem = WidgetTypes.MenuItem
export type MenuToggle = WidgetTypes.MenuToggle
export type Separator = WidgetTypes.Separator
export type Indent = WidgetTypes.Indent
export type SameLine = WidgetTypes.SameLine
export type Group = WidgetTypes.Group
export type Text = WidgetTypes.Text
export type SeparatorText = WidgetTypes.SeparatorText
export type Button = WidgetTypes.Button
export type Checkbox = WidgetTypes.Checkbox
export type RadioButton = WidgetTypes.RadioButton
export type Image = WidgetTypes.Image
export type ImageButton = WidgetTypes.ImageButton
export type Tree = WidgetTypes.Tree
export type CollapsingHeader = WidgetTypes.CollapsingHeader
export type TabBar = WidgetTypes.TabBar
export type Tab = WidgetTypes.Tab
export type Input<T> = WidgetTypes.Input<T>
export type InputColor3 = WidgetTypes.InputColor3
export type InputColor4 = WidgetTypes.InputColor4
export type InputEnum = WidgetTypes.InputEnum
export type InputText = WidgetTypes.InputText
export type Selectable = WidgetTypes.Selectable
export type Combo = WidgetTypes.Combo
export type ProgressBar = WidgetTypes.ProgressBar
export type PlotLines = WidgetTypes.PlotLines
export type PlotHistogram = WidgetTypes.PlotHistogram
export type Table = WidgetTypes.Table

export type InputDataType = number | Vector2 | Vector3 | UDim | UDim2 | Color3 | Rect | { number }

export type Argument = any
export type Arguments = {
    [string]: Argument,
    Text: string,
    TextHint: string,
    TextOverlay: string,
    ReadOnly: boolean,
    MultiLine: boolean,
    Wrapped: boolean,
    Color: Color3,
    RichText: boolean,

    Increment: InputDataType,
    Min: InputDataType,
    Max: InputDataType,
    Format: { string },
    UseFloats: boolean,
    UseHSV: boolean,
    UseHex: boolean,
    Prefix: { string },
    BaseLine: number,

    Width: number,
    Height: number,
    VerticalAlignment: Enum.VerticalAlignment,
    HorizontalAlignment: Enum.HorizontalAlignment,
    Index: any,
    Image: string,
    Size: UDim2,
    Rect: Rect,
    ScaleType: Enum.ScaleType,
    TileSize: UDim2,
    SliceCenter: Rect,
    SliceScale: number,
    ResampleMode: Enum.ResamplerMode,

    SpanAvailWidth: boolean,
    NoIdent: boolean,
    NoClick: boolean,
    NoButtons: boolean,
    NoButton: boolean,
    NoPreview: boolean,

    NumColumns: number,
    RowBg: boolean,
    BordersOuter: boolean,
    BordersInner: boolean,

    Title: string,
    NoTitleBar: boolean,
    NoBackground: boolean,
    NoCollapse: boolean,
    NoClose: boolean,
    NoMove: boolean,
    NoScrollbar: boolean,
    NoResize: boolean,
    NoMenu: boolean,

    KeyCode: Enum.KeyCode,
    ModifierKey: Enum.ModifierKey,
    Disabled: boolean,
}

export type States = {
    [string]: State<any>,
    number: State<number>,
    color: State<Color3>,
    transparency: State<number>,
    editingText: State<boolean>,
    index: State<any>,

    size: State<Vector2>,
    position: State<Vector2>,
    progress: State<number>,
    scrollDistance: State<number>,

    isChecked: State<boolean>,
    isOpened: State<boolean>,
    isUncollapsed: State<boolean>,
}

export type Event = {
    Init: (Widget) -> (),
    Get: (Widget) -> boolean,
}
export type Events = { [string]: Event }

-- Widgets

export type WidgetArguments = { [number]: Argument }
export type WidgetStates = {
    [string]: State<any>,
    number: State<number>?,
    color: State<Color3>?,
    transparency: State<number>?,
    editingText: State<boolean>?,
    index: State<any>?,

    size: State<Vector2>?,
    position: State<Vector2>?,
    progress: State<number>?,
    scrollDistance: State<number>?,
    values: State<number>?,

    isChecked: State<boolean>?,
    isOpened: State<boolean>?,
    isUncollapsed: State<boolean>?,
}

export type WidgetClass = {
    Generate: (thisWidget: Widget) -> GuiObject,
    Discard: (thisWidget: Widget) -> (),
    Update: (thisWidget: Widget, ...any) -> (),

    Args: { [string]: number },
    Events: Events,
    hasChildren: boolean,
    hasState: boolean,
    ArgNames: { [number]: string },

    GenerateState: (thisWidget: Widget) -> (),
    UpdateState: (thisWidget: Widget) -> (),

    ChildAdded: (thisWidget: Widget, thisChild: Widget) -> GuiObject,
    ChildDiscarded: (thisWidget: Widget, thisChild: Widget) -> (),
}

-- Axios

export type Internal = {
    --[[
        --------------
          PROPERTIES
        --------------
    ]]
    _version: string,
    _started: boolean,
    _shutdown: boolean,
    _cycleTick: number,
    _deltaTime: number,
    _eventConnection: RBXScriptConnection?,

    -- Refresh
    _globalRefreshRequested: boolean,
    _refreshCounter: number,
    _refreshLevel: number,
    _refreshStack: { boolean },

    -- Widgets & Instances
    _widgets: { [string]: WidgetClass },
    _widgetCount: number,
    _stackIndex: number,
    _rootInstance: GuiObject?,
    _rootWidget: ParentWidget,
    _lastWidget: Widget,
    SelectionImageObject: Frame,
    parentInstance: BasePlayerGui | GuiBase2d,
    _utility: WidgetUtility,

    -- Config
    _rootConfig: Config,
    _config: Config,

    -- ID
    _IDStack: { ID },
    _usedIDs: { [ID]: number },
    _newID: boolean,
    _pushedIds: { ID },
    _nextWidgetId: ID?,

    -- VDOM
    _lastVDOM: { [ID]: Widget },
    _VDOM: { [ID]: Widget },

    -- State
    _states: { [ID]: State<any> },

    -- Callback
    _postCycleCallbacks: { () -> () },
    _connectedFunctions: { () -> () },
    _connections: { RBXScriptConnection },
    _initFunctions: { () -> () },
    _cycleCoroutine: thread?,

    --[[
        ---------
          STATE
        ---------
    ]]

    StateClass: {
        __index: any,

        get: <T>(self: State<T>) -> any,
        set: <T>(self: State<T>, newValue: any) -> any,
        onChange: <T>(self: State<T>, callback: (newValue: any) -> ()) -> (),
    },

    --[[
        -------------
          FUNCTIONS
        -------------
    ]]
    _cycle: (deltaTime: number) -> (),
    _NoOp: () -> (),

    -- Widget
    WidgetConstructor: (type: string, widgetClass: WidgetClass) -> (),
    _Insert: (widgetType: string, arguments: WidgetArguments?, states: WidgetStates?) -> Widget,
    _GenNewWidget: (widgetType: string, arguments: Arguments, states: WidgetStates?, ID: ID) -> Widget,
    _ContinueWidget: (ID: ID, widgetType: string) -> Widget,
    _DiscardWidget: (widgetToDiscard: Widget) -> (),

    _widgetState: (thisWidget: Widget, stateName: string, initialValue: any) -> State<any>,
    _EventCall: (thisWidget: Widget, eventName: string) -> boolean,
    _GetParentWidget: () -> ParentWidget,
    SetFocusedWindow: (thisWidget: WidgetTypes.Window?) -> (),

    -- Generate
    _generateEmptyVDOM: () -> { [ID]: Widget },
    _generateRootInstance: () -> (),
    _generateSelectionImageObject: () -> (),

    -- Utility
    _getID: (levelsToIgnore: number) -> ID,
    _deepCompare: (t1: {}, t2: {}) -> boolean,
    _deepCopy: (t: {}) -> {},
}

export type WidgetUtility = {
    GuiService: GuiService,
    RunService: RunService,
    TextService: TextService,
    UserInputService: UserInputService,
    ContextActionService: ContextActionService,

    getTime: () -> number,
    getMouseLocation: () -> Vector2,

    ICONS: {
        BLANK_SQUARE: string,
        RIGHT_POINTING_TRIANGLE: string,
        DOWN_POINTING_TRIANGLE: string,
        MULTIPLICATION_SIGN: string,
        BOTTOM_RIGHT_CORNER: string,
        CHECKMARK: string,
        BORDER: string,
        ALPHA_BACKGROUND_TEXTURE: string,
        UNKNOWN_TEXTURE: string,
    },

    GuiOffset: Vector2,
    MouseOffset: Vector2,

    findBestWindowPosForPopup: (refPos: Vector2, size: Vector2, outerMin: Vector2, outerMax: Vector2) -> Vector2,
    getScreenSizeForWindow: (thisWidget: Widget) -> Vector2,
    isPosInsideRect: (pos: Vector2, rectMin: Vector2, rectMax: Vector2) -> boolean,
    extend: (superClass: WidgetClass, { [any]: any }) -> WidgetClass,
    discardState: (thisWidget: Widget) -> (),

    UIPadding: (Parent: GuiObject, PxPadding: Vector2) -> UIPadding,
    UIListLayout: (Parent: GuiObject, FillDirection: Enum.FillDirection, Padding: UDim) -> UIListLayout,
    UIStroke: (Parent: GuiObject, Thickness: number, Color: Color3, Transparency: number) -> UIStroke,
    UICorner: (Parent: GuiObject, PxRounding: number?) -> UICorner,
    UISizeConstraint: (Parent: GuiObject, MinSize: Vector2?, MaxSize: Vector2?) -> UISizeConstraint,

    applyTextStyle: (thisInstance: TextLabel | TextButton | TextBox) -> (),
    applyInteractionHighlights: (Property: string, Button: GuiButton, Highlightee: GuiObject, Colors: { [string]: any }) -> (),
    applyInteractionHighlightsWithMultiHighlightee: (Property: string, Button: GuiButton, Highlightees: { { GuiObject | { [string]: Color3 | number } } }) -> (),
    applyFrameStyle: (thisInstance: GuiObject, noPadding: boolean?, noCorner: boolean?) -> (),

    applyButtonClick: (thisInstance: GuiButton, callback: () -> ()) -> (),
    applyButtonDown: (thisInstance: GuiButton, callback: (x: number, y: number) -> ()) -> (),
    applyMouseEnter: (thisInstance: GuiObject, callback: (x: number, y: number) -> ()) -> (),
    applyMouseMoved: (thisInstance: GuiObject, callback: (x: number, y: number) -> ()) -> (),
    applyMouseLeave: (thisInstance: GuiObject, callback: (x: number, y: number) -> ()) -> (),
    applyInputBegan: (thisInstance: GuiObject, callback: (input: InputObject) -> ()) -> (),
    applyInputEnded: (thisInstance: GuiObject, callback: (input: InputObject) -> ()) -> (),

    registerEvent: (event: string, callback: (...any) -> ()) -> (),

    EVENTS: {
        hover: (pathToHovered: (thisWidget: Widget & Hovered) -> GuiObject) -> Event,
        click: (pathToClicked: (thisWidget: Widget & Clicked) -> GuiButton) -> Event,
        rightClick: (pathToClicked: (thisWidget: Widget & RightClicked) -> GuiButton) -> Event,
        doubleClick: (pathToClicked: (thisWidget: Widget & DoubleClicked) -> GuiButton) -> Event,
        ctrlClick: (pathToClicked: (thisWidget: Widget & CtrlClicked) -> GuiButton) -> Event,
    },

    abstractButton: WidgetClass,
}

export type Config = {
    TextColor: Color3,
    TextTransparency: number,
    TextDisabledColor: Color3,
    TextDisabledTransparency: number,

    BorderColor: Color3,
    BorderActiveColor: Color3,
    BorderTransparency: number,
    BorderActiveTransparency: number,

    WindowBgColor: Color3,
    WindowBgTransparency: number,
    ScrollbarGrabColor: Color3,
    ScrollbarGrabTransparency: number,
    PopupBgColor: Color3,
    PopupBgTransparency: number,

    TitleBgColor: Color3,
    TitleBgTransparency: number,
    TitleBgActiveColor: Color3,
    TitleBgActiveTransparency: number,
    TitleBgCollapsedColor: Color3,
    TitleBgCollapsedTransparency: number,

    MenubarBgColor: Color3,
    MenubarBgTransparency: number,

    FrameBgColor: Color3,
    FrameBgTransparency: number,
    FrameBgHoveredColor: Color3,
    FrameBgHoveredTransparency: number,
    FrameBgActiveColor: Color3,
    FrameBgActiveTransparency: number,

    ButtonColor: Color3,
    ButtonTransparency: number,
    ButtonHoveredColor: Color3,
    ButtonHoveredTransparency: number,
    ButtonActiveColor: Color3,
    ButtonActiveTransparency: number,

    ImageColor: Color3,
    ImageTransparency: number,

    SliderGrabColor: Color3,
    SliderGrabTransparency: number,
    SliderGrabActiveColor: Color3,
    SliderGrabActiveTransparency: number,

    HeaderColor: Color3,
    HeaderTransparency: number,
    HeaderHoveredColor: Color3,
    HeaderHoveredTransparency: number,
    HeaderActiveColor: Color3,
    HeaderActiveTransparency: number,

    TabColor: Color3,
    TabTransparency: number,
    TabHoveredColor: Color3,
    TabHoveredTransparency: number,
    TabActiveColor: Color3,
    TabActiveTransparency: number,

    SelectionImageObjectColor: Color3,
    SelectionImageObjectTransparency: number,
    SelectionImageObjectBorderColor: Color3,
    SelectionImageObjectBorderTransparency: number,

    TableBorderStrongColor: Color3,
    TableBorderStrongTransparency: number,
    TableBorderLightColor: Color3,
    TableBorderLightTransparency: number,
    TableRowBgColor: Color3,
    TableRowBgTransparency: number,
    TableRowBgAltColor: Color3,
    TableRowBgAltTransparency: number,
    TableHeaderColor: Color3,
    TableHeaderTransparency: number,

    NavWindowingHighlightColor: Color3,
    NavWindowingHighlightTransparency: number,
    NavWindowingDimBgColor: Color3,
    NavWindowingDimBgTransparency: number,

    SeparatorColor: Color3,
    SeparatorTransparency: number,

    CheckMarkColor: Color3,
    CheckMarkTransparency: number,

    PlotLinesColor: Color3,
    PlotLinesTransparency: number,
    PlotLinesHoveredColor: Color3,
    PlotLinesHoveredTransparency: number,
    PlotHistogramColor: Color3,
    PlotHistogramTransparency: number,
    PlotHistogramHoveredColor: Color3,
    PlotHistogramHoveredTransparency: number,

    ResizeGripColor: Color3,
    ResizeGripTransparency: number,
    ResizeGripHoveredColor: Color3,
    ResizeGripHoveredTransparency: number,
    ResizeGripActiveColor: Color3,
    ResizeGripActiveTransparency: number,

    HoverColor: Color3,
    HoverTransparency: number,

    -- Sizes
    ItemWidth: UDim,
    ContentWidth: UDim,
    ContentHeight: UDim,

    WindowPadding: Vector2,
    WindowResizePadding: Vector2,
    FramePadding: Vector2,
    ItemSpacing: Vector2,
    ItemInnerSpacing: Vector2,
    CellPadding: Vector2,
    DisplaySafeAreaPadding: Vector2,
    IndentSpacing: number,
    SeparatorTextPadding: Vector2,

    TextFont: Font,
    TextSize: number,
    FrameBorderSize: number,
    FrameRounding: number,
    GrabRounding: number,
    WindowBorderSize: number,
    WindowTitleAlign: Enum.LeftRight,
    PopupBorderSize: number,
    PopupRounding: number,
    ScrollbarSize: number,
    GrabMinSize: number,
    SeparatorTextBorderSize: number,
    ImageBorderSize: number,

    UseScreenGUIs: boolean,
    IgnoreGuiInset: boolean,
    ScreenInsets: Enum.ScreenInsets,
    Parent: BasePlayerGui,
    RichText: boolean,
    TextWrapped: boolean,
    DisplayOrderOffset: number,
    ZIndexOffset: number,

    MouseDoubleClickTime: number,
    MouseDoubleClickMaxDist: number,
    MouseDragThreshold: number,
}

type WidgetCall<W, A, S, E...> = (arguments: A, states: S, E...) -> W

export type Axios = {
    --[[
        -----------
          WIDGETS
        -----------
    ]]

    End: () -> (),

    -- Window API
    Window: WidgetCall<Window, WidgetArguments, WidgetStates?>,
    Tooltip: WidgetCall<Tooltip, WidgetArguments, nil>,

    -- Menu Widget API
    MenuBar: () -> Widget,
    Menu: WidgetCall<Menu, WidgetArguments, WidgetStates?>,
    MenuItem: WidgetCall<MenuItem, WidgetArguments, nil>,
    MenuToggle: WidgetCall<MenuToggle, WidgetArguments, WidgetStates?>,

    -- Format Widget API
    Separator: () -> Separator,
    Indent: (arguments: WidgetArguments?) -> Indent,
    SameLine: (arguments: WidgetArguments?) -> SameLine,
    Group: () -> Group,

    -- Text Widget API
    Text: WidgetCall<Text, WidgetArguments, nil>,
    TextWrapped: WidgetCall<Text, WidgetArguments, nil>,
    TextColored: WidgetCall<Text, WidgetArguments, nil>,
    SeparatorText: WidgetCall<SeparatorText, WidgetArguments, nil>,
    InputText: WidgetCall<InputText, WidgetArguments, WidgetStates?>,

    -- Basic Widget API
    Button: WidgetCall<Button, WidgetArguments, nil>,
    SmallButton: WidgetCall<Button, WidgetArguments, nil>,
    Checkbox: WidgetCall<Checkbox, WidgetArguments, WidgetStates?>,
    RadioButton: WidgetCall<RadioButton, WidgetArguments, WidgetStates?>,

    -- Tree Widget API
    Tree: WidgetCall<Tree, WidgetArguments, WidgetStates?>,
    CollapsingHeader: WidgetCall<CollapsingHeader, WidgetArguments, WidgetStates?>,

    -- Tab Widget API
    TabBar: WidgetCall<TabBar, WidgetArguments?, WidgetStates?>,
    Tab: WidgetCall<Tab, WidgetArguments, WidgetStates?>,

    -- Input Widget API
    InputNum: WidgetCall<Input<number>, WidgetArguments, WidgetStates?>,
    InputVector2: WidgetCall<Input<Vector2>, WidgetArguments, WidgetStates?>,
    InputVector3: WidgetCall<Input<Vector3>, WidgetArguments, WidgetStates?>,
    InputUDim: WidgetCall<Input<UDim>, WidgetArguments, WidgetStates?>,
    InputUDim2: WidgetCall<Input<UDim2>, WidgetArguments, WidgetStates?>,
    InputRect: WidgetCall<Input<Rect>, WidgetArguments, WidgetStates?>,
    InputColor3: WidgetCall<InputColor3, WidgetArguments, WidgetStates?>,
    InputColor4: WidgetCall<InputColor4, WidgetArguments, WidgetStates?>,

    -- Drag Widget API
    DragNum: WidgetCall<Input<number>, WidgetArguments, WidgetStates?>,
    DragVector2: WidgetCall<Input<Vector2>, WidgetArguments, WidgetStates?>,
    DragVector3: WidgetCall<Input<Vector3>, WidgetArguments, WidgetStates?>,
    DragUDim: WidgetCall<Input<UDim>, WidgetArguments, WidgetStates?>,
    DragUDim2: WidgetCall<Input<UDim2>, WidgetArguments, WidgetStates?>,
    DragRect: WidgetCall<Input<Rect>, WidgetArguments, WidgetStates?>,

    -- Slider Widget API
    SliderNum: WidgetCall<Input<number>, WidgetArguments, WidgetStates?>,
    SliderVector2: WidgetCall<Input<Vector2>, WidgetArguments, WidgetStates?>,
    SliderVector3: WidgetCall<Input<Vector3>, WidgetArguments, WidgetStates?>,
    SliderUDim: WidgetCall<Input<UDim>, WidgetArguments, WidgetStates?>,
    SliderUDim2: WidgetCall<Input<UDim2>, WidgetArguments, WidgetStates?>,
    SliderRect: WidgetCall<Input<Rect>, WidgetArguments, WidgetStates?>,

    -- Combo Widget Widget API
    Selectable: WidgetCall<Selectable, WidgetArguments, WidgetStates?>,
    Combo: WidgetCall<Combo, WidgetArguments, WidgetStates?>,
    ComboArray: WidgetCall<Combo, WidgetArguments, WidgetStates?, { any }>,
    ComboEnum: WidgetCall<Combo, WidgetArguments, WidgetStates?, Enum>,
    InputEnum: WidgetCall<Combo, WidgetArguments, WidgetStates?, Enum>,

    ProgressBar: WidgetCall<ProgressBar, WidgetArguments, WidgetStates?>,
    PlotLines: WidgetCall<PlotLines, WidgetArguments, WidgetStates?>,
    PlotHistogram: WidgetCall<PlotHistogram, WidgetArguments, WidgetStates?>,

    Image: WidgetCall<Image, WidgetArguments, nil>,
    ImageButton: WidgetCall<ImageButton, WidgetArguments, nil>,

    -- Table Widget Api
    Table: WidgetCall<Table, WidgetArguments, WidgetStates?>,
    NextColumn: () -> number,
    NextRow: () -> number,
    SetColumnIndex: (index: number) -> (),
    SetRowIndex: (index: number) -> (),
    NextHeaderColumn: () -> number,
    SetHeaderColumnIndex: (index: number) -> (),
    SetColumnWidth: (index: number, width: number) -> (),

    --[[
        ---------
          STATE
        ---------
    ]]

    State: <T>(initialValue: T) -> State<T>,
    WeakState: <T>(initialValue: T) -> T,
    VariableState: <T>(variable: T, callback: (T) -> ()) -> State<T>,
    TableState: <K, V>(tab: { [K]: V }, key: K, callback: ((newValue: V) -> true?)?) -> State<V>,
    ComputedState: <T, U>(firstState: State<T>, onChangeCallback: (firstValue: T) -> U) -> State<U>,

    --[[
        -------------
          FUNCTIONS
        -------------
    ]]

    Init: (parentInstance: BasePlayerGui | GuiBase2d?, eventConnection: (RBXScriptSignal | (() -> number) | false)?, allowMultipleInits: boolean) -> Axios,
    Shutdown: () -> (),
    Connect: (self: Axios, callback: () -> ()) -> () -> (),
    Append: (userInstance: GuiObject) -> (),
    ForceRefresh: () -> (),

    -- Widget
    SetFocusedWindow: (thisWidget: Window?) -> (),

    -- ID API
    PushId: (ID: ID) -> (),
    PopId: () -> (),
    SetNextWidgetID: (ID: ID) -> (),

    -- Config API
    UpdateGlobalConfig: (deltaStyle: { [string]: any }) -> (),
    PushConfig: (deltaStyle: { [string]: any }) -> (),
    PopConfig: () -> (),

    --[[
        --------------
          PROPERTIES
        --------------
    ]]

    Internal: Internal,
    Disabled: boolean,
    Args: { [string]: { [string]: number } },
    Events: { [string]: () -> boolean },

    TemplateConfig: { [string]: Config },
    _config: Config,
    ShowDemoWindow: () -> Window,
}

return {}

end

_modules["Axios.WidgetTypes"] = function()
    local script = create_mock_script("Axios.WidgetTypes")
    local require = axios_require
--[=[
    @within Axios
    @type ID string
]=]
export type ID = string

--[=[
    @within State
    @type State<T> { ID: ID, value: T, get: (self) -> T, set: (self, newValue: T) -> T, onChange: (self, callback: (newValue: T) -> ()) -> (), ConnectedWidgets: { [ID]: Widget }, ConnectedFunctions: { (newValue: T) -> () } }
]=]
export type State<T> = {
    ID: ID,
    value: T,
    lastChangeTick: number,
    ConnectedWidgets: { [ID]: Widget },
    ConnectedFunctions: { (newValue: T) -> () },

    get: (self: State<T>) -> T,
    set: (self: State<T>, newValue: T, force: true?) -> (),
    onChange: (self: State<T>, funcToConnect: (newValue: T) -> ()) -> () -> (),
    changed: (self: State<T>) -> boolean,
}

--[=[
    @within Axios
    @type Widget { ID: ID, type: string, lastCycleTick: number, parentWidget: Widget, Instance: GuiObject, ZIndex: number, arguments: { [string]: any }}
]=]
export type Widget = {
    ID: ID,
    type: string,
    lastCycleTick: number,
    trackedEvents: {},
    parentWidget: ParentWidget,

    arguments: {},
    providedArguments: {},

    Instance: GuiObject,
    ZIndex: number,
}

export type ParentWidget = Widget & {
    ChildContainer: GuiObject,
    ZOffset: number,
    ZUpdate: boolean,
}

export type StateWidget = Widget & {
    state: {
        [string]: State<any>,
    },
}

-- Events

export type Hovered = {
    isHoveredEvent: boolean,
    hovered: () -> boolean,
}

export type Clicked = {
    lastClickedTick: number,
    clicked: () -> boolean,
}

export type RightClicked = {
    lastRightClickedTick: number,
    rightClicked: () -> boolean,
}

export type DoubleClicked = {
    lastClickedTime: number,
    lastClickedPosition: Vector2,
    lastDoubleClickedTick: number,
    doubleClicked: () -> boolean,
}

export type CtrlClicked = {
    lastCtrlClickedTick: number,
    ctrlClicked: () -> boolean,
}

export type Active = {
    active: () -> boolean,
}

export type Checked = {
    lastCheckedTick: number,
    checked: () -> boolean,
}

export type Unchecked = {
    lastUncheckedTick: number,
    unchecked: () -> boolean,
}

export type Opened = {
    lastOpenedTick: number,
    opened: () -> boolean,
}

export type Closed = {
    lastClosedTick: number,
    closed: () -> boolean,
}

export type Collapsed = {
    lastCollapsedTick: number,
    collapsed: () -> boolean,
}

export type Uncollapsed = {
    lastUncollapsedTick: number,
    uncollapsed: () -> boolean,
}

export type Selected = {
    lastSelectedTick: number,
    selected: () -> boolean,
}

export type Unselected = {
    lastUnselectedTick: number,
    unselected: () -> boolean,
}

export type Changed = {
    lastChangedTick: number,
    changed: () -> boolean,
}

export type NumberChanged = {
    lastNumberChangedTick: number,
    numberChanged: () -> boolean,
}

export type TextChanged = {
    lastTextChangedTick: number,
    textChanged: () -> boolean,
}

-- Widgets

-- Window

export type Root = ParentWidget

export type Window = ParentWidget & {
    usesScreenGuis: boolean,

    arguments: {
        Title: string?,
        NoTitleBar: boolean?,
        NoBackground: boolean?,
        NoCollapse: boolean?,
        NoClose: boolean?,
        NoMove: boolean?,
        NoScrollbar: boolean?,
        NoResize: boolean?,
        NoNav: boolean?,
        NoMenu: boolean?,
    },

    state: {
        size: State<Vector2>,
        position: State<Vector2>,
        isUncollapsed: State<boolean>,
        isOpened: State<boolean>,
        scrollDistance: State<number>,
    },
} & Opened & Closed & Collapsed & Uncollapsed & Hovered

export type Tooltip = Widget & {
    arguments: {
        Text: string,
    },
}

-- Menu

export type MenuBar = ParentWidget

export type Menu = ParentWidget & {
    ButtonColors: { [string]: Color3 | number },

    arguments: {
        Text: string?,
    },

    state: {
        isOpened: State<boolean>,
    },
} & Clicked & Opened & Closed & Hovered

export type MenuItem = Widget & {
    arguments: {
        Text: string,
        KeyCode: Enum.KeyCode?,
        ModifierKey: Enum.ModifierKey?,
    },
} & Clicked & Hovered

export type MenuToggle = Widget & {
    arguments: {
        Text: string,
        KeyCode: Enum.KeyCode?,
        ModifierKey: Enum.ModifierKey?,
    },

    state: {
        isChecked: State<boolean>,
    },
} & Checked & Unchecked & Hovered

-- Format

export type Separator = Widget

export type Indent = ParentWidget & {
    arguments: {
        Width: number?,
    },
}

export type SameLine = ParentWidget & {
    arguments: {
        Width: number?,
        VerticalAlignment: Enum.VerticalAlignment?,
        HorizontalAlignment: Enum.HorizontalAlignment?,
    },
}

export type Group = ParentWidget

-- Text

export type Text = Widget & {
    arguments: {
        Text: string,
        Wrapped: boolean?,
        Color: Color3?,
        RichText: boolean?,
    },
} & Hovered

export type SeparatorText = Widget & {
    arguments: {
        Text: string,
    },
} & Hovered

-- Basic

export type Button = Widget & {
    arguments: {
        Text: string?,
        Size: UDim2?,
    },
} & Clicked & RightClicked & DoubleClicked & CtrlClicked & Hovered

export type Checkbox = Widget & {
    arguments: {
        Text: string?,
    },

    state: {
        isChecked: State<boolean>,
    },
} & Unchecked & Checked & Hovered

export type RadioButton = Widget & {
    arguments: {
        Text: string?,
        Index: any,
    },

    state: {
        index: State<any>,
    },

    active: () -> boolean,
} & Selected & Unselected & Active & Hovered

-- Image

export type Image = Widget & {
    arguments: {
        Image: string,
        Size: UDim2,
        Rect: Rect?,
        ScaleType: Enum.ScaleType?,
        TileSize: UDim2?,
        SliceCenter: Rect?,
        SliceScale: number?,
        ResampleMode: Enum.ResamplerMode?,
    },
} & Hovered

-- ooops, may have overriden a Roblox type, and then got a weird type message
-- let's just hope I don't have to use a Roblox ImageButton type anywhere by name in this file
export type ImageButton = Image & Clicked & RightClicked & DoubleClicked & CtrlClicked

-- Tree

export type Tree = CollapsingHeader & {
    arguments: {
        Text: string,
        SpanAvailWidth: boolean?,
        NoIndent: boolean?,
        DefaultOpen: true?,
    },
}

export type CollapsingHeader = ParentWidget & {
    arguments: {
        Text: string?,
        DefaultOpen: true?,
    },

    state: {
        isUncollapsed: State<boolean>,
    },
} & Collapsed & Uncollapsed & Hovered

-- Tabs

export type TabBar = ParentWidget & {
    Tabs: { Tab },

    state: {
        index: State<number>,
    },
}

export type Tab = ParentWidget & {
    parentWidget: TabBar,
    Index: number,
    ButtonColors: { [string]: Color3 | number },

    arguments: {
        Text: string,
        Hideable: boolean,
    },

    state: {
        index: State<number>,
        isOpened: State<boolean>,
    },
} & Clicked & Opened & Selected & Unselected & Active & Closed & Hovered

-- Input
export type Input<T> = Widget & {
    lastClickedTime: number,
    lastClickedPosition: Vector2,

    arguments: {
        Text: string?,
        Increment: T,
        Min: T,
        Max: T,
        Format: { string },
        Prefix: { string },
        NoButtons: boolean?,
    },

    state: {
        number: State<T>,
        editingText: State<number>,
    },
} & NumberChanged & Hovered

export type InputColor3 = Input<{ number }> & {
    arguments: {
        UseFloats: boolean?,
        UseHSV: boolean?,
    },

    state: {
        color: State<Color3>,
        editingText: State<boolean>,
    },
} & NumberChanged & Hovered

export type InputColor4 = InputColor3 & {
    state: {
        transparency: State<number>,
    },
}

export type InputEnum = Input<number> & {
    state: {
        enumItem: State<EnumItem>,
    },
}

export type InputText = Widget & {
    arguments: {
        Text: string?,
        TextHint: string?,
        ReadOnly: boolean?,
        MultiLine: boolean?,
    },

    state: {
        text: State<string>,
    },
} & TextChanged & Hovered

-- Combo

export type Selectable = Widget & {
    ButtonColors: { [string]: Color3 | number },

    arguments: {
        Text: string?,
        Index: any?,
        NoClick: boolean?,
    },

    state: {
        index: State<any>,
    },
} & Selected & Unselected & Clicked & RightClicked & DoubleClicked & CtrlClicked & Hovered

export type Combo = ParentWidget & {
    arguments: {
        Text: string?,
        NoButton: boolean?,
        NoPreview: boolean?,
    },

    state: {
        index: State<any>,
        isOpened: State<boolean>,
    },

    UIListLayout: UIListLayout,
} & Opened & Closed & Changed & Clicked & Hovered

-- Plot

export type ProgressBar = Widget & {
    arguments: {
        Text: string?,
        Format: string?,
    },

    state: {
        progress: State<number>,
    },
} & Changed & Hovered

export type PlotLines = Widget & {
    Lines: { Frame },
    HoveredLine: Frame | false,
    Tooltip: TextLabel,

    arguments: {
        Text: string,
        Height: number,
        Min: number,
        Max: number,
        TextOverlay: string,
    },

    state: {
        values: State<{ number }>,
        hovered: State<{ number }?>,
    },
} & Hovered

export type PlotHistogram = Widget & {
    Blocks: { Frame },
    HoveredBlock: Frame | false,
    Tooltip: TextLabel,

    arguments: {
        Text: string,
        Height: number,
        Min: number,
        Max: number,
        TextOverlay: string,
        BaseLine: number,
    },

    state: {
        values: State<{ number }>,
        hovered: State<number?>,
    },
} & Hovered

export type Table = ParentWidget & {
    _columnIndex: number,
    _rowIndex: number,
    _rowContainer: Frame,
    _rowInstances: { Frame },
    _cellInstances: { { Frame } },
    _rowBorders: { Frame },
    _columnBorders: { GuiButton },
    _rowCycles: { number },
    _widths: { UDim },
    _minWidths: { number },

    arguments: {
        NumColumns: number,
        Header: boolean,
        RowBackground: boolean,
        OuterBorders: boolean,
        InnerBorders: boolean,
        Resizable: boolean,
        FixedWidth: boolean,
        ProportionalWidth: boolean,
        LimitTableWidth: boolean,
    },

    state: {
        widths: State<{ number }>,
    },
} & Hovered

return {}

end

_modules["Axios.config"] = function()
    local script = create_mock_script("Axios.config")
    local require = axios_require
local TemplateConfig = {
    colorDark = { -- Dear, ImGui default dark
        TextColor = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0,
        TextDisabledColor = Color3.fromRGB(128, 128, 128),
        TextDisabledTransparency = 0,

        -- Dear ImGui uses 110, 110, 125
        -- The Roblox window selection highlight is 67, 191, 254
        BorderColor = Color3.fromRGB(110, 110, 125),
        BorderTransparency = 0.5,
        BorderActiveColor = Color3.fromRGB(160, 160, 175), -- does not exist in Dear ImGui
        BorderActiveTransparency = 0.3,

        WindowBgColor = Color3.fromRGB(15, 15, 15),
        WindowBgTransparency = 0.06,
        PopupBgColor = Color3.fromRGB(20, 20, 20),
        PopupBgTransparency = 0.06,

        ScrollbarGrabColor = Color3.fromRGB(79, 79, 79),
        ScrollbarGrabTransparency = 0,

        TitleBgColor = Color3.fromRGB(10, 10, 10),
        TitleBgTransparency = 0,
        TitleBgActiveColor = Color3.fromRGB(41, 74, 122),
        TitleBgActiveTransparency = 0,
        TitleBgCollapsedColor = Color3.fromRGB(0, 0, 0),
        TitleBgCollapsedTransparency = 0.5,

        MenubarBgColor = Color3.fromRGB(36, 36, 36),
        MenubarBgTransparency = 0,

        FrameBgColor = Color3.fromRGB(41, 74, 122),
        FrameBgTransparency = 0.46,
        FrameBgHoveredColor = Color3.fromRGB(66, 150, 250),
        FrameBgHoveredTransparency = 0.46,
        FrameBgActiveColor = Color3.fromRGB(66, 150, 250),
        FrameBgActiveTransparency = 0.33,

        ButtonColor = Color3.fromRGB(66, 150, 250),
        ButtonTransparency = 0.6,
        ButtonHoveredColor = Color3.fromRGB(66, 150, 250),
        ButtonHoveredTransparency = 0,
        ButtonActiveColor = Color3.fromRGB(15, 135, 250),
        ButtonActiveTransparency = 0,

        ImageColor = Color3.fromRGB(255, 255, 255),
        ImageTransparency = 0,

        SliderGrabColor = Color3.fromRGB(66, 150, 250),
        SliderGrabTransparency = 0,
        SliderGrabActiveColor = Color3.fromRGB(66, 150, 250),
        SliderGrabActiveTransparency = 0,

        HeaderColor = Color3.fromRGB(66, 150, 250),
        HeaderTransparency = 0.69,
        HeaderHoveredColor = Color3.fromRGB(66, 150, 250),
        HeaderHoveredTransparency = 0.2,
        HeaderActiveColor = Color3.fromRGB(66, 150, 250),
        HeaderActiveTransparency = 0,

        TabColor = Color3.fromRGB(46, 89, 148),
        TabTransparency = 0.14,
        TabHoveredColor = Color3.fromRGB(66, 150, 250),
        TabHoveredTransparency = 0.2,
        TabActiveColor = Color3.fromRGB(51, 105, 173),
        TabActiveTransparency = 0,

        SelectionImageObjectColor = Color3.fromRGB(255, 255, 255),
        SelectionImageObjectTransparency = 0.8,
        SelectionImageObjectBorderColor = Color3.fromRGB(255, 255, 255),
        SelectionImageObjectBorderTransparency = 0,

        TableBorderStrongColor = Color3.fromRGB(79, 79, 89),
        TableBorderStrongTransparency = 0,
        TableBorderLightColor = Color3.fromRGB(59, 59, 64),
        TableBorderLightTransparency = 0,
        TableRowBgColor = Color3.fromRGB(0, 0, 0),
        TableRowBgTransparency = 1,
        TableRowBgAltColor = Color3.fromRGB(255, 255, 255),
        TableRowBgAltTransparency = 0.94,
        TableHeaderColor = Color3.fromRGB(48, 48, 51),
        TableHeaderTransparency = 0,

        NavWindowingHighlightColor = Color3.fromRGB(255, 255, 255),
        NavWindowingHighlightTransparency = 0.3,
        NavWindowingDimBgColor = Color3.fromRGB(204, 204, 204),
        NavWindowingDimBgTransparency = 0.65,

        SeparatorColor = Color3.fromRGB(110, 110, 128),
        SeparatorTransparency = 0.5,

        CheckMarkColor = Color3.fromRGB(66, 150, 250),
        CheckMarkTransparency = 0,

        PlotLinesColor = Color3.fromRGB(156, 156, 156),
        PlotLinesTransparency = 0,
        PlotLinesHoveredColor = Color3.fromRGB(255, 110, 89),
        PlotLinesHoveredTransparency = 0,
        PlotHistogramColor = Color3.fromRGB(230, 179, 0),
        PlotHistogramTransparency = 0,
        PlotHistogramHoveredColor = Color3.fromRGB(255, 153, 0),
        PlotHistogramHoveredTransparency = 0,

        ResizeGripColor = Color3.fromRGB(66, 150, 250),
        ResizeGripTransparency = 0.8,
        ResizeGripHoveredColor = Color3.fromRGB(66, 150, 250),
        ResizeGripHoveredTransparency = 0.33,
        ResizeGripActiveColor = Color3.fromRGB(66, 150, 250),
        ResizeGripActiveTransparency = 0.05,
    },
    colorLight = { -- Dear, ImGui default light
        TextColor = Color3.fromRGB(0, 0, 0),
        TextTransparency = 0,
        TextDisabledColor = Color3.fromRGB(153, 153, 153),
        TextDisabledTransparency = 0,

        -- Dear ImGui uses 0, 0, 0, 77
        -- The Roblox window selection highlight is 67, 191, 254
        BorderColor = Color3.fromRGB(64, 64, 64),
        BorderActiveColor = Color3.fromRGB(64, 64, 64), -- does not exist in Dear ImGui

        -- BorderTransparency will be problematic for non UIStroke border implimentations
        -- will not be implimented because of this
        BorderTransparency = 0.5,
        BorderActiveTransparency = 0.2,

        WindowBgColor = Color3.fromRGB(240, 240, 240),
        WindowBgTransparency = 0,
        PopupBgColor = Color3.fromRGB(255, 255, 255),
        PopupBgTransparency = 0.02,

        TitleBgColor = Color3.fromRGB(245, 245, 245),
        TitleBgTransparency = 0,
        TitleBgActiveColor = Color3.fromRGB(209, 209, 209),
        TitleBgActiveTransparency = 0,
        TitleBgCollapsedColor = Color3.fromRGB(255, 255, 255),
        TitleBgCollapsedTransparency = 0.5,

        MenubarBgColor = Color3.fromRGB(219, 219, 219),
        MenubarBgTransparency = 0,

        ScrollbarGrabColor = Color3.fromRGB(176, 176, 176),
        ScrollbarGrabTransparency = 0.2,

        FrameBgColor = Color3.fromRGB(255, 255, 255),
        FrameBgTransparency = 0.6,
        FrameBgHoveredColor = Color3.fromRGB(66, 150, 250),
        FrameBgHoveredTransparency = 0.6,
        FrameBgActiveColor = Color3.fromRGB(66, 150, 250),
        FrameBgActiveTransparency = 0.33,

        ButtonColor = Color3.fromRGB(66, 150, 250),
        ButtonTransparency = 0.6,
        ButtonHoveredColor = Color3.fromRGB(66, 150, 250),
        ButtonHoveredTransparency = 0,
        ButtonActiveColor = Color3.fromRGB(15, 135, 250),
        ButtonActiveTransparency = 0,

        ImageColor = Color3.fromRGB(255, 255, 255),
        ImageTransparency = 0,

        HeaderColor = Color3.fromRGB(66, 150, 250),
        HeaderTransparency = 0.31,
        HeaderHoveredColor = Color3.fromRGB(66, 150, 250),
        HeaderHoveredTransparency = 0.2,
        HeaderActiveColor = Color3.fromRGB(66, 150, 250),
        HeaderActiveTransparency = 0,

        TabColor = Color3.fromRGB(195, 203, 213),
        TabTransparency = 0.07,
        TabHoveredColor = Color3.fromRGB(66, 150, 250),
        TabHoveredTransparency = 0.2,
        TabActiveColor = Color3.fromRGB(152, 186, 255),
        TabActiveTransparency = 0,

        SliderGrabColor = Color3.fromRGB(61, 133, 224),
        SliderGrabTransparency = 0,
        SliderGrabActiveColor = Color3.fromRGB(117, 138, 204),
        SliderGrabActiveTransparency = 0,

        SelectionImageObjectColor = Color3.fromRGB(0, 0, 0),
        SelectionImageObjectTransparency = 0.8,
        SelectionImageObjectBorderColor = Color3.fromRGB(0, 0, 0),
        SelectionImageObjectBorderTransparency = 0,

        TableBorderStrongColor = Color3.fromRGB(145, 145, 163),
        TableBorderStrongTransparency = 0,
        TableBorderLightColor = Color3.fromRGB(173, 173, 189),
        TableBorderLightTransparency = 0,
        TableRowBgColor = Color3.fromRGB(0, 0, 0),
        TableRowBgTransparency = 1,
        TableRowBgAltColor = Color3.fromRGB(77, 77, 77),
        TableRowBgAltTransparency = 0.91,
        TableHeaderColor = Color3.fromRGB(199, 222, 250),
        TableHeaderTransparency = 0,

        NavWindowingHighlightColor = Color3.fromRGB(179, 179, 179),
        NavWindowingHighlightTransparency = 0.3,
        NavWindowingDimBgColor = Color3.fromRGB(51, 51, 51),
        NavWindowingDimBgTransparency = 0.8,

        SeparatorColor = Color3.fromRGB(99, 99, 99),
        SeparatorTransparency = 0.38,

        CheckMarkColor = Color3.fromRGB(66, 150, 250),
        CheckMarkTransparency = 0,

        PlotLinesColor = Color3.fromRGB(99, 99, 99),
        PlotLinesTransparency = 0,
        PlotLinesHoveredColor = Color3.fromRGB(255, 110, 89),
        PlotLinesHoveredTransparency = 0,
        PlotHistogramColor = Color3.fromRGB(230, 179, 0),
        PlotHistogramTransparency = 0,
        PlotHistogramHoveredColor = Color3.fromRGB(255, 153, 0),
        PlotHistogramHoveredTransparency = 0,

        ResizeGripColor = Color3.fromRGB(89, 89, 89),
        ResizeGripTransparency = 0.83,
        ResizeGripHoveredColor = Color3.fromRGB(66, 150, 250),
        ResizeGripHoveredTransparency = 0.33,
        ResizeGripActiveColor = Color3.fromRGB(66, 150, 250),
        ResizeGripActiveTransparency = 0.05,
    },

    sizeDefault = { -- Dear, ImGui default
        ItemWidth = UDim.new(1, 0),
        ContentWidth = UDim.new(0.65, 0),
        ContentHeight = UDim.new(0, 0),

        WindowPadding = Vector2.new(8, 8),
        WindowResizePadding = Vector2.new(6, 6),
        FramePadding = Vector2.new(4, 3),
        ItemSpacing = Vector2.new(8, 4),
        ItemInnerSpacing = Vector2.new(4, 4),
        CellPadding = Vector2.new(4, 2),
        DisplaySafeAreaPadding = Vector2.new(0, 0),
        SeparatorTextPadding = Vector2.new(20, 3),
        IndentSpacing = 21,

        TextFont = Font.fromEnum(Enum.Font.Code),
        TextSize = 13,
        FrameBorderSize = 0,
        FrameRounding = 0,
        GrabRounding = 0,
        WindowRounding = 0, -- these don't actually work but it's nice to have them.
        WindowBorderSize = 1,
        WindowTitleAlign = Enum.LeftRight.Left,
        PopupBorderSize = 1,
        PopupRounding = 0,
        ScrollbarSize = 7,
        GrabMinSize = 10,
        SeparatorTextBorderSize = 3,
        ImageBorderSize = 2,
    },
    sizeClear = { -- easier to read and manuveure
        ItemWidth = UDim.new(1, 0),
        ContentWidth = UDim.new(0.65, 0),
        ContentHeight = UDim.new(0, 0),

        WindowPadding = Vector2.new(12, 8),
        WindowResizePadding = Vector2.new(8, 8),
        FramePadding = Vector2.new(6, 4),
        ItemSpacing = Vector2.new(8, 8),
        ItemInnerSpacing = Vector2.new(8, 8),
        CellPadding = Vector2.new(4, 4),
        DisplaySafeAreaPadding = Vector2.new(8, 8),
        SeparatorTextPadding = Vector2.new(24, 6),
        IndentSpacing = 25,

        TextFont = Font.fromEnum(Enum.Font.Ubuntu),
        TextSize = 15,
        FrameBorderSize = 1,
        FrameRounding = 4,
        GrabRounding = 4,
        WindowRounding = 4,
        WindowBorderSize = 1,
        WindowTitleAlign = Enum.LeftRight.Center,
        PopupBorderSize = 1,
        PopupRounding = 4,
        ScrollbarSize = 9,
        GrabMinSize = 14,
        SeparatorTextBorderSize = 4,
        ImageBorderSize = 4,
    },

    utilityDefault = {
        UseScreenGUIs = true,
        IgnoreGuiInset = false,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
        Parent = nil,
        RichText = false,
        TextWrapped = false,
        DisplayOrderOffset = 127,
        ZIndexOffset = 0,

        MouseDoubleClickTime = 0.30, -- Time for a double-click, in seconds.
        MouseDoubleClickMaxDist = 6.0, -- Distance threshold to stay in to validate a double-click, in pixels.

        HoverColor = Color3.fromRGB(255, 255, 0),
        HoverTransparency = 0.1,
    },
}

return TemplateConfig

end

_modules["Axios.demoWindow"] = function()
    local script = create_mock_script("Axios.demoWindow")
    local require = axios_require
local Types = require(script.Parent.Types)

return function(Axios: Types.Axios)
    local showMainWindow = Axios.State(true)
    local showRecursiveWindow = Axios.State(false)
    local showRuntimeInfo = Axios.State(false)
    local showStyleEditor = Axios.State(false)
    local showWindowlessDemo = Axios.State(false)
    local showMainMenuBarWindow = Axios.State(false)
    local showDebugWindow = Axios.State(false)

    local showBackground = Axios.State(false)
    local backgroundColour = Axios.State(Color3.fromRGB(115, 140, 152))
    local backgroundTransparency = Axios.State(0)
    table.insert(Axios.Internal._initFunctions, function()
        local background = Instance.new("Frame")
        background.Name = "Background"
        background.Size = UDim2.fromScale(1, 1)
        background.BackgroundColor3 = backgroundColour.value
        background.BackgroundTransparency = backgroundTransparency.value

        local widget
        if Axios._config.UseScreenGUIs then
            widget = Instance.new("ScreenGui")
            widget.Name = "Axios_Background"
            widget.IgnoreGuiInset = true
            widget.DisplayOrder = Axios._config.DisplayOrderOffset - 1
            widget.ScreenInsets = Enum.ScreenInsets.None
            widget.Enabled = true

            background.Parent = widget
        else
            background.ZIndex = Axios._config.DisplayOrderOffset - 1
            widget = background
        end

        backgroundColour:onChange(function(value: Color3)
            background.BackgroundColor3 = value
        end)
        backgroundTransparency:onChange(function(value: number)
            background.BackgroundTransparency = value
        end)

        showBackground:onChange(function(show: boolean)
            if show then
                widget.Parent = Axios.Internal.parentInstance
            else
                widget.Parent = nil
            end
        end)
    end)

    local function helpMarker(helpText: string)
        Axios.PushConfig({ TextColor = Axios._config.TextDisabledColor })
        local text = Axios.Text({ "(?)" })
        Axios.PopConfig()

        Axios.PushConfig({ ContentWidth = UDim.new(0, 350) })
        if text.hovered() then
            Axios.Tooltip({ helpText })
        end
        Axios.PopConfig()
    end

    local function textAndHelpMarker(text: string, helpText: string)
        Axios.SameLine()
        do
            Axios.Text({ text })
            helpMarker(helpText)
        end
        Axios.End()
    end

    -- shows each widgets functionality
    local widgetDemos = {
        Basic = function()
            Axios.Tree({ "Basic" })
            do
                Axios.SeparatorText({ "Basic" })

                local radioButtonState = Axios.State(1)
                Axios.Button({ "Button" })
                Axios.SmallButton({ "SmallButton" })
                Axios.Text({ "Text" })
                Axios.TextWrapped({ string.rep("Text Wrapped ", 5) })
                Axios.TextColored({ "Colored Text", Color3.fromRGB(255, 128, 0) })
                Axios.Text({ `Rich Text: <b>bold text</b> <i>italic text</i> <u>underline text</u> <s>strikethrough text</s> <font color= "rgb(240, 40, 10)">red text</font> <font size="32">bigger text</font>`, true, nil, true })

                Axios.SameLine()
                do
                    Axios.RadioButton({ "Index '1'", 1 }, { index = radioButtonState })
                    Axios.RadioButton({ "Index 'two'", "two" }, { index = radioButtonState })
                    if Axios.RadioButton({ "Index 'false'", false }, { index = radioButtonState }).active() == false then
                        if Axios.SmallButton({ "Select last" }).clicked() then
                            radioButtonState:set(false)
                        end
                    end
                end
                Axios.End()

                Axios.Text({ "The Index is: " .. tostring(radioButtonState.value) })

                Axios.SeparatorText({ "Inputs" })

                Axios.InputNum({})
                Axios.DragNum({})
                Axios.SliderNum({})
            end
            Axios.End()
        end,

        Image = function()
            Axios.Tree({ "Image" })
            do
                Axios.SeparatorText({ "Image Controls" })

                local AssetState = Axios.State("rbxasset://textures/ui/common/robux.png")
                local SizeState = Axios.State(UDim2.fromOffset(100, 100))
                local RectState = Axios.State(Rect.new(0, 0, 0, 0))
                local ScaleTypeState = Axios.State(Enum.ScaleType.Stretch)
                local PixelatedCheckState = Axios.State(false)
                local PixelatedState = Axios.ComputedState(PixelatedCheckState, function(check)
                    return check and Enum.ResamplerMode.Pixelated or Enum.ResamplerMode.Default
                end)

                local ImageColorState = Axios.State(Axios._config.ImageColor)
                local ImageTransparencyState = Axios.State(Axios._config.ImageTransparency)
                Axios.InputColor4({ "Image Tint" }, { color = ImageColorState, transparency = ImageTransparencyState })

                Axios.Combo({ "Asset" }, { index = AssetState })
                do
                    Axios.Selectable({ "Robux Small", "rbxasset://textures/ui/common/robux.png" }, { index = AssetState })
                    Axios.Selectable({ "Robux Large", "rbxasset://textures//ui/common/robux@3x.png" }, { index = AssetState })
                    Axios.Selectable({ "Loading Texture", "rbxasset://textures//loading/darkLoadingTexture.png" }, { index = AssetState })
                    Axios.Selectable({ "Hue-Saturation Gradient", "rbxasset://textures//TagEditor/huesatgradient.png" }, { index = AssetState })
                    Axios.Selectable({ "famfamfam.png (WHY?)", "rbxasset://textures//TagEditor/famfamfam.png" }, { index = AssetState })
                end
                Axios.End()

                Axios.SliderUDim2({ "Image Size", nil, nil, UDim2.new(1, 240, 1, 240) }, { number = SizeState })
                Axios.SliderRect({ "Image Rect", nil, nil, Rect.new(256, 256, 256, 256) }, { number = RectState })

                Axios.Combo({ "Scale Type" }, { index = ScaleTypeState })
                do
                    Axios.Selectable({ "Stretch", Enum.ScaleType.Stretch }, { index = ScaleTypeState })
                    Axios.Selectable({ "Fit", Enum.ScaleType.Fit }, { index = ScaleTypeState })
                    Axios.Selectable({ "Crop", Enum.ScaleType.Crop }, { index = ScaleTypeState })
                end

                Axios.End()
                Axios.Checkbox({ "Pixelated" }, { isChecked = PixelatedCheckState })

                Axios.PushConfig({
                    ImageColor = ImageColorState:get(),
                    ImageTransparency = ImageTransparencyState:get(),
                })
                Axios.Image({ AssetState:get(), SizeState:get(), RectState:get(), ScaleTypeState:get(), PixelatedState:get() })
                Axios.PopConfig()

                Axios.SeparatorText({ "Tile" })
                local TileState = Axios.State(UDim2.fromScale(0.5, 0.5))
                Axios.SliderUDim2({ "Tile Size", nil, nil, UDim2.new(1, 240, 1, 240) }, { number = TileState })

                Axios.PushConfig({
                    ImageColor = ImageColorState:get(),
                    ImageTransparency = ImageTransparencyState:get(),
                })
                Axios.Image({ "rbxasset://textures/grid2.png", SizeState:get(), nil, Enum.ScaleType.Tile, PixelatedState:get(), TileState:get() })
                Axios.PopConfig()

                Axios.SeparatorText({ "Slice" })
                local SliceScaleState = Axios.State(1)
                Axios.SliderNum({ "Image Slice Scale", 0.1, 0.1, 5 }, { number = SliceScaleState })

                Axios.PushConfig({
                    ImageColor = ImageColorState:get(),
                    ImageTransparency = ImageTransparencyState:get(),
                })
                Axios.Image({ "rbxasset://textures/ui/chatBubble_blue_notify_bkg.png", SizeState:get(), nil, Enum.ScaleType.Slice, PixelatedState:get(), nil, Rect.new(12, 12, 56, 56), 1 }, SliceScaleState:get())
                Axios.PopConfig()

                Axios.SeparatorText({ "Image Button" })
                local count = Axios.State(0)

                Axios.SameLine()
                do
                    Axios.PushConfig({
                        ImageColor = ImageColorState:get(),
                        ImageTransparency = ImageTransparencyState:get(),
                    })
                    if Axios.ImageButton({ "rbxasset://textures/AvatarCompatibilityPreviewer/add.png", UDim2.fromOffset(20, 20) }).clicked() then
                        count:set(count.value + 1)
                    end
                    Axios.PopConfig()

                    Axios.Text({ `Click count: {count.value}` })
                end
                Axios.End()
            end
            Axios.End()
        end,

        Selectable = function()
            Axios.Tree({ "Selectable" })
            do
                local sharedIndex = Axios.State(2)
                Axios.Selectable({ "Selectable #1", 1 }, { index = sharedIndex })
                Axios.Selectable({ "Selectable #2", 2 }, { index = sharedIndex })
                if Axios.Selectable({ "Double click Selectable", 3, true }, { index = sharedIndex }).doubleClicked() then
                    sharedIndex:set(3)
                end

                Axios.Selectable({ "Impossible to select", 4, true }, { index = sharedIndex })
                if Axios.Button({ "Select last" }).clicked() then
                    sharedIndex:set(4)
                end

                Axios.Selectable({ "Independent Selectable" })
            end
            Axios.End()
        end,

        Combo = function()
            Axios.Tree({ "Combo" })
            do
                Axios.PushConfig({ ContentWidth = UDim.new(1, -200) })
                local sharedComboIndex = Axios.State("No Selection")

                local NoPreview, NoButton
                Axios.SameLine()
                do
                    NoPreview = Axios.Checkbox({ "No Preview" })
                    NoButton = Axios.Checkbox({ "No Button" })
                    if NoPreview.checked() and NoButton.isChecked.value == true then
                        NoButton.isChecked:set(false)
                    end
                    if NoButton.checked() and NoPreview.isChecked.value == true then
                        NoPreview.isChecked:set(false)
                    end
                end
                Axios.End()

                Axios.Combo({ "Basic Usage", NoButton.isChecked:get(), NoPreview.isChecked:get() }, { index = sharedComboIndex })
                do
                    Axios.Selectable({ "Select 1", "One" }, { index = sharedComboIndex })
                    Axios.Selectable({ "Select 2", "Two" }, { index = sharedComboIndex })
                    Axios.Selectable({ "Select 3", "Three" }, { index = sharedComboIndex })
                end
                Axios.End()

                Axios.ComboArray({ "Using ComboArray" }, { index = "No Selection" }, { "Red", "Green", "Blue" })

                local heightTestArray = {}
                for i = 1, 50 do
                    table.insert(heightTestArray, tostring(i))
                end
                Axios.ComboArray({ "Height Test" }, { index = "1" }, heightTestArray)

                local sharedComboIndex2 = Axios.State("7 AM")

                Axios.Combo({ "Combo with Inner widgets" }, { index = sharedComboIndex2 })
                do
                    Axios.Tree({ "Morning Shifts" })
                    do
                        Axios.Selectable({ "Shift at 7 AM", "7 AM" }, { index = sharedComboIndex2 })
                        Axios.Selectable({ "Shift at 11 AM", "11 AM" }, { index = sharedComboIndex2 })
                        Axios.Selectable({ "Shift at 3 PM", "3 PM" }, { index = sharedComboIndex2 })
                    end
                    Axios.End()
                    Axios.Tree({ "Night Shifts" })
                    do
                        Axios.Selectable({ "Shift at 6 PM", "6 PM" }, { index = sharedComboIndex2 })
                        Axios.Selectable({ "Shift at 9 PM", "9 PM" }, { index = sharedComboIndex2 })
                    end
                    Axios.End()
                end
                Axios.End()

                local ComboEnum = Axios.ComboEnum({ "Using ComboEnum" }, { index = Enum.UserInputState.Begin }, Enum.UserInputState)
                Axios.Text({ "Selected: " .. ComboEnum.index:get().Name })
                Axios.PopConfig()
            end
            Axios.End()
        end,

        Tree = function()
            Axios.Tree({ "Trees" })
            do
                Axios.Tree({ "Tree using SpanAvailWidth", true })
                do
                    helpMarker("SpanAvailWidth determines if the Tree is selectable from its entire with, or only the text area")
                end
                Axios.End()

                local tree1 = Axios.Tree({ "Tree with Children" })
                do
                    Axios.Text({ "Im inside the first tree!" })
                    Axios.Button({ "Im a button inside the first tree!" })
                    Axios.Tree({ "Im a tree inside the first tree!" })
                    do
                        Axios.Text({ "I am the innermost text!" })
                    end
                    Axios.End()
                end
                Axios.End()

                Axios.Checkbox({ "Toggle above tree" }, { isChecked = tree1.state.isUncollapsed })
            end
            Axios.End()
        end,

        CollapsingHeader = function()
            Axios.Tree({ "Collapsing Headers" })
            do
                Axios.CollapsingHeader({ "A header" })
                do
                    Axios.Text({ "This is under the first header!" })
                end
                Axios.End()

                local secondHeader = Axios.State(false)
                Axios.CollapsingHeader({ "Another header" }, { isUncollapsed = secondHeader })
                do
                    if Axios.Button({ "Shhh... secret button!" }).clicked() then
                        secondHeader:set(true)
                    end
                end
                Axios.End()
            end
            Axios.End()
        end,

        Group = function()
            Axios.Tree({ "Groups" })
            do
                Axios.SameLine()
                do
                    Axios.Group()
                    do
                        Axios.Text({ "I am in group A" })
                        Axios.Button({ "Im also in A" })
                    end
                    Axios.End()

                    Axios.Separator()

                    Axios.Group()
                    do
                        Axios.Text({ "I am in group B" })
                        Axios.Button({ "Im also in B" })
                        Axios.Button({ "Also group B" })
                    end
                    Axios.End()
                end
                Axios.End()
            end
            Axios.End()
        end,

        Tab = function()
            Axios.Tree({ "Tabs" })
            do
                Axios.Tree({ "Simple" })
                do
                    Axios.TabBar()
                    do
                        Axios.Tab({ "Apples" })
                        do
                            Axios.Text({ "Who loves apples?" })
                        end
                        Axios.End()
                        Axios.Tab({ "Broccoli" })
                        do
                            Axios.Text({ "And what about broccoli?" })
                        end
                        Axios.End()
                        Axios.Tab({ "Carrots" })
                        do
                            Axios.Text({ "But carrots are the best." })
                        end
                        Axios.End()
                    end
                    Axios.End()
                    Axios.Separator()
                    Axios.Text({ "Very important questions." })
                end
                Axios.End()

                Axios.Tree({ "Closable" })
                do
                    local a = Axios.State(true)
                    local b = Axios.State(true)
                    local c = Axios.State(true)

                    Axios.TabBar()
                    do
                        Axios.Tab({ "🍎", true }, { isOpened = a })
                        do
                            Axios.Text({ "Who loves apples?" })
                            if Axios.Button({ "I don't like apples." }).clicked() then
                                a:set(false)
                            end
                        end
                        Axios.End()
                        Axios.Tab({ "🥦", true }, { isOpened = b })
                        do
                            Axios.Text({ "And what about broccoli?" })
                            if Axios.Button({ "Not for me." }).clicked() then
                                b:set(false)
                            end
                        end
                        Axios.End()
                        Axios.Tab({ "🥕", true }, { isOpened = c })
                        do
                            Axios.Text({ "But carrots are the best." })
                            if Axios.Button({ "I disagree with you." }).clicked() then
                                c:set(false)
                            end
                        end
                        Axios.End()
                    end
                    Axios.End()
                    Axios.Separator()
                    if Axios.Button({ "Actually, let me reconsider it." }).clicked() then
                        a:set(true)
                        b:set(true)
                        c:set(true)
                    end
                end
                Axios.End()
            end
            Axios.End()
        end,

        Indent = function()
            Axios.Tree({ "Indents" })
            Axios.Text({ "Not Indented" })
            Axios.Indent()
            do
                Axios.Text({ "Indented" })
                Axios.Indent({ 7 })
                do
                    Axios.Text({ "Indented by 7 more pixels" })
                    Axios.End()

                    Axios.Indent({ -7 })
                    do
                        Axios.Text({ "Indented by 7 less pixels" })
                    end
                    Axios.End()
                end
                Axios.End()
            end
            Axios.End()
        end,

        Input = function()
            Axios.Tree({ "Input" })
            do
                local NoField, NoButtons, Min, Max, Increment, Format = Axios.State(false), Axios.State(false), Axios.State(0), Axios.State(100), Axios.State(1), Axios.State("%d")

                Axios.PushConfig({ ContentWidth = UDim.new(1, -120) })
                local InputNum = Axios.InputNum({
                    [Axios.Args.InputNum.Text] = "Input Number",
                    -- [Axios.Args.InputNum.NoField] = NoField.value,
                    [Axios.Args.InputNum.NoButtons] = NoButtons.value,
                    [Axios.Args.InputNum.Min] = Min.value,
                    [Axios.Args.InputNum.Max] = Max.value,
                    [Axios.Args.InputNum.Increment] = Increment.value,
                    [Axios.Args.InputNum.Format] = { Format.value },
                })
                Axios.PopConfig()
                Axios.Text({ "The Value is: " .. InputNum.number.value })
                if Axios.Button({ "Randomize Number" }).clicked() then
                    InputNum.number:set(math.random(1, 99))
                end
                local NoFieldCheckbox = Axios.Checkbox({ "NoField" }, { isChecked = NoField })
                local NoButtonsCheckbox = Axios.Checkbox({ "NoButtons" }, { isChecked = NoButtons })
                if NoFieldCheckbox.checked() and NoButtonsCheckbox.isChecked.value == true then
                    NoButtonsCheckbox.isChecked:set(false)
                end
                if NoButtonsCheckbox.checked() and NoFieldCheckbox.isChecked.value == true then
                    NoFieldCheckbox.isChecked:set(false)
                end

                Axios.PushConfig({ ContentWidth = UDim.new(1, -120) })
                Axios.InputVector2({ "InputVector2" })
                Axios.InputVector3({ "InputVector3" })
                Axios.InputUDim({ "InputUDim" })
                Axios.InputUDim2({ "InputUDim2" })
                local UseFloats = Axios.State(false)
                local UseHSV = Axios.State(false)
                local sharedColor = Axios.State(Color3.new())
                local transparency = Axios.State(0)
                Axios.SliderNum({ "Transparency", 0.01, 0, 1 }, { number = transparency })
                Axios.InputColor3({ "InputColor3", UseFloats:get(), UseHSV:get() }, { color = sharedColor })
                Axios.InputColor4({ "InputColor4", UseFloats:get(), UseHSV:get() }, { color = sharedColor, transparency = transparency })
                Axios.SameLine()
                Axios.Text({ `#{sharedColor:get():ToHex()}` })
                Axios.Checkbox({ "Use Floats" }, { isChecked = UseFloats })
                Axios.Checkbox({ "Use HSV" }, { isChecked = UseHSV })
                Axios.End()

                Axios.PopConfig()

                Axios.Separator()

                Axios.SameLine()
                do
                    Axios.Text({ "Slider Numbers" })
                    helpMarker("ctrl + click slider number widgets to input a number")
                end
                Axios.End()
                Axios.PushConfig({ ContentWidth = UDim.new(1, -120) })
                Axios.SliderNum({ "Slide Int", 1, 1, 8 })
                Axios.SliderNum({ "Slide Float", 0.01, 0, 100 })
                Axios.SliderNum({ "Small Numbers", 0.001, -2, 1, "%f radians" })
                Axios.SliderNum({ "Odd Ranges", 0.001, -math.pi, math.pi, "%f radians" })
                Axios.SliderNum({ "Big Numbers", 1e4, 1e5, 1e7 })
                Axios.SliderNum({ "Few Numbers", 1, 0, 3 })
                Axios.PopConfig()

                Axios.Separator()

                Axios.SameLine()
                do
                    Axios.Text({ "Drag Numbers" })
                    helpMarker("ctrl + click or double click drag number widgets to input a number, hold shift/alt while dragging to increase/decrease speed")
                end
                Axios.End()
                Axios.PushConfig({ ContentWidth = UDim.new(1, -120) })
                Axios.DragNum({ "Drag Int" })
                Axios.DragNum({ "Slide Float", 0.001, -10, 10 })
                Axios.DragNum({ "Percentage", 1, 0, 100, "%d %%" })
                Axios.PopConfig()
            end
            Axios.End()
        end,

        InputText = function()
            Axios.Tree({ "Input Text" })
            do
                local InputText = Axios.InputText({ "Input Text Test", "Input Text here" })
                Axios.Text({ "The text is: " .. InputText.text.value })
            end
            Axios.End()
        end,

        MultiInput = function()
            Axios.Tree({ "Multi-Component Input" })
            do
                local sharedVector2 = Axios.State(Vector2.new())
                local sharedVector3 = Axios.State(Vector3.new())
                local sharedUDim = Axios.State(UDim.new())
                local sharedUDim2 = Axios.State(UDim2.new())
                local sharedColor3 = Axios.State(Color3.new())
                local SharedRect = Axios.State(Rect.new(0, 0, 0, 0))

                Axios.SeparatorText({ "Input" })

                Axios.InputVector2({}, { number = sharedVector2 })
                Axios.InputVector3({}, { number = sharedVector3 })
                Axios.InputUDim({}, { number = sharedUDim })
                Axios.InputUDim2({}, { number = sharedUDim2 })
                Axios.InputRect({}, { number = SharedRect })

                Axios.SeparatorText({ "Drag" })

                Axios.DragVector2({}, { number = sharedVector2 })
                Axios.DragVector3({}, { number = sharedVector3 })
                Axios.DragUDim({}, { number = sharedUDim })
                Axios.DragUDim2({}, { number = sharedUDim2 })
                Axios.DragRect({}, { number = SharedRect })

                Axios.SeparatorText({ "Slider" })

                Axios.SliderVector2({}, { number = sharedVector2 })
                Axios.SliderVector3({}, { number = sharedVector3 })
                Axios.SliderUDim({}, { number = sharedUDim })
                Axios.SliderUDim2({}, { number = sharedUDim2 })
                Axios.SliderRect({}, { number = SharedRect })

                Axios.SeparatorText({ "Color" })

                Axios.InputColor3({}, { color = sharedColor3 })
                Axios.InputColor4({}, { color = sharedColor3 })
            end
            Axios.End()
        end,

        Tooltip = function()
            Axios.PushConfig({ ContentWidth = UDim.new(0, 250) })
            Axios.Tree({ "Tooltip" })
            do
                if Axios.Text({ "Hover over me to reveal a tooltip" }).hovered() then
                    Axios.Tooltip({ "I am some helpful tooltip text" })
                end
                local dynamicText = Axios.State("Hello ")
                local numRepeat = Axios.State(1)
                if Axios.InputNum({ "# of repeat", 1, 1, 50 }, { number = numRepeat }).numberChanged() then
                    dynamicText:set(string.rep("Hello ", numRepeat:get()))
                end
                if Axios.Checkbox({ "Show dynamic text tooltip" }).state.isChecked.value then
                    Axios.Tooltip({ dynamicText:get() })
                end
            end
            Axios.End()
            Axios.PopConfig()
        end,

        Plotting = function()
            Axios.Tree({ "Plotting" })
            do
                Axios.SeparatorText({ "Progress" })
                local curTime = os.clock() * 15

                local Progress = Axios.State(0)
                -- formula to cycle between 0 and 100 linearly
                local newValue = math.clamp((math.abs(curTime % 100 - 50)) - 7.5, 0, 35) / 35
                Progress:set(newValue)

                Axios.ProgressBar({ "Progress Bar" }, { progress = Progress })
                Axios.ProgressBar({ "Progress Bar", `{math.floor(Progress:get() * 1753)}/1753` }, { progress = Progress })

                Axios.SeparatorText({ "Graphs" })

                do
                    local ValueState = Axios.State({ 0.5, 0.8, 0.2, 0.9, 0.1, 0.6, 0.4, 0.7, 0.3, 0.0 })

                    Axios.PlotHistogram({ "Histogram", 100, 0, 1, "random" }, { values = ValueState })
                    Axios.PlotLines({ "Lines", 100, 0, 1, "random" }, { values = ValueState })
                end

                do
                    local FunctionState = Axios.State("Cos")
                    local SampleState = Axios.State(37)
                    local BaseLineState = Axios.State(0)
                    local ValueState = Axios.State({})
                    local TimeState = Axios.State(0)

                    local Animated = Axios.Checkbox({ "Animate" })
                    local plotFunc = Axios.ComboArray({ "Plotting Function" }, { index = FunctionState }, { "Sin", "Cos", "Tan", "Saw" })
                    local samples = Axios.SliderNum({ "Samples", 1, 1, 145, "%d samples" }, { number = SampleState })
                    if Axios.SliderNum({ "Baseline", 0.1, -1, 1 }, { number = BaseLineState }).numberChanged() then
                        ValueState:set(ValueState.value, true)
                    end

                    if Animated.state.isChecked.value or plotFunc.closed() or samples.numberChanged() or #ValueState.value == 0 then
                        if Animated.state.isChecked.value then
                            TimeState:set(TimeState.value + Axios.Internal._deltaTime)
                        end
                        local offset = math.floor(TimeState.value * 30) - 1
                        local func = FunctionState.value
                        table.clear(ValueState.value)
                        for i = 1, SampleState.value do
                            if func == "Sin" then
                                ValueState.value[i] = math.sin(math.rad(5 * (i + offset)))
                            elseif func == "Cos" then
                                ValueState.value[i] = math.cos(math.rad(5 * (i + offset)))
                            elseif func == "Tan" then
                                ValueState.value[i] = math.tan(math.rad(5 * (i + offset)))
                            elseif func == "Saw" then
                                ValueState.value[i] = if (i % 2) == (offset % 2) then 1 else -1
                            end
                        end

                        ValueState:set(ValueState.value, true)
                    end

                    Axios.PlotHistogram({ "Histogram", 100, -1, 1, "", BaseLineState:get() }, { values = ValueState })
                    Axios.PlotLines({ "Lines", 100, -1, 1 }, { values = ValueState })
                end
            end
            Axios.End()
        end,
    }
    local widgetDemosOrder = { "Basic", "Image", "Selectable", "Combo", "Tree", "CollapsingHeader", "Group", "Tab", "Indent", "Input", "MultiInput", "InputText", "Tooltip", "Plotting" }

    local function recursiveTree()
        local theTree = Axios.Tree({ "Recursive Tree" })
        do
            if theTree.state.isUncollapsed.value then
                recursiveTree()
            end
        end
        Axios.End()
    end

    local function recursiveWindow(parentCheckboxState)
        local theCheckbox
        Axios.Window({ "Recursive Window" }, { size = Axios.State(Vector2.new(175, 100)), isOpened = parentCheckboxState })
        do
            theCheckbox = Axios.Checkbox({ "Recurse Again" })
        end
        Axios.End()

        if theCheckbox.isChecked.value then
            recursiveWindow(theCheckbox.isChecked)
        end
    end

    -- shows list of runtime widgets and states, including IDs. shows other info about runtime and can show widgets/state info in depth.
    local function runtimeInfo()
        local runtimeInfoWindow = Axios.Window({ "Runtime Info" }, { isOpened = showRuntimeInfo })
        do
            local lastVDOM = Axios.Internal._lastVDOM
            local states = Axios.Internal._states

            local numSecondsDisabled = Axios.State(3)
            local rollingDT = Axios.State(0)
            local lastT = Axios.State(os.clock())

            Axios.SameLine()
            do
                Axios.InputNum({ [Axios.Args.InputNum.Text] = "", [Axios.Args.InputNum.Format] = "%d Seconds", [Axios.Args.InputNum.Max] = 10 }, { number = numSecondsDisabled })
                if Axios.Button({ "Disable" }).clicked() then
                    Axios.Disabled = true
                    task.delay(numSecondsDisabled:get(), function()
                        Axios.Disabled = false
                    end)
                end
            end
            Axios.End()

            local t = os.clock()
            local dt = t - lastT.value
            rollingDT.value += (dt - rollingDT.value) * 0.2
            lastT.value = t
            Axios.Text({ string.format("Average %.3f ms/frame (%.1f FPS)", rollingDT.value * 1000, 1 / rollingDT.value) })

            Axios.Text({
                string.format("Window Position: (%d, %d), Window Size: (%d, %d)", runtimeInfoWindow.position.value.X, runtimeInfoWindow.position.value.Y, runtimeInfoWindow.size.value.X, runtimeInfoWindow.size.value.Y),
            })

            Axios.SameLine()
            do
                Axios.Text({ "Enter an ID to learn more about it." })
                helpMarker("every widget and state has an ID which Axios tracks to remember which widget is which. below lists all widgets and states, with their respective IDs")
            end
            Axios.End()

            Axios.PushConfig({ ItemWidth = UDim.new(1, -150) })
            local enteredText = Axios.InputText({ "ID field" }, { text = Axios.State(runtimeInfoWindow.ID) }).state.text.value
            Axios.PopConfig()

            Axios.Indent()
            do
                local enteredWidget = lastVDOM[enteredText]
                local enteredState = states[enteredText]
                if enteredWidget then
                    Axios.Table({ 1 })
                    Axios.Text({ string.format('The ID, "%s", is a widget', enteredText) })
                    Axios.NextRow()

                    Axios.Text({ string.format("Widget is type: %s", enteredWidget.type) })
                    Axios.NextRow()

                    Axios.Tree({ "Widget has Args:" }, { isUncollapsed = Axios.State(true) })
                    for i, v in enteredWidget.arguments do
                        Axios.Text({ i .. " - " .. tostring(v) })
                    end
                    Axios.End()
                    Axios.NextRow()

                    if enteredWidget.state then
                        Axios.Tree({ "Widget has State:" }, { isUncollapsed = Axios.State(true) })
                        for i, v in enteredWidget.state do
                            Axios.Text({ i .. " - " .. tostring(v.value) })
                        end
                        Axios.End()
                    end
                    Axios.End()
                elseif enteredState then
                    Axios.Table({ 1 })
                    Axios.Text({ string.format('The ID, "%s", is a state', enteredText) })
                    Axios.NextRow()

                    Axios.Text({ string.format("Value is type: %s, Value = %s", typeof(enteredState.value), tostring(enteredState.value)) })
                    Axios.NextRow()

                    Axios.Tree({ "state has connected widgets:" }, { isUncollapsed = Axios.State(true) })
                    for i, v in enteredState.ConnectedWidgets do
                        Axios.Text({ i .. " - " .. v.type })
                    end
                    Axios.End()
                    Axios.NextRow()

                    Axios.Text({ string.format("state has: %d connected functions", #enteredState.ConnectedFunctions) })
                    Axios.End()
                else
                    Axios.Text({ string.format('The ID, "%s", is not a state or widget', enteredText) })
                end
            end
            Axios.End()

            if Axios.Tree({ "Widgets" }).state.isUncollapsed.value then
                local widgetCount = 0
                local widgetStr = ""
                for _, v in lastVDOM do
                    widgetCount += 1
                    widgetStr ..= "\n" .. v.ID .. " - " .. v.type
                end

                Axios.Text({ "Number of Widgets: " .. widgetCount })

                Axios.Text({ widgetStr })
            end
            Axios.End()

            if Axios.Tree({ "States" }).state.isUncollapsed.value then
                local stateCount = 0
                local stateStr = ""
                for i, v in states do
                    stateCount += 1
                    stateStr ..= "\n" .. i .. " - " .. tostring(v.value)
                end

                Axios.Text({ "Number of States: " .. stateCount })

                Axios.Text({ stateStr })
            end
            Axios.End()
        end
        Axios.End()
    end

    local function debugPanel()
        Axios.Window({ "Debug Panel" }, { isOpened = showDebugWindow })
        do
            Axios.CollapsingHeader({ "Widgets" })
            do
                Axios.SeparatorText({ "GuiService" })
                Axios.Text({ `GuiOffset: {Axios.Internal._utility.GuiOffset}` })
                Axios.Text({ `MouseOffset: {Axios.Internal._utility.MouseOffset}` })

                Axios.SeparatorText({ "UserInputService" })
                Axios.Text({ `MousePosition: {Axios.Internal._utility.UserInputService:GetMouseLocation()}` })
                Axios.Text({ `MouseLocation: {Axios.Internal._utility.getMouseLocation()}` })

                Axios.Text({ `Left Control: {Axios.Internal._utility.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)}` })
                Axios.Text({ `Right Control: {Axios.Internal._utility.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)}` })
            end
            Axios.End()
        end
        Axios.End()
    end

    local function recursiveMenu()
        if Axios.Menu({ "Recursive" }).state.isOpened.value then
            Axios.MenuItem({ "New", Enum.KeyCode.N, Enum.ModifierKey.Ctrl })
            Axios.MenuItem({ "Open", Enum.KeyCode.O, Enum.ModifierKey.Ctrl })
            Axios.MenuItem({ "Save", Enum.KeyCode.S, Enum.ModifierKey.Ctrl })
            Axios.Separator()
            Axios.MenuToggle({ "Autosave" })
            Axios.MenuToggle({ "Checked" })
            Axios.Separator()
            Axios.Menu({ "Options" })
            Axios.MenuItem({ "Red" })
            Axios.MenuItem({ "Yellow" })
            Axios.MenuItem({ "Green" })
            Axios.MenuItem({ "Blue" })
            Axios.Separator()
            recursiveMenu()
            Axios.End()
        end
        Axios.End()
    end

    local function mainMenuBar()
        Axios.MenuBar()
        do
            Axios.Menu({ "File" })
            do
                Axios.MenuItem({ "New", Enum.KeyCode.N, Enum.ModifierKey.Ctrl })
                Axios.MenuItem({ "Open", Enum.KeyCode.O, Enum.ModifierKey.Ctrl })
                Axios.MenuItem({ "Save", Enum.KeyCode.S, Enum.ModifierKey.Ctrl })
                recursiveMenu()
                if Axios.MenuItem({ "Quit", Enum.KeyCode.Q, Enum.ModifierKey.Alt }).clicked() then
                    showMainWindow:set(false)
                end
            end
            Axios.End()

            Axios.Menu({ "Examples" })
            do
                Axios.MenuToggle({ "Recursive Window" }, { isChecked = showRecursiveWindow })
                Axios.MenuToggle({ "Windowless" }, { isChecked = showWindowlessDemo })
                Axios.MenuToggle({ "Main Menu Bar" }, { isChecked = showMainMenuBarWindow })
            end
            Axios.End()

            Axios.Menu({ "Tools" })
            do
                Axios.MenuToggle({ "Runtime Info" }, { isChecked = showRuntimeInfo })
                Axios.MenuToggle({ "Style Editor" }, { isChecked = showStyleEditor })
                Axios.MenuToggle({ "Debug Panel" }, { isChecked = showDebugWindow })
            end
            Axios.End()
        end
        Axios.End()
    end

    local function mainMenuBarExample()
        -- local screenSize = Axios.Internal._rootWidget.Instance.PseudoWindowScreenGui.AbsoluteSize
        -- Axios.Window(
        --     {[Axios.Args.Window.NoBackground] = true, [Axios.Args.Window.NoTitleBar] = true, [Axios.Args.Window.NoMove] = true, [Axios.Args.Window.NoResize] = true},
        --     {size = Axios.State(screenSize), position = Axios.State(Vector2.new(0, 0))}
        -- )

        mainMenuBar()

        --Axios.End()
    end

    -- allows users to edit state
    local styleEditor
    do
        styleEditor = function()
            local styleList = {
                {
                    "Sizing",
                    function()
                        local UpdatedConfig = Axios.State({})

                        Axios.SameLine()
                        do
                            if Axios.Button({ "Update" }).clicked() then
                                Axios.UpdateGlobalConfig(UpdatedConfig.value)
                                UpdatedConfig:set({})
                            end

                            helpMarker("Update the global config with these changes.")
                        end
                        Axios.End()

                        local function SliderInput(input: string, arguments: { any })
                            local Input = Axios[input](arguments, { number = Axios.WeakState(Axios._config[arguments[1]]) })
                            if Input.numberChanged() then
                                UpdatedConfig.value[arguments[1]] = Input.number:get()
                            end
                        end

                        local function BooleanInput(arguments: { any })
                            local Input = Axios.Checkbox(arguments, { isChecked = Axios.WeakState(Axios._config[arguments[1]]) })
                            if Input.checked() or Input.unchecked() then
                                UpdatedConfig.value[arguments[1]] = Input.isChecked:get()
                            end
                        end

                        Axios.SeparatorText({ "Main" })
                        SliderInput("SliderVector2", { "WindowPadding", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderVector2", { "WindowResizePadding", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderVector2", { "FramePadding", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderVector2", { "ItemSpacing", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderVector2", { "ItemInnerSpacing", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderVector2", { "CellPadding", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderNum", { "IndentSpacing", 1, 0, 36 })
                        SliderInput("SliderNum", { "ScrollbarSize", 1, 0, 20 })
                        SliderInput("SliderNum", { "GrabMinSize", 1, 0, 20 })

                        Axios.SeparatorText({ "Borders & Rounding" })
                        SliderInput("SliderNum", { "FrameBorderSize", 0.1, 0, 1 })
                        SliderInput("SliderNum", { "WindowBorderSize", 0.1, 0, 1 })
                        SliderInput("SliderNum", { "PopupBorderSize", 0.1, 0, 1 })
                        SliderInput("SliderNum", { "SeparatorTextBorderSize", 1, 0, 20 })
                        SliderInput("SliderNum", { "FrameRounding", 1, 0, 12 })
                        SliderInput("SliderNum", { "GrabRounding", 1, 0, 12 })
                        SliderInput("SliderNum", { "PopupRounding", 1, 0, 12 })

                        Axios.SeparatorText({ "Widgets" })
                        SliderInput("SliderVector2", { "DisplaySafeAreaPadding", nil, Vector2.zero, Vector2.new(20, 20) })
                        SliderInput("SliderVector2", { "SeparatorTextPadding", nil, Vector2.zero, Vector2.new(36, 36) })
                        SliderInput("SliderUDim", { "ItemWidth", nil, UDim.new(), UDim.new(1, 200) })
                        SliderInput("SliderUDim", { "ContentWidth", nil, UDim.new(), UDim.new(1, 200) })
                        SliderInput("SliderNum", { "ImageBorderSize", 1, 0, 12 })
                        local TitleInput = Axios.ComboEnum({ "WindowTitleAlign" }, { index = Axios.WeakState(Axios._config.WindowTitleAlign) }, Enum.LeftRight)
                        if TitleInput.closed() then
                            UpdatedConfig.value["WindowTitleAlign"] = TitleInput.index:get()
                        end
                        BooleanInput({ "RichText" })
                        BooleanInput({ "TextWrapped" })

                        Axios.SeparatorText({ "Config" })
                        BooleanInput({ "UseScreenGUIs" })
                        SliderInput("DragNum", { "DisplayOrderOffset", 1, 0 })
                        SliderInput("DragNum", { "ZIndexOffset", 1, 0 })
                        SliderInput("SliderNum", { "MouseDoubleClickTime", 0.1, 0, 5 })
                        SliderInput("SliderNum", { "MouseDoubleClickMaxDist", 0.1, 0, 20 })
                    end,
                },
                {
                    "Colors",
                    function()
                        local UpdatedConfig = Axios.State({})

                        Axios.SameLine()
                        do
                            if Axios.Button({ "Update" }).clicked() then
                                Axios.UpdateGlobalConfig(UpdatedConfig.value)
                                UpdatedConfig:set({})
                            end
                            helpMarker("Update the global config with these changes.")
                        end
                        Axios.End()

                        local color4s = {
                            "Text",
                            "TextDisabled",
                            "WindowBg",
                            "PopupBg",
                            "Border",
                            "BorderActive",
                            "ScrollbarGrab",
                            "TitleBg",
                            "TitleBgActive",
                            "TitleBgCollapsed",
                            "MenubarBg",
                            "FrameBg",
                            "FrameBgHovered",
                            "FrameBgActive",
                            "Button",
                            "ButtonHovered",
                            "ButtonActive",
                            "Image",
                            "SliderGrab",
                            "SliderGrabActive",
                            "Header",
                            "HeaderHovered",
                            "HeaderActive",
                            "SelectionImageObject",
                            "SelectionImageObjectBorder",
                            "TableBorderStrong",
                            "TableBorderLight",
                            "TableRowBg",
                            "TableRowBgAlt",
                            "NavWindowingHighlight",
                            "NavWindowingDimBg",
                            "Separator",
                            "CheckMark",
                        }

                        for _, vColor in color4s do
                            local Input = Axios.InputColor4({ vColor }, {
                                color = Axios.WeakState(Axios._config[vColor .. "Color"]),
                                transparency = Axios.WeakState(Axios._config[vColor .. "Transparency"]),
                            })
                            if Input.numberChanged() then
                                UpdatedConfig.value[vColor .. "Color"] = Input.color:get()
                                UpdatedConfig.value[vColor .. "Transparency"] = Input.transparency:get()
                            end
                        end
                    end,
                },
                {
                    "Fonts",
                    function()
                        local UpdatedConfig = Axios.State({})

                        Axios.SameLine()
                        do
                            if Axios.Button({ "Update" }).clicked() then
                                Axios.UpdateGlobalConfig(UpdatedConfig.value)
                                UpdatedConfig:set({})
                            end

                            helpMarker("Update the global config with these changes.")
                        end
                        Axios.End()

                        local fonts: { [string]: Font } = {
                            ["Code (default)"] = Font.fromEnum(Enum.Font.Code),
                            ["Ubuntu (template)"] = Font.fromEnum(Enum.Font.Ubuntu),
                            ["Arial"] = Font.fromEnum(Enum.Font.Arial),
                            ["Highway"] = Font.fromEnum(Enum.Font.Highway),
                            ["Roboto"] = Font.fromEnum(Enum.Font.Roboto),
                            ["Roboto Mono"] = Font.fromEnum(Enum.Font.RobotoMono),
                            ["Noto Sans"] = Font.new("rbxassetid://12187370747"),
                            ["Builder Sans"] = Font.fromEnum(Enum.Font.BuilderSans),
                            ["Builder Mono"] = Font.new("rbxassetid://16658246179"),
                            ["Sono"] = Font.new("rbxassetid://12187374537"),
                        }

                        Axios.Text({ `Current Font: {Axios._config.TextFont.Family} Weight: {Axios._config.TextFont.Weight} Style: {Axios._config.TextFont.Style}` })
                        Axios.SeparatorText({ "Size" })

                        local TextSize = Axios.SliderNum({ "Font Size", 1, 4, 20 }, { number = Axios.WeakState(Axios._config.TextSize) })
                        if TextSize.numberChanged() then
                            UpdatedConfig.value["TextSize"] = TextSize.state.number:get()
                        end

                        Axios.SeparatorText({ "Properties" })

                        local TextFont = Axios.WeakState(Axios._config.TextFont.Family)
                        local FontWeight = Axios.ComboEnum({ "Font Weight" }, { index = Axios.WeakState(Axios._config.TextFont.Weight) }, Enum.FontWeight)
                        local FontStyle = Axios.ComboEnum({ "Font Style" }, { index = Axios.WeakState(Axios._config.TextFont.Style) }, Enum.FontStyle)

                        Axios.SeparatorText({ "Fonts" })
                        for name, font in fonts do
                            font = Font.new(font.Family, FontWeight.state.index.value, FontStyle.state.index.value)
                            Axios.SameLine()
                            do
                                Axios.PushConfig({
                                    TextFont = font,
                                })

                                if Axios.Selectable({ `{name} | "The quick brown fox jumps over the lazy dog."`, font.Family }, { index = TextFont }).selected() then
                                    UpdatedConfig.value["TextFont"] = font
                                end
                                Axios.PopConfig()
                            end
                            Axios.End()
                        end
                    end,
                },
            }

            Axios.Window({ "Style Editor" }, { isOpened = showStyleEditor })
            do
                Axios.Text({ "Customize the look of Axios in realtime." })

                local ThemeState = Axios.State("Dark Theme")
                if Axios.ComboArray({ "Theme" }, { index = ThemeState }, { "Dark Theme", "Light Theme" }).closed() then
                    if ThemeState.value == "Dark Theme" then
                        Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorDark)
                    elseif ThemeState.value == "Light Theme" then
                        Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorLight)
                    end
                end

                local SizeState = Axios.State("Classic Size")
                if Axios.ComboArray({ "Size" }, { index = SizeState }, { "Classic Size", "Larger Size" }).closed() then
                    if SizeState.value == "Classic Size" then
                        Axios.UpdateGlobalConfig(Axios.TemplateConfig.sizeDefault)
                    elseif SizeState.value == "Larger Size" then
                        Axios.UpdateGlobalConfig(Axios.TemplateConfig.sizeClear)
                    end
                end

                Axios.SameLine()
                do
                    if Axios.Button({ "Revert" }).clicked() then
                        Axios.UpdateGlobalConfig(Axios.TemplateConfig.colorDark)
                        Axios.UpdateGlobalConfig(Axios.TemplateConfig.sizeDefault)
                        ThemeState:set("Dark Theme")
                        SizeState:set("Classic Size")
                    end

                    helpMarker("Reset Axios to the default theme and size.")
                end
                Axios.End()

                Axios.TabBar()
                do
                    for i, v in ipairs(styleList) do
                        Axios.Tab({ v[1] })
                        do
                            styleList[i][2]()
                        end
                        Axios.End()
                    end
                end
                Axios.End()

                Axios.Separator()
            end
            Axios.End()
        end
    end

    local function widgetEventInteractivity()
        Axios.CollapsingHeader({ "Widget Event Interactivity" })
        do
            local clickCount = Axios.State(0)
            if Axios.Button({ "Click to increase Number" }).clicked() then
                clickCount:set(clickCount:get() + 1)
            end
            Axios.Text({ "The Number is: " .. clickCount:get() })

            Axios.Separator()

            local showEventText = Axios.State(false)
            local selectedEvent = Axios.State("clicked")

            Axios.SameLine()
            do
                Axios.RadioButton({ "clicked", "clicked" }, { index = selectedEvent })
                Axios.RadioButton({ "rightClicked", "rightClicked" }, { index = selectedEvent })
                Axios.RadioButton({ "doubleClicked", "doubleClicked" }, { index = selectedEvent })
                Axios.RadioButton({ "ctrlClicked", "ctrlClicked" }, { index = selectedEvent })
            end
            Axios.End()

            Axios.SameLine()
            do
                local button = Axios.Button({ selectedEvent:get() .. " to reveal text" })
                if button[selectedEvent:get()]() then
                    showEventText:set(not showEventText:get())
                end
                if showEventText:get() then
                    Axios.Text({ "Here i am!" })
                end
            end
            Axios.End()

            Axios.Separator()

            local showTextTimer = Axios.State(0)
            Axios.SameLine()
            do
                if Axios.Button({ "Click to show text for 20 frames" }).clicked() then
                    showTextTimer:set(20)
                end
                if showTextTimer:get() > 0 then
                    Axios.Text({ "Here i am!" })
                end
            end
            Axios.End()

            showTextTimer:set(math.max(0, showTextTimer:get() - 1))
            Axios.Text({ "Text Timer: " .. showTextTimer:get() })

            local checkbox0 = Axios.Checkbox({ "Event-tracked checkbox" })
            Axios.Indent()
            do
                Axios.Text({ "unchecked: " .. tostring(checkbox0.unchecked()) })
                Axios.Text({ "checked: " .. tostring(checkbox0.checked()) })
            end
            Axios.End()

            Axios.SameLine()
            do
                if Axios.Button({ "Hover over me" }).hovered() then
                    Axios.Text({ "The button is hovered" })
                end
            end
            Axios.End()
        end
        Axios.End()
    end

    local function widgetStateInteractivity()
        Axios.CollapsingHeader({ "Widget State Interactivity" })
        do
            local checkbox0 = Axios.Checkbox({ "Widget-Generated State" })
            Axios.Text({ `isChecked: {checkbox0.state.isChecked.value}\n` })

            local checkboxState0 = Axios.State(false)
            local checkbox1 = Axios.Checkbox({ "User-Generated State" }, { isChecked = checkboxState0 })
            Axios.Text({ `isChecked: {checkbox1.state.isChecked.value}\n` })

            local checkbox2 = Axios.Checkbox({ "Widget Coupled State" })
            local checkbox3 = Axios.Checkbox({ "Coupled to above Checkbox" }, { isChecked = checkbox2.state.isChecked })
            Axios.Text({ `isChecked: {checkbox3.state.isChecked.value}\n` })

            local checkboxState1 = Axios.State(false)
            local _checkbox4 = Axios.Checkbox({ "Widget and Code Coupled State" }, { isChecked = checkboxState1 })
            local Button0 = Axios.Button({ "Click to toggle above checkbox" })
            if Button0.clicked() then
                checkboxState1:set(not checkboxState1:get())
            end
            Axios.Text({ `isChecked: {checkboxState1.value}\n` })

            local checkboxState2 = Axios.State(true)
            local checkboxState3 = Axios.ComputedState(checkboxState2, function(newValue)
                return not newValue
            end)
            local _checkbox5 = Axios.Checkbox({ "ComputedState (dynamic coupling)" }, { isChecked = checkboxState2 })
            local _checkbox5 = Axios.Checkbox({ "Inverted of above checkbox" }, { isChecked = checkboxState3 })
            Axios.Text({ `isChecked: {checkboxState3.value}\n` })
        end
        Axios.End()
    end

    local function dynamicStyle()
        Axios.CollapsingHeader({ "Dynamic Styles" })
        do
            local colorH = Axios.State(0)
            Axios.SameLine()
            do
                if Axios.Button({ "Change Color" }).clicked() then
                    colorH:set(math.random())
                end
                Axios.Text({ "Hue: " .. math.floor(colorH:get() * 255) })
                helpMarker("Using PushConfig with a changing value, this can be done with any config field")
            end
            Axios.End()

            Axios.PushConfig({ TextColor = Color3.fromHSV(colorH:get(), 1, 1) })
            Axios.Text({ "Text with a unique and changable color" })
            Axios.PopConfig()
        end
        Axios.End()
    end

    local function tablesDemo()
        local showTablesTree = Axios.State(false)

        Axios.CollapsingHeader({ "Tables & Columns" }, { isUncollapsed = showTablesTree })
        if showTablesTree.value == false then
            -- optimization to skip code which draws GUI which wont be seen.
            -- its a trade off because when the tree becomes opened widgets will all have to be generated again.
            -- Dear ImGui utilizes the same trick, but its less useful here because the Retained mode Backend
            Axios.End()
        else
            Axios.Tree({ "Basic" })
            do
                Axios.SameLine()
                do
                    Axios.Text({ "Table using NextColumn syntax:" })
                    helpMarker("calling Axios.NextColumn() in the inner loop,\nwhich automatically goes to the next row at the end.")
                end
                Axios.End()

                Axios.Table({ 3 })
                do
                    for i = 1, 4 do
                        for i2 = 1, 3 do
                            Axios.Text({ `Row: {i}, Column: {i2}` })
                            Axios.NextColumn()
                        end
                    end
                end
                Axios.End()

                Axios.Text({ "" })

                Axios.SameLine()
                do
                    Axios.Text({ "Table using NextColumn and NextRow syntax:" })
                    helpMarker("Calling Axios.NextColumn() in the inner loop and Axios.NextRow() in the outer loop,\nto acehieve a visually identical result. Technically they are not the same.")
                end
                Axios.End()

                Axios.Table({ 3 })
                do
                    for j = 1, 4 do
                        for i = 1, 3 do
                            Axios.Text({ `Row: {j}, Column: {i}` })
                            Axios.NextColumn()
                        end
                        Axios.NextRow()
                    end
                end
                Axios.End()
            end
            Axios.End()

            Axios.Tree({ "Headers, borders and backgrounds" })
            do
                local Type = Axios.State(0)
                local Header = Axios.State(false)
                local RowBackgrounds = Axios.State(false)
                local OuterBorders = Axios.State(true)
                local InnerBorders = Axios.State(true)

                Axios.Checkbox({ "Table header row" }, { isChecked = Header })
                Axios.Checkbox({ "Table row backgrounds" }, { isChecked = RowBackgrounds })
                Axios.Checkbox({ "Table outer border" }, { isChecked = OuterBorders })
                Axios.Checkbox({ "Table inner borders" }, { isChecked = InnerBorders })
                Axios.SameLine()
                do
                    Axios.Text({ "Cell contents" })
                    Axios.RadioButton({ "Text", 0 }, { index = Type })
                    Axios.RadioButton({ "Fill button", 1 }, { index = Type })
                end
                Axios.End()

                Axios.Table({ 3, Header.value, RowBackgrounds.value, OuterBorders.value, InnerBorders.value })
                do
                    Axios.SetHeaderColumnIndex(1)
                    for j = 0, 4 do
                        for i = 1, 3 do
                            if Type.value == 0 then
                                Axios.Text({ `Cell ({i}, {j})` })
                            else
                                Axios.Button({ `Cell ({i}, {j})`, UDim2.fromScale(1, 0) })
                            end
                            Axios.NextColumn()
                        end
                    end
                end
                Axios.End()
            end
            Axios.End()

            Axios.Tree({ "Sizing" })
            do
                local Resizable = Axios.State(false)
                local LimitWidth = Axios.State(false)
                Axios.Checkbox({ "Resizable" }, { isChecked = Resizable })
                Axios.Checkbox({ "Limit Table Width" }, { isChecked = LimitWidth })

                do
                    Axios.SeparatorText({ "stretch, equal" })
                    Axios.Table({ 3, false, true, true, true, Resizable.value })
                    do
                        for _ = 1, 3 do
                            for _ = 1, 3 do
                                Axios.Text({ "stretch" })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                    Axios.Table({ 3, false, true, true, true, Resizable.value })
                    do
                        for _ = 1, 3 do
                            for i = 1, 3 do
                                Axios.Text({ string.rep(string.char(64 + i), 4 * i) })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                end

                do
                    Axios.SeparatorText({ "stretch, proportional" })
                    Axios.Table({ 3, false, true, true, true, Resizable.value, false, true })
                    do
                        for _ = 1, 3 do
                            for _ = 1, 3 do
                                Axios.Text({ "stretch" })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                    Axios.Table({ 3, false, true, true, true, Resizable.value, false, true })
                    do
                        for _ = 1, 3 do
                            for i = 1, 3 do
                                Axios.Text({ string.rep(string.char(64 + i), 4 * i) })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                end

                do
                    Axios.SeparatorText({ "fixed, equal" })
                    Axios.Table({ 3, false, true, true, true, Resizable.value, true, false, LimitWidth.value })
                    do
                        for _ = 1, 3 do
                            for _ = 1, 3 do
                                Axios.Text({ "fixed" })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                    Axios.Table({ 3, false, true, true, true, Resizable.value, true, false, LimitWidth.value })
                    do
                        for _ = 1, 3 do
                            for i = 1, 3 do
                                Axios.Text({ string.rep(string.char(64 + i), 4 * i) })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                end

                do
                    Axios.SeparatorText({ "fixed, proportional" })
                    Axios.Table({ 3, false, true, true, true, Resizable.value, true, true, LimitWidth.value })
                    do
                        for _ = 1, 3 do
                            for _ = 1, 3 do
                                Axios.Text({ "fixed" })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                    Axios.Table({ 3, false, true, true, true, Resizable.value, true, true, LimitWidth.value })
                    do
                        for _ = 1, 3 do
                            for i = 1, 3 do
                                Axios.Text({ string.rep(string.char(64 + i), 4 * i) })
                                Axios.NextColumn()
                            end
                        end
                    end
                    Axios.End()
                end
            end
            Axios.End()

            Axios.Tree({ "Resizable" })
            do
                local NumColumns = Axios.State(4)
                local NumRows = Axios.State(3)
                local TableUseButtons = Axios.State(false)

                local HeaderState = Axios.State(true)
                local BackgroundState = Axios.State(true)
                local OuterBorderState = Axios.State(true)
                local InnerBorderState = Axios.State(true)
                local ResizableState = Axios.State(false)
                local FixedWidthState = Axios.State(false)
                local ProportionalWidthState = Axios.State(false)
                local LimitTableWidthState = Axios.State(false)

                local AddExtra = Axios.State(false)

                local WidthState = Axios.State(table.create(10, 100))

                Axios.SliderNum({ "Num Columns", 1, 1, 10 }, { number = NumColumns })
                Axios.SliderNum({ "Number of rows", 1, 0, 100 }, { number = NumRows })

                Axios.SameLine()
                do
                    Axios.RadioButton({ "Buttons", true }, { index = TableUseButtons })
                    Axios.RadioButton({ "Text", false }, { index = TableUseButtons })
                end
                Axios.End()

                Axios.Table({ 3 })
                do
                    Axios.Checkbox({ "Show Header Row" }, { isChecked = HeaderState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Show Row Backgrounds" }, { isChecked = BackgroundState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Show Outer Border" }, { isChecked = OuterBorderState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Show Inner Border" }, { isChecked = InnerBorderState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Resizable" }, { isChecked = ResizableState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Fixed Width" }, { isChecked = FixedWidthState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Proportional Width" }, { isChecked = ProportionalWidthState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Limit Table Width" }, { isChecked = LimitTableWidthState })
                    Axios.NextColumn()
                    Axios.Checkbox({ "Add extra" }, { isChecked = AddExtra })
                    Axios.NextColumn()
                end
                Axios.End()

                for i = 1, NumColumns.value do
                    local increment = if FixedWidthState.value == true then 1 else 0.05
                    local min = if FixedWidthState.value == true then 2 else 0.05
                    local max = if FixedWidthState.value == true then 480 else 1
                    Axios.SliderNum({ `Column {i} Width`, increment, min, max }, {
                        number = Axios.TableState(WidthState.value, i, function(value)
                            -- we have to force the state to change, because comparing two tables is equal
                            WidthState.value[i] = value
                            WidthState:set(WidthState.value, true)
                            return false
                        end),
                    })
                end

                Axios.PushConfig({
                    NumColumns = NumColumns.value,
                })
                Axios.Table(
                    { NumColumns.value, HeaderState.value, BackgroundState.value, OuterBorderState.value, InnerBorderState.value, ResizableState.value, FixedWidthState.value, ProportionalWidthState.value, LimitTableWidthState.value },
                    { widths = WidthState }
                )
                do
                    Axios.SetHeaderColumnIndex(1)
                    for i = 0, NumRows:get() do
                        for j = 1, NumColumns.value do
                            if i == 0 then
                                if TableUseButtons.value then
                                    Axios.Button({ `H: {j}` })
                                else
                                    Axios.Text({ `H: {j}` })
                                end
                            else
                                if TableUseButtons.value then
                                    Axios.Button({ `R: {i}, C: {j}` })
                                    Axios.Button({ string.rep("...", j) })
                                else
                                    Axios.Text({ `R: {i}, C: {j}` })
                                    Axios.Text({ string.rep("...", j) })
                                end
                            end
                            Axios.NextColumn()
                        end
                    end

                    if AddExtra.value then
                        Axios.Text({ "A really long piece of text!" })
                    end
                end
                Axios.End()
                Axios.PopConfig()
            end
            Axios.End()

            Axios.End()
        end
    end

    local function layoutDemo()
        Axios.CollapsingHeader({ "Widget Layout" })
        do
            Axios.Tree({ "Widget Alignment" })
            do
                Axios.Text({ "Axios.SameLine has optional argument supporting horizontal and vertical alignments." })
                Axios.Text({ "This allows widgets to be place anywhere on the line." })
                Axios.Separator()

                Axios.SameLine()
                do
                    Axios.Text({ "By default child widgets will be aligned to the left." })
                    helpMarker('Axios.SameLine()\n\tAxios.Button({ "Button A" })\n\tAxios.Button({ "Button B" })\nAxios.End()')
                end
                Axios.End()

                Axios.SameLine()
                do
                    Axios.Button({ "Button A" })
                    Axios.Button({ "Button B" })
                end
                Axios.End()

                Axios.SameLine()
                do
                    Axios.Text({ "But can be aligned to the center." })
                    helpMarker('Axios.SameLine({ nil, nil, Enum.HorizontalAlignment.Center })\n\tAxios.Button({ "Button A" })\n\tAxios.Button({ "Button B" })\nAxios.End()')
                end
                Axios.End()

                Axios.SameLine({ nil, nil, Enum.HorizontalAlignment.Center })
                do
                    Axios.Button({ "Button A" })
                    Axios.Button({ "Button B" })
                end
                Axios.End()

                Axios.SameLine()
                do
                    Axios.Text({ "Or right." })
                    helpMarker('Axios.SameLine({ nil, nil, Enum.HorizontalAlignment.Right })\n\tAxios.Button({ "Button A" })\n\tAxios.Button({ "Button B" })\nAxios.End()')
                end
                Axios.End()

                Axios.SameLine({ nil, nil, Enum.HorizontalAlignment.Right })
                do
                    Axios.Button({ "Button A" })
                    Axios.Button({ "Button B" })
                end
                Axios.End()

                Axios.Separator()

                Axios.SameLine()
                do
                    Axios.Text({ "You can also specify the padding." })
                    helpMarker('Axios.SameLine({ 0, nil, Enum.HorizontalAlignment.Center })\n\tAxios.Button({ "Button A" })\n\tAxios.Button({ "Button B" })\nAxios.End()')
                end
                Axios.End()

                Axios.SameLine({ 0, nil, Enum.HorizontalAlignment.Center })
                do
                    Axios.Button({ "Button A" })
                    Axios.Button({ "Button B" })
                end
                Axios.End()
            end
            Axios.End()

            Axios.Tree({ "Widget Sizing" })
            do
                Axios.Text({ "Nearly all widgets are the minimum size of the content." })
                Axios.Text({ "For example, text and button widgets will be the size of the text labels." })
                Axios.Text({ "Some widgets, such as the Image and Button have Size arguments will will set the size of them." })
                Axios.Separator()

                textAndHelpMarker("The button takes up the full screen-width.", 'Axios.Button({ "Button", UDim2.fromScale(1, 0) })')
                Axios.Button({ "Button", UDim2.fromScale(1, 0) })
                textAndHelpMarker("The button takes up half the screen-width.", 'Axios.Button({ "Button", UDim2.fromScale(0.5, 0) })')
                Axios.Button({ "Button", UDim2.fromScale(0.5, 0) })

                textAndHelpMarker("Combining with SameLine, the buttons can fill the screen width.", "The button will still be larger that the text size.")
                local num = Axios.State(2)
                Axios.SliderNum({ "Number of Buttons", 1, 1, 8 }, { number = num })
                Axios.SameLine({ 0, nil, Enum.HorizontalAlignment.Center })
                do
                    for i = 1, num.value do
                        Axios.Button({ `Button {i}`, UDim2.fromScale(1 / num.value, 0) })
                    end
                end
                Axios.End()
            end
            Axios.End()

            Axios.Tree({ "Content Width" })
            do
                local value = Axios.State(50)
                local index = Axios.State(Enum.Axis.X)

                Axios.Text({ "The Content Width is a size property which determines the width of input fields." })
                Axios.SameLine()
                do
                    Axios.Text({ "By default the value is UDim.new(0.65, 0)" })
                    helpMarker("This is the default value from Dear ImGui.\nIt is 65% of the window width.")
                end
                Axios.End()

                Axios.Text({ "This works well, but sometimes we know how wide elements are going to be and want to maximise the space." })
                Axios.Text({ "Therefore, we can use Axios.PushConfig() to change the width" })

                Axios.Separator()

                Axios.SameLine()
                do
                    Axios.Text({ "Content Width = 150 pixels" })
                    helpMarker("UDim.new(0, 150)")
                end
                Axios.End()

                Axios.PushConfig({ ContentWidth = UDim.new(0, 150) })
                Axios.DragNum({ "number", 1, 0, 100 }, { number = value })
                Axios.InputEnum({ "axis" }, { index = index }, Enum.Axis)
                Axios.PopConfig()

                Axios.SameLine()
                do
                    Axios.Text({ "Content Width = 50% window width" })
                    helpMarker("UDim.new(0.5, 0)")
                end
                Axios.End()

                Axios.PushConfig({ ContentWidth = UDim.new(0.5, 0) })
                Axios.DragNum({ "number", 1, 0, 100 }, { number = value })
                Axios.InputEnum({ "axis" }, { index = index }, Enum.Axis)
                Axios.PopConfig()

                Axios.SameLine()
                do
                    Axios.Text({ "Content Width = -150 pixels from the right side" })
                    helpMarker("UDim.new(1, -150)")
                end
                Axios.End()

                Axios.PushConfig({ ContentWidth = UDim.new(1, -150) })
                Axios.DragNum({ "number", 1, 0, 100 }, { number = value })
                Axios.InputEnum({ "axis" }, { index = index }, Enum.Axis)
                Axios.PopConfig()
            end
            Axios.End()

            Axios.Tree({ "Content Height" })
            do
                local text = Axios.State("a single line")
                local value = Axios.State(50)
                local index = Axios.State(Enum.Axis.X)
                local progress = Axios.State(0)

                -- formula to cycle between 0 and 100 linearly
                local newValue = math.clamp((math.abs((os.clock() * 15) % 100 - 50)) - 7.5, 0, 35) / 35
                progress:set(newValue)

                Axios.Text({ "The Content Height is a size property that determines the minimum size of certain widgets." })
                Axios.Text({ "By default the value is UDim.new(0, 0), so there is no minimum height." })
                Axios.Text({ "We use Axios.PushConfig() to change this value." })

                Axios.Separator()
                Axios.SameLine()
                do
                    Axios.Text({ "Content Height = 0 pixels" })
                    helpMarker("UDim.new(0, 0)")
                end
                Axios.End()

                Axios.InputText({ "text" }, { text = text })
                Axios.ProgressBar({ "progress" }, { progress = progress })
                Axios.DragNum({ "number", 1, 0, 100 }, { number = value })
                Axios.ComboEnum({ "axis" }, { index = index }, Enum.Axis)

                Axios.SameLine()
                do
                    Axios.Text({ "Content Height = 60 pixels" })
                    helpMarker("UDim.new(0, 60)")
                end
                Axios.End()

                Axios.PushConfig({ ContentHeight = UDim.new(0, 60) })
                Axios.InputText({ "text", nil, nil, true }, { text = text })
                Axios.ProgressBar({ "progress" }, { progress = progress })
                Axios.DragNum({ "number", 1, 0, 100 }, { number = value })
                Axios.ComboEnum({ "axis" }, { index = index }, Enum.Axis)
                Axios.PopConfig()

                Axios.Text({ "This property can be used to force the height of a text box." })
                Axios.Text({ "Just make sure you enable the MultiLine argument." })
            end
            Axios.End()
        end
        Axios.End()
    end

    -- showcases how widgets placed outside of a window are placed inside root
    local function windowlessDemo()
        Axios.PushConfig({ ItemWidth = UDim.new(0, 150) })
        Axios.SameLine()
        do
            Axios.TextWrapped({ "Windowless widgets" })
            helpMarker("Widgets which are placed outside of a window will appear on the top left side of the screen.")
        end
        Axios.End()

        Axios.Button({})
        Axios.Tree({})
        do
            Axios.InputText({})
        end
        Axios.End()

        Axios.PopConfig()
    end

    -- main demo window
    return function()
        local NoTitleBar = Axios.State(false)
        local NoBackground = Axios.State(false)
        local NoCollapse = Axios.State(false)
        local NoClose = Axios.State(true)
        local NoMove = Axios.State(false)
        local NoScrollbar = Axios.State(false)
        local NoResize = Axios.State(false)
        local NoNav = Axios.State(false)
        local NoMenu = Axios.State(false)

        if showMainWindow.value == false then
            Axios.Checkbox({ "Open main window" }, { isChecked = showMainWindow })
            return
        end

        debug.profilebegin("Axios/Demo/Window")
        local window = Axios.Window({
            [Axios.Args.Window.Title] = "Axios Demo Window",
            [Axios.Args.Window.NoTitleBar] = NoTitleBar.value,
            [Axios.Args.Window.NoBackground] = NoBackground.value,
            [Axios.Args.Window.NoCollapse] = NoCollapse.value,
            [Axios.Args.Window.NoClose] = NoClose.value,
            [Axios.Args.Window.NoMove] = NoMove.value,
            [Axios.Args.Window.NoScrollbar] = NoScrollbar.value,
            [Axios.Args.Window.NoResize] = NoResize.value,
            [Axios.Args.Window.NoNav] = NoNav.value,
            [Axios.Args.Window.NoMenu] = NoMenu.value,
        }, { size = Axios.State(Vector2.new(600, 550)), position = Axios.State(Vector2.new(100, 25)), isOpened = showMainWindow })

        if window.state.isUncollapsed.value and window.state.isOpened.value then
            debug.profilebegin("Axios/Demo/MenuBar")
            mainMenuBar()
            debug.profileend()

            Axios.Text({ "Axios says hello. (" .. Axios.Internal._version .. ")" })

            debug.profilebegin("Axios/Demo/Options")
            Axios.CollapsingHeader({ "Window Options" })
            do
                Axios.Table({ 3, false, false, false })
                do
                    Axios.Checkbox({ "NoTitleBar" }, { isChecked = NoTitleBar })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoBackground" }, { isChecked = NoBackground })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoCollapse" }, { isChecked = NoCollapse })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoClose" }, { isChecked = NoClose })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoMove" }, { isChecked = NoMove })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoScrollbar" }, { isChecked = NoScrollbar })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoResize" }, { isChecked = NoResize })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoNav" }, { isChecked = NoNav })
                    Axios.NextColumn()
                    Axios.Checkbox({ "NoMenu" }, { isChecked = NoMenu })
                    Axios.NextColumn()
                end
                Axios.End()
            end
            Axios.End()
            debug.profileend()

            debug.profilebegin("Axios/Demo/Events")
            widgetEventInteractivity()
            debug.profileend()

            debug.profilebegin("Axios/Demo/States")
            widgetStateInteractivity()
            debug.profileend()

            debug.profilebegin("Axios/Demo/Recursive")
            Axios.CollapsingHeader({ "Recursive Tree" })
            recursiveTree()
            Axios.End()
            debug.profileend()

            debug.profilebegin("Axios/Demo/Style")
            dynamicStyle()
            debug.profileend()

            Axios.Separator()

            debug.profilebegin("Axios/Demo/Widgets")
            Axios.CollapsingHeader({ "Widgets" })
            do
                for _, name in widgetDemosOrder do
                    debug.profilebegin(`Axios/Demo/Widgets/{name}`)
                    widgetDemos[name]()
                    debug.profileend()
                end
            end
            Axios.End()
            debug.profileend()

            debug.profilebegin("Axios/Demo/Tables")
            tablesDemo()
            debug.profileend()

            debug.profilebegin("Axios/Demo/Layout")
            layoutDemo()
            debug.profileend()

            Axios.CollapsingHeader({ "Background" })
            do
                Axios.Checkbox({ "Show background colour" }, { isChecked = showBackground })
                Axios.InputColor4({ "Background colour" }, { color = backgroundColour, transparency = backgroundTransparency })
            end
            Axios.End()
        end
        Axios.End()
        debug.profileend()

        if showRecursiveWindow.value then
            recursiveWindow(showRecursiveWindow)
        end
        if showRuntimeInfo.value then
            runtimeInfo()
        end
        if showDebugWindow.value then
            debugPanel()
        end
        if showStyleEditor.value then
            styleEditor()
        end
        if showWindowlessDemo.value then
            windowlessDemo()
        end

        if showMainMenuBarWindow.value then
            mainMenuBarExample()
        end

        return window
    end
end

end

_modules["Axios.widgets"] = function()
    local script = create_mock_script("Axios.widgets")
    local require = axios_require
local Types = require(script.Parent.Types)

local widgets = {} :: Types.WidgetUtility

return function(Axios: Types.Internal)
    widgets.GuiService = game:GetService("GuiService")
    widgets.RunService = game:GetService("RunService")
    widgets.UserInputService = game:GetService("UserInputService")
    widgets.ContextActionService = game:GetService("ContextActionService")
    widgets.TextService = game:GetService("TextService")

    widgets.ICONS = {
        BLANK_SQUARE = "rbxassetid://83265623867126",
        RIGHT_POINTING_TRIANGLE = "rbxassetid://105541346271951",
        DOWN_POINTING_TRIANGLE = "rbxassetid://95465797476827",
        MULTIPLICATION_SIGN = "rbxassetid://133890060015237", -- best approximation for a close X which roblox supports, needs to be scaled about 2x
        BOTTOM_RIGHT_CORNER = "rbxassetid://125737344915000", -- used in window resize icon in bottom right
        CHECKMARK = "rbxassetid://109638815494221",
        BORDER = "rbxassetid://133803690460269",
        ALPHA_BACKGROUND_TEXTURE = "rbxassetid://114090016039876", -- used for color4 alpha
        UNKNOWN_TEXTURE = "rbxassetid://95045813476061",
    }

    widgets.IS_STUDIO = widgets.RunService:IsStudio()
    function widgets.getTime()
        -- time() always returns 0 in the context of plugins
        if widgets.IS_STUDIO then
            return os.clock()
        else
            return time()
        end
    end

    -- acts as an offset where the absolute position of the base frame is not zero, such as IgnoreGuiInset or for stories
    widgets.GuiOffset = if Axios._config.IgnoreGuiInset then -widgets.GuiService:GetGuiInset() else Vector2.zero
    -- the registered mouse position always ignores the topbar, so needs a separate variable offset
    widgets.MouseOffset = if Axios._config.IgnoreGuiInset then Vector2.zero else widgets.GuiService:GetGuiInset()

    -- the topbar inset changes updates a frame later.
    local connection: RBXScriptConnection
    connection = widgets.GuiService:GetPropertyChangedSignal("TopbarInset"):Once(function()
        widgets.MouseOffset = if Axios._config.IgnoreGuiInset then Vector2.zero else widgets.GuiService:GetGuiInset()
        widgets.GuiOffset = if Axios._config.IgnoreGuiInset then -widgets.GuiService:GetGuiInset() else Vector2.zero
        connection:Disconnect()
    end)
    -- in case the topbar doesn't change, we cancel the event.
    task.delay(5, function()
        connection:Disconnect()
    end)

    function widgets.getMouseLocation()
        return widgets.UserInputService:GetMouseLocation() - widgets.MouseOffset
    end

    function widgets.isPosInsideRect(pos: Vector2, rectMin: Vector2, rectMax: Vector2)
        return pos.X >= rectMin.X and pos.X <= rectMax.X and pos.Y >= rectMin.Y and pos.Y <= rectMax.Y
    end

    function widgets.findBestWindowPosForPopup(refPos: Vector2, size: Vector2, outerMin: Vector2, outerMax: Vector2)
        local CURSOR_OFFSET_DIST = 20

        if refPos.X + size.X + CURSOR_OFFSET_DIST > outerMax.X then
            if refPos.Y + size.Y + CURSOR_OFFSET_DIST > outerMax.Y then
                -- placed to the top
                refPos += Vector2.new(0, -(CURSOR_OFFSET_DIST + size.Y))
            else
                -- placed to the bottom
                refPos += Vector2.new(0, CURSOR_OFFSET_DIST)
            end
        else
            -- placed to the right
            refPos += Vector2.new(CURSOR_OFFSET_DIST)
        end

        return Vector2.new(math.max(math.min(refPos.X + size.X, outerMax.X) - size.X, outerMin.X), math.max(math.min(refPos.Y + size.Y, outerMax.Y) - size.Y, outerMin.Y))
    end

    function widgets.getScreenSizeForWindow(thisWidget: Types.Widget) -- possible parents are GuiBase2d, CoreGui, PlayerGui
        if thisWidget.Instance:IsA("GuiBase2d") then
            return thisWidget.Instance.AbsoluteSize
        else
            local rootParent = thisWidget.Instance.Parent
            if rootParent:IsA("GuiBase2d") then
                return rootParent.AbsoluteSize
            else
                if rootParent.Parent:IsA("GuiBase2d") then
                    return rootParent.AbsoluteSize
                else
                    return workspace.CurrentCamera.ViewportSize
                end
            end
        end
    end

    function widgets.extend(superClass: Types.WidgetClass, subClass: Types.WidgetClass): Types.WidgetClass
        local newClass = table.clone(superClass)
        for index, value in subClass do
            newClass[index] = value
        end
        return newClass
    end

    function widgets.UIPadding(Parent: GuiObject, PxPadding: Vector2)
        local UIPaddingInstance = Instance.new("UIPadding")
        UIPaddingInstance.PaddingLeft = UDim.new(0, PxPadding.X)
        UIPaddingInstance.PaddingRight = UDim.new(0, PxPadding.X)
        UIPaddingInstance.PaddingTop = UDim.new(0, PxPadding.Y)
        UIPaddingInstance.PaddingBottom = UDim.new(0, PxPadding.Y)
        UIPaddingInstance.Parent = Parent
        return UIPaddingInstance
    end

    function widgets.UIListLayout(Parent: GuiObject, FillDirection: Enum.FillDirection, Padding: UDim)
        local UIListLayoutInstance = Instance.new("UIListLayout")
        UIListLayoutInstance.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayoutInstance.Padding = Padding
        UIListLayoutInstance.FillDirection = FillDirection
        UIListLayoutInstance.Parent = Parent
        return UIListLayoutInstance
    end

    function widgets.UIStroke(Parent: GuiObject, Thickness: number, Color: Color3, Transparency: number)
        local UIStrokeInstance = Instance.new("UIStroke")
        UIStrokeInstance.Thickness = Thickness
        UIStrokeInstance.Color = Color
        UIStrokeInstance.Transparency = Transparency
        UIStrokeInstance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStrokeInstance.LineJoinMode = Enum.LineJoinMode.Round
        UIStrokeInstance.Parent = Parent
        return UIStrokeInstance
    end

    function widgets.UICorner(Parent: GuiObject, PxRounding: number?)
        local UICornerInstance = Instance.new("UICorner")
        UICornerInstance.CornerRadius = UDim.new(PxRounding and 0 or 1, PxRounding or 0)
        UICornerInstance.Parent = Parent
        return UICornerInstance
    end

    function widgets.UISizeConstraint(Parent: GuiObject, MinSize: Vector2?, MaxSize: Vector2?)
        local UISizeConstraintInstance = Instance.new("UISizeConstraint")
        UISizeConstraintInstance.MinSize = MinSize or UISizeConstraintInstance.MinSize -- made these optional
        UISizeConstraintInstance.MaxSize = MaxSize or UISizeConstraintInstance.MaxSize
        UISizeConstraintInstance.Parent = Parent
        return UISizeConstraintInstance
    end

    -- below uses Axios

    function widgets.applyTextStyle(thisInstance: TextLabel & TextButton & TextBox)
        thisInstance.FontFace = Axios._config.TextFont
        thisInstance.TextSize = Axios._config.TextSize
        thisInstance.TextColor3 = Axios._config.TextColor
        thisInstance.TextTransparency = Axios._config.TextTransparency
        thisInstance.TextXAlignment = Enum.TextXAlignment.Left
        thisInstance.TextYAlignment = Enum.TextYAlignment.Center
        thisInstance.RichText = Axios._config.RichText
        thisInstance.TextWrapped = Axios._config.TextWrapped

        thisInstance.AutoLocalize = false
    end

    function widgets.applyInteractionHighlights(Property: string, Button: GuiButton, Highlightee: GuiObject, Colors: { [string]: any })
        local exitedButton = false
        widgets.applyMouseEnter(Button, function()
            Highlightee[Property .. "Color3"] = Colors.HoveredColor
            Highlightee[Property .. "Transparency"] = Colors.HoveredTransparency

            exitedButton = false
        end)

        widgets.applyMouseLeave(Button, function()
            Highlightee[Property .. "Color3"] = Colors.Color
            Highlightee[Property .. "Transparency"] = Colors.Transparency

            exitedButton = true
        end)

        widgets.applyInputBegan(Button, function(input: InputObject)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) then
                return
            end
            Highlightee[Property .. "Color3"] = Colors.ActiveColor
            Highlightee[Property .. "Transparency"] = Colors.ActiveTransparency
        end)

        widgets.applyInputEnded(Button, function(input: InputObject)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) or exitedButton then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Highlightee[Property .. "Color3"] = Colors.HoveredColor
                Highlightee[Property .. "Transparency"] = Colors.HoveredTransparency
            end
            if input.UserInputType == Enum.UserInputType.Gamepad1 then
                Highlightee[Property .. "Color3"] = Colors.Color
                Highlightee[Property .. "Transparency"] = Colors.Transparency
            end
        end)

        Button.SelectionImageObject = Axios.SelectionImageObject
    end

    function widgets.applyInteractionHighlightsWithMultiHighlightee(Property: string, Button: GuiButton, Highlightees: { { GuiObject | { [string]: Color3 | number } } })
        local exitedButton = false
        widgets.applyMouseEnter(Button, function()
            for _, Highlightee in Highlightees do
                Highlightee[1][Property .. "Color3"] = Highlightee[2].HoveredColor
                Highlightee[1][Property .. "Transparency"] = Highlightee[2].HoveredTransparency

                exitedButton = false
            end
        end)

        widgets.applyMouseLeave(Button, function()
            for _, Highlightee in Highlightees do
                Highlightee[1][Property .. "Color3"] = Highlightee[2].Color
                Highlightee[1][Property .. "Transparency"] = Highlightee[2].Transparency

                exitedButton = true
            end
        end)

        widgets.applyInputBegan(Button, function(input: InputObject)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) then
                return
            end
            for _, Highlightee in Highlightees do
                Highlightee[1][Property .. "Color3"] = Highlightee[2].ActiveColor
                Highlightee[1][Property .. "Transparency"] = Highlightee[2].ActiveTransparency
            end
        end)

        widgets.applyInputEnded(Button, function(input: InputObject)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) or exitedButton then
                return
            end
            for _, Highlightee in Highlightees do
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Highlightee[1][Property .. "Color3"] = Highlightee[2].HoveredColor
                    Highlightee[1][Property .. "Transparency"] = Highlightee[2].HoveredTransparency
                end
                if input.UserInputType == Enum.UserInputType.Gamepad1 then
                    Highlightee[1][Property .. "Color3"] = Highlightee[2].Color
                    Highlightee[1][Property .. "Transparency"] = Highlightee[2].Transparency
                end
            end
        end)

        Button.SelectionImageObject = Axios.SelectionImageObject
    end

    function widgets.applyFrameStyle(thisInstance: GuiObject, noPadding: boolean?, noCorner: boolean?)
        -- padding, border, and rounding
        -- optimized to only use what instances are needed, based on style
        local FrameBorderSize = Axios._config.FrameBorderSize
        local FrameRounding = Axios._config.FrameRounding
        thisInstance.BorderSizePixel = 0

        if FrameBorderSize > 0 then
            widgets.UIStroke(thisInstance, FrameBorderSize, Axios._config.BorderColor, Axios._config.BorderTransparency)
        end
        if FrameRounding > 0 and not noCorner then
            widgets.UICorner(thisInstance, FrameRounding)
        end
        if not noPadding then
            widgets.UIPadding(thisInstance, Axios._config.FramePadding)
        end
    end

    function widgets.applyButtonClick(thisInstance: GuiButton, callback: () -> ())
        thisInstance.MouseButton1Click:Connect(function()
            callback()
        end)
    end

    function widgets.applyButtonDown(thisInstance: GuiButton, callback: (x: number, y: number) -> ())
        thisInstance.MouseButton1Down:Connect(function(x: number, y: number)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyMouseEnter(thisInstance: GuiObject, callback: (x: number, y: number) -> ())
        thisInstance.MouseEnter:Connect(function(x: number, y: number)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyMouseMoved(thisInstance: GuiObject, callback: (x: number, y: number) -> ())
        thisInstance.MouseMoved:Connect(function(x: number, y: number)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyMouseLeave(thisInstance: GuiObject, callback: (x: number, y: number) -> ())
        thisInstance.MouseLeave:Connect(function(x: number, y: number)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyInputBegan(thisInstance: GuiButton, callback: (input: InputObject) -> ())
        thisInstance.InputBegan:Connect(function(...)
            callback(...)
        end)
    end

    function widgets.applyInputEnded(thisInstance: GuiButton, callback: (input: InputObject) -> ())
        thisInstance.InputEnded:Connect(function(...)
            callback(...)
        end)
    end

    function widgets.discardState(thisWidget: Types.StateWidget)
        for _, state in thisWidget.state do
            state.ConnectedWidgets[thisWidget.ID] = nil
        end
    end

    function widgets.registerEvent(event: string, callback: (...any) -> ())
        table.insert(Axios._initFunctions, function()
            table.insert(Axios._connections, widgets.UserInputService[event]:Connect(callback))
        end)
    end

    widgets.EVENTS = {
        hover = function(pathToHovered: (thisWidget: Types.Widget) -> GuiObject)
            return {
                ["Init"] = function(thisWidget: Types.Widget & Types.Hovered)
                    local hoveredGuiObject = pathToHovered(thisWidget)
                    widgets.applyMouseEnter(hoveredGuiObject, function()
                        thisWidget.isHoveredEvent = true
                    end)
                    widgets.applyMouseLeave(hoveredGuiObject, function()
                        thisWidget.isHoveredEvent = false
                    end)
                    thisWidget.isHoveredEvent = false
                end,
                ["Get"] = function(thisWidget: Types.Widget & Types.Hovered)
                    return thisWidget.isHoveredEvent
                end,
            }
        end,

        click = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
            return {
                ["Init"] = function(thisWidget: Types.Widget & Types.Clicked)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastClickedTick = -1

                    widgets.applyButtonClick(clickedGuiObject, function()
                        thisWidget.lastClickedTick = Axios._cycleTick + 1
                    end)
                end,
                ["Get"] = function(thisWidget: Types.Widget & Types.Clicked)
                    return thisWidget.lastClickedTick == Axios._cycleTick
                end,
            }
        end,

        rightClick = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
            return {
                ["Init"] = function(thisWidget: Types.Widget & Types.RightClicked)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastRightClickedTick = -1

                    clickedGuiObject.MouseButton2Click:Connect(function()
                        thisWidget.lastRightClickedTick = Axios._cycleTick + 1
                    end)
                end,
                ["Get"] = function(thisWidget: Types.Widget & Types.RightClicked)
                    return thisWidget.lastRightClickedTick == Axios._cycleTick
                end,
            }
        end,

        doubleClick = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
            return {
                ["Init"] = function(thisWidget: Types.Widget & Types.DoubleClicked)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastClickedTime = -1
                    thisWidget.lastClickedPosition = Vector2.zero
                    thisWidget.lastDoubleClickedTick = -1

                    widgets.applyButtonDown(clickedGuiObject, function(x: number, y: number)
                        local currentTime = widgets.getTime()
                        local isTimeValid = currentTime - thisWidget.lastClickedTime < Axios._config.MouseDoubleClickTime
                        if isTimeValid and (Vector2.new(x, y) - thisWidget.lastClickedPosition).Magnitude < Axios._config.MouseDoubleClickMaxDist then
                            thisWidget.lastDoubleClickedTick = Axios._cycleTick + 1
                        else
                            thisWidget.lastClickedTime = currentTime
                            thisWidget.lastClickedPosition = Vector2.new(x, y)
                        end
                    end)
                end,
                ["Get"] = function(thisWidget: Types.Widget & Types.DoubleClicked)
                    return thisWidget.lastDoubleClickedTick == Axios._cycleTick
                end,
            }
        end,

        ctrlClick = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
            return {
                ["Init"] = function(thisWidget: Types.Widget & Types.CtrlClicked)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastCtrlClickedTick = -1

                    widgets.applyButtonClick(clickedGuiObject, function()
                        if widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                            thisWidget.lastCtrlClickedTick = Axios._cycleTick + 1
                        end
                    end)
                end,
                ["Get"] = function(thisWidget: Types.Widget & Types.CtrlClicked)
                    return thisWidget.lastCtrlClickedTick == Axios._cycleTick
                end,
            }
        end,
    }

    Axios._utility = widgets

    require(script.Root)(Axios, widgets)
    require(script.Window)(Axios, widgets)

    require(script.Menu)(Axios, widgets)

    require(script.Format)(Axios, widgets)

    require(script.Text)(Axios, widgets)
    require(script.Button)(Axios, widgets)
    require(script.Checkbox)(Axios, widgets)
    require(script.RadioButton)(Axios, widgets)
    require(script.Image)(Axios, widgets)

    require(script.Tree)(Axios, widgets)
    require(script.Tab)(Axios, widgets)

    require(script.Input)(Axios, widgets)
    require(script.Combo)(Axios, widgets)
    require(script.Plot)(Axios, widgets)

    require(script.Table)(Axios, widgets)
end

end

_modules["Axios.widgets.Button"] = function()
    local script = create_mock_script("Axios.widgets.Button")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local abstractButton = {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Size"] = 2,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(_thisWidget: Types.Button)
            local Button = Instance.new("TextButton")
            Button.AutomaticSize = Enum.AutomaticSize.XY
            Button.Size = UDim2.fromOffset(0, 0)
            Button.BackgroundColor3 = Axios._config.ButtonColor
            Button.BackgroundTransparency = Axios._config.ButtonTransparency
            Button.AutoButtonColor = false

            widgets.applyTextStyle(Button)
            Button.TextXAlignment = Enum.TextXAlignment.Center

            widgets.applyFrameStyle(Button)

            widgets.applyInteractionHighlights("Background", Button, Button, {
                Color = Axios._config.ButtonColor,
                Transparency = Axios._config.ButtonTransparency,
                HoveredColor = Axios._config.ButtonHoveredColor,
                HoveredTransparency = Axios._config.ButtonHoveredTransparency,
                ActiveColor = Axios._config.ButtonActiveColor,
                ActiveTransparency = Axios._config.ButtonActiveTransparency,
            })

            return Button
        end,
        Update = function(thisWidget: Types.Button)
            local Button = thisWidget.Instance :: TextButton
            Button.Text = thisWidget.arguments.Text or "Button"
            Button.Size = thisWidget.arguments.Size or UDim2.fromOffset(0, 0)
        end,
        Discard = function(thisWidget: Types.Button)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass
    widgets.abstractButton = abstractButton

    --stylua: ignore
    Axios.WidgetConstructor("Button", widgets.extend(abstractButton, {
            Generate = function(thisWidget: Types.Button)
                local Button = abstractButton.Generate(thisWidget)
                Button.Name = "Axios_Button"

                return Button
            end,
        } :: Types.WidgetClass)
    )

    --stylua: ignore
    Axios.WidgetConstructor("SmallButton", widgets.extend(abstractButton, {
            Generate = function(thisWidget: Types.Button)
                local SmallButton = abstractButton.Generate(thisWidget)
                SmallButton.Name = "Axios_SmallButton"

                local uiPadding: UIPadding = SmallButton.UIPadding
                uiPadding.PaddingLeft = UDim.new(0, 2)
                uiPadding.PaddingRight = UDim.new(0, 2)
                uiPadding.PaddingTop = UDim.new(0, 0)
                uiPadding.PaddingBottom = UDim.new(0, 0)

                return SmallButton
            end,
        } :: Types.WidgetClass)
    )
end

end

_modules["Axios.widgets.Checkbox"] = function()
    local script = create_mock_script("Axios.widgets.Checkbox")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    --stylua: ignore
    Axios.WidgetConstructor("Checkbox", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
        },
        Events = {
            ["checked"] = {
                ["Init"] = function(_thisWidget: Types.Checkbox) end,
                ["Get"] = function(thisWidget: Types.Checkbox)
                    return thisWidget.lastCheckedTick == Axios._cycleTick
                end,
            },
            ["unchecked"] = {
                ["Init"] = function(_thisWidget: Types.Checkbox) end,
                ["Get"] = function(thisWidget: Types.Checkbox)
                    return thisWidget.lastUncheckedTick == Axios._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.Checkbox)
            local Checkbox = Instance.new("TextButton")
            Checkbox.Name = "Axios_Checkbox"
            Checkbox.AutomaticSize = Enum.AutomaticSize.XY
            Checkbox.Size = UDim2.fromOffset(0, 0)
            Checkbox.BackgroundTransparency = 1
            Checkbox.BorderSizePixel = 0
            Checkbox.Text = ""
            Checkbox.AutoButtonColor = false
            
            widgets.UIListLayout(Checkbox, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local checkboxSize = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y

            local Box = Instance.new("Frame")
            Box.Name = "Box"
            Box.Size = UDim2.fromOffset(checkboxSize, checkboxSize)
            Box.BackgroundColor3 = Axios._config.FrameBgColor
            Box.BackgroundTransparency = Axios._config.FrameBgTransparency
            
            widgets.applyFrameStyle(Box, true)
            widgets.UIPadding(Box, Vector2.new(math.floor(checkboxSize / 10), math.floor(checkboxSize / 10)))

            widgets.applyInteractionHighlights("Background", Checkbox, Box, {
                Color = Axios._config.FrameBgColor,
                Transparency = Axios._config.FrameBgTransparency,
                HoveredColor = Axios._config.FrameBgHoveredColor,
                HoveredTransparency = Axios._config.FrameBgHoveredTransparency,
                ActiveColor = Axios._config.FrameBgActiveColor,
                ActiveTransparency = Axios._config.FrameBgActiveTransparency,
            })

            Box.Parent = Checkbox

            local Checkmark = Instance.new("ImageLabel")
            Checkmark.Name = "Checkmark"
            Checkmark.Size = UDim2.fromScale(1, 1)
            Checkmark.BackgroundTransparency = 1
            Checkmark.Image = widgets.ICONS.CHECKMARK
            Checkmark.ImageColor3 = Axios._config.CheckMarkColor
            Checkmark.ImageTransparency = 1
            Checkmark.ScaleType = Enum.ScaleType.Fit

            Checkmark.Parent = Box

            widgets.applyButtonClick(Checkbox, function()
                thisWidget.state.isChecked:set(not thisWidget.state.isChecked.value)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)
            TextLabel.Parent = Checkbox

            return Checkbox
        end,
        GenerateState = function(thisWidget: Types.Checkbox)
            if thisWidget.state.isChecked == nil then
                thisWidget.state.isChecked = Axios._widgetState(thisWidget, "checked", false)
            end
        end,
        Update = function(thisWidget: Types.Checkbox)
            local Checkbox = thisWidget.Instance :: TextButton
            Checkbox.TextLabel.Text = thisWidget.arguments.Text or "Checkbox"
        end,
        UpdateState = function(thisWidget: Types.Checkbox)
            local Checkbox = thisWidget.Instance :: TextButton
            local Box = Checkbox.Box :: Frame
            local Checkmark: ImageLabel = Box.Checkmark
            if thisWidget.state.isChecked.value then
                Checkmark.ImageTransparency = Axios._config.CheckMarkTransparency
                thisWidget.lastCheckedTick = Axios._cycleTick + 1
            else
                Checkmark.ImageTransparency = 1
                thisWidget.lastUncheckedTick = Axios._cycleTick + 1
            end
        end,
        Discard = function(thisWidget: Types.Checkbox)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Combo"] = function()
    local script = create_mock_script("Axios.widgets.Combo")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    --stylua: ignore
    Axios.WidgetConstructor("Selectable", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Index"] = 2,
            ["NoClick"] = 3,
        },
        Events = {
            ["selected"] = {
                ["Init"] = function(_thisWidget: Types.Selectable) end,
                ["Get"] = function(thisWidget: Types.Selectable)
                    return thisWidget.lastSelectedTick == Axios._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget: Types.Selectable) end,
                ["Get"] = function(thisWidget: Types.Selectable)
                    return thisWidget.lastUnselectedTick == Axios._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget: Types.Selectable) end,
                ["Get"] = function(thisWidget: Types.Selectable)
                    return thisWidget.state.index.value == thisWidget.arguments.Index
                end,
            },
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
        },
        Generate = function(thisWidget: Types.Selectable)
            local Selectable = Instance.new("Frame")
            Selectable.Name = "Axios_Selectable"
            Selectable.Size = UDim2.new(Axios._config.ItemWidth, UDim.new(0, Axios._config.TextSize + 2 * Axios._config.FramePadding.Y - Axios._config.ItemSpacing.Y))
            Selectable.BackgroundTransparency = 1
            Selectable.BorderSizePixel = 0

            local SelectableButton = Instance.new("TextButton")
            SelectableButton.Name = "SelectableButton"
            SelectableButton.Size = UDim2.new(1, 0, 0, Axios._config.TextSize + 2 * Axios._config.FramePadding.Y)
            SelectableButton.Position = UDim2.fromOffset(0, -bit32.rshift(Axios._config.ItemSpacing.Y, 1)) -- divide by 2
            SelectableButton.BackgroundColor3 = Axios._config.HeaderColor
            SelectableButton.ClipsDescendants = true

            widgets.applyFrameStyle(SelectableButton)
            widgets.applyTextStyle(SelectableButton)
            widgets.UISizeConstraint(SelectableButton, Vector2.xAxis)

            thisWidget.ButtonColors = {
                Color = Axios._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Axios._config.HeaderHoveredColor,
                HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                ActiveColor = Axios._config.HeaderActiveColor,
                ActiveTransparency = Axios._config.HeaderActiveTransparency,
            }

            widgets.applyInteractionHighlights("Background", SelectableButton, SelectableButton, thisWidget.ButtonColors)

            widgets.applyButtonClick(SelectableButton, function()
                if thisWidget.arguments.NoClick ~= true then
                    if type(thisWidget.state.index.value) == "boolean" then
                        thisWidget.state.index:set(not thisWidget.state.index.value)
                    else
                        thisWidget.state.index:set(thisWidget.arguments.Index)
                    end
                end
            end)

            SelectableButton.Parent = Selectable

            return Selectable
        end,
        GenerateState = function(thisWidget: Types.Selectable)
            if thisWidget.state.index == nil then
                if thisWidget.arguments.Index ~= nil then
                    error("A shared state index is required for Axios.Selectables() with an Index argument.", 5)
                end
                thisWidget.state.index = Axios._widgetState(thisWidget, "index", false)
            end
        end,
        Update = function(thisWidget: Types.Selectable)
            local Selectable = thisWidget.Instance :: Frame
            local SelectableButton: TextButton = Selectable.SelectableButton
            SelectableButton.Text = thisWidget.arguments.Text or "Selectable"
        end,
        UpdateState = function(thisWidget: Types.Selectable)
            local Selectable = thisWidget.Instance :: Frame
            local SelectableButton: TextButton = Selectable.SelectableButton
            
            if thisWidget.state.index.value == thisWidget.arguments.Index or thisWidget.state.index.value == true then
                thisWidget.ButtonColors.Transparency = Axios._config.HeaderTransparency
                SelectableButton.BackgroundTransparency = Axios._config.HeaderTransparency
                thisWidget.lastSelectedTick = Axios._cycleTick + 1
            else
                thisWidget.ButtonColors.Transparency = 1
                SelectableButton.BackgroundTransparency = 1
                thisWidget.lastUnselectedTick = Axios._cycleTick + 1
            end
        end,
        Discard = function(thisWidget: Types.Selectable)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)

    local AnyOpenedCombo = false
    local ComboOpenedTick = -1
    local OpenedCombo: Types.Combo? = nil
    local CachedContentSize = 0

    local function UpdateChildContainerTransform(thisWidget: Types.Combo)
        local Combo = thisWidget.Instance :: Frame
        local PreviewContainer = Combo.PreviewContainer :: TextButton
        local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame

        local previewPosition = PreviewContainer.AbsolutePosition - widgets.GuiOffset
        local previewSize = PreviewContainer.AbsoluteSize
        local borderSize = Axios._config.PopupBorderSize
        local screenSize: Vector2 = ChildContainer.Parent.AbsoluteSize

        local absoluteContentSize = thisWidget.UIListLayout.AbsoluteContentSize.Y
        CachedContentSize = absoluteContentSize

        local contentsSize = absoluteContentSize + 2 * Axios._config.WindowPadding.Y

        local x = previewPosition.X
        local y = previewPosition.Y + previewSize.Y + borderSize
        local anchor = Vector2.zero
        local distanceToScreen = screenSize.Y - y

        -- Only extend upwards if we cannot fully extend downwards, and we are on the bottom half of the screen.
        --  i.e. there is more space upwards than there is downwards.
        if contentsSize > distanceToScreen and y > (screenSize.Y / 2) then
            y = previewPosition.Y - borderSize
            anchor = Vector2.yAxis
            distanceToScreen = y -- from 0 to the current position
        end

        ChildContainer.AnchorPoint = anchor
        ChildContainer.Position = UDim2.fromOffset(x, y)

        local height = math.min(contentsSize, distanceToScreen)
        ChildContainer.Size = UDim2.fromOffset(PreviewContainer.AbsoluteSize.X, height)
    end

    table.insert(Axios._postCycleCallbacks, function()
        if AnyOpenedCombo and OpenedCombo then
            local contentSize = OpenedCombo.UIListLayout.AbsoluteContentSize.Y
            if contentSize ~= CachedContentSize then
                UpdateChildContainerTransform(OpenedCombo)
            end
        end
    end)

    local function UpdateComboState(input: InputObject)
        if not Axios._started then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseButton2 and input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseWheel then
            return
        end
        if AnyOpenedCombo == false or not OpenedCombo then
            return
        end
        if ComboOpenedTick == Axios._cycleTick then
            return
        end

        local MouseLocation = widgets.getMouseLocation()
        local Combo = OpenedCombo.Instance :: Frame
        local PreviewContainer: TextButton = Combo.PreviewContainer
        local ChildContainer = OpenedCombo.ChildContainer
        local rectMin = PreviewContainer.AbsolutePosition - widgets.GuiOffset
        local rectMax = PreviewContainer.AbsolutePosition - widgets.GuiOffset + PreviewContainer.AbsoluteSize
        if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
            return
        end

        rectMin = ChildContainer.AbsolutePosition - widgets.GuiOffset
        rectMax = ChildContainer.AbsolutePosition - widgets.GuiOffset + ChildContainer.AbsoluteSize
        if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
            return
        end

        OpenedCombo.state.isOpened:set(false)
    end

    widgets.registerEvent("InputBegan", UpdateComboState)

    widgets.registerEvent("InputChanged", UpdateComboState)

    --stylua: ignore
    Axios.WidgetConstructor("Combo", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
            ["NoButton"] = 2,
            ["NoPreview"] = 3,
        },
        Events = {
            ["opened"] = {
                ["Init"] = function(_thisWidget: Types.Combo) end,
                ["Get"] = function(thisWidget: Types.Combo)
                    return thisWidget.lastOpenedTick == Axios._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget: Types.Combo) end,
                ["Get"] = function(thisWidget: Types.Combo)
                    return thisWidget.lastClosedTick == Axios._cycleTick
                end,
            },
            ["changed"] = {
                ["Init"] = function(_thisWidget: Types.Combo) end,
                ["Get"] = function(thisWidget: Types.Combo)
                    return thisWidget.lastChangedTick == Axios._cycleTick
                end,
            },
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                local Combo = thisWidget.Instance :: Frame
                return Combo.PreviewContainer
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.Combo)
            local frameHeight = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y

            local Combo = Instance.new("Frame")
            Combo.Name = "Axios_Combo"
            Combo.AutomaticSize = Enum.AutomaticSize.Y
            Combo.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            Combo.BackgroundTransparency = 1
            Combo.BorderSizePixel = 0

            widgets.UIListLayout(Combo, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local PreviewContainer = Instance.new("TextButton")
            PreviewContainer.Name = "PreviewContainer"
            PreviewContainer.AutomaticSize = Enum.AutomaticSize.Y
            PreviewContainer.Size = UDim2.new(Axios._config.ContentWidth, UDim.new(0, 0))
            PreviewContainer.BackgroundTransparency = 1
            PreviewContainer.Text = ""
            PreviewContainer.AutoButtonColor = false
            PreviewContainer.ZIndex = 2

            widgets.applyFrameStyle(PreviewContainer, true)
            widgets.UIListLayout(PreviewContainer, Enum.FillDirection.Horizontal, UDim.new(0, 0))
            widgets.UISizeConstraint(PreviewContainer, Vector2.new(frameHeight))

            PreviewContainer.Parent = Combo

            local PreviewLabel = Instance.new("TextLabel")
            PreviewLabel.Name = "PreviewLabel"
            PreviewLabel.AutomaticSize = Enum.AutomaticSize.Y
            PreviewLabel.Size = UDim2.new(UDim.new(1, 0), Axios._config.ContentHeight)
            PreviewLabel.BackgroundColor3 = Axios._config.FrameBgColor
            PreviewLabel.BackgroundTransparency = Axios._config.FrameBgTransparency
            PreviewLabel.BorderSizePixel = 0
            PreviewLabel.ClipsDescendants = true

            widgets.applyTextStyle(PreviewLabel)
            widgets.UIPadding(PreviewLabel, Axios._config.FramePadding)

            PreviewLabel.Parent = PreviewContainer

            local DropdownButton = Instance.new("TextLabel")
            DropdownButton.Name = "DropdownButton"
            DropdownButton.Size = UDim2.new(0, frameHeight, Axios._config.ContentHeight.Scale, math.max(Axios._config.ContentHeight.Offset, frameHeight))
            DropdownButton.BackgroundColor3 = Axios._config.ButtonColor
            DropdownButton.BackgroundTransparency = Axios._config.ButtonTransparency
            DropdownButton.BorderSizePixel = 0
            DropdownButton.Text = ""

            local padding = math.round(frameHeight * 0.2)
            local dropdownSize = frameHeight - 2 * padding

            local Dropdown = Instance.new("ImageLabel")
            Dropdown.Name = "Dropdown"
            Dropdown.AnchorPoint = Vector2.new(0.5, 0.5)
            Dropdown.Size = UDim2.fromOffset(dropdownSize, dropdownSize)
            Dropdown.Position = UDim2.fromScale(0.5, 0.5)
            Dropdown.BackgroundTransparency = 1
            Dropdown.BorderSizePixel = 0
            Dropdown.ImageColor3 = Axios._config.TextColor
            Dropdown.ImageTransparency = Axios._config.TextTransparency

            Dropdown.Parent = DropdownButton

            DropdownButton.Parent = PreviewContainer

            -- for some reason ImGui Combo has no highlights for Active, only hovered.
            -- so this deviates from ImGui, but its a good UX change
            widgets.applyInteractionHighlightsWithMultiHighlightee("Background", PreviewContainer, {
                {
                    PreviewLabel,
                    {
                        Color = Axios._config.FrameBgColor,
                        Transparency = Axios._config.FrameBgTransparency,
                        HoveredColor = Axios._config.FrameBgHoveredColor,
                        HoveredTransparency = Axios._config.FrameBgHoveredTransparency,
                        ActiveColor = Axios._config.FrameBgActiveColor,
                        ActiveTransparency = Axios._config.FrameBgActiveTransparency,
                    },
                },
                {
                    DropdownButton,
                    {
                        Color = Axios._config.ButtonColor,
                        Transparency = Axios._config.ButtonTransparency,
                        HoveredColor = Axios._config.ButtonHoveredColor,
                        HoveredTransparency = Axios._config.ButtonHoveredTransparency,
                        -- Use hovered for active
                        ActiveColor = Axios._config.ButtonHoveredColor,
                        ActiveTransparency = Axios._config.ButtonHoveredTransparency,
                    },
                },
            })

            widgets.applyButtonClick(PreviewContainer, function()
                if AnyOpenedCombo and OpenedCombo ~= thisWidget then
                    return
                end
                thisWidget.state.isOpened:set(not thisWidget.state.isOpened.value)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.X
            TextLabel.Size = UDim2.fromOffset(0, frameHeight)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = Combo

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "ComboContainer"
            ChildContainer.BackgroundColor3 = Axios._config.PopupBgColor
            ChildContainer.BackgroundTransparency = Axios._config.PopupBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Axios._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Axios._config.ScrollbarGrabColor
            ChildContainer.ScrollBarThickness = Axios._config.ScrollbarSize
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            -- appear over everything else
            ChildContainer.ClipsDescendants = true

            -- Unfortunatley, ScrollingFrame does not work with UICorner
            -- if Axios._config.PopupRounding > 0 then
            --     widgets.UICorner(ChildContainer, Axios._config.PopupRounding)
            -- end

            widgets.UIStroke(ChildContainer, Axios._config.WindowBorderSize, Axios._config.BorderColor, Axios._config.BorderTransparency)
            widgets.UIPadding(ChildContainer, Vector2.new(2, Axios._config.WindowPadding.Y))
            widgets.UISizeConstraint(ChildContainer, Vector2.new(100))

            local ChildContainerUIListLayout = widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))
            ChildContainerUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

            local RootPopupScreenGui = Axios._rootInstance and Axios._rootInstance:WaitForChild("PopupScreenGui") :: GuiObject
            ChildContainer.Parent = RootPopupScreenGui

            thisWidget.ChildContainer = ChildContainer
            thisWidget.UIListLayout = ChildContainerUIListLayout
            return Combo
        end,
        GenerateState = function(thisWidget: Types.Combo)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Axios._widgetState(thisWidget, "index", "No Selection")
            end
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Axios._widgetState(thisWidget, "isOpened", false)
            end
            
            thisWidget.state.index:onChange(function()
                thisWidget.lastChangedTick = Axios._cycleTick + 1
                if thisWidget.state.isOpened.value then
                    thisWidget.state.isOpened:set(false)
                end
            end)
        end,
        Update = function(thisWidget: Types.Combo)
            local Axios_Combo = thisWidget.Instance :: Frame
            local PreviewContainer = Axios_Combo.PreviewContainer :: TextButton
            local PreviewLabel: TextLabel = PreviewContainer.PreviewLabel
            local DropdownButton: TextLabel = PreviewContainer.DropdownButton
            local TextLabel: TextLabel = Axios_Combo.TextLabel

            TextLabel.Text = thisWidget.arguments.Text or "Combo"

            if thisWidget.arguments.NoButton then
                DropdownButton.Visible = false
                PreviewLabel.Size = UDim2.new(UDim.new(1, 0), PreviewLabel.Size.Height)
            else
                DropdownButton.Visible = true
                local DropdownButtonSize = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y
                PreviewLabel.Size = UDim2.new(UDim.new(1, -DropdownButtonSize), PreviewLabel.Size.Height)
            end

            if thisWidget.arguments.NoPreview then
                PreviewLabel.Visible = false
                PreviewContainer.Size = UDim2.new(0, 0, 0, 0)
                PreviewContainer.AutomaticSize = Enum.AutomaticSize.XY
            else
                PreviewLabel.Visible = true
                PreviewContainer.Size = UDim2.new(Axios._config.ContentWidth, Axios._config.ContentHeight)
                PreviewContainer.AutomaticSize = Enum.AutomaticSize.Y
            end
        end,
        UpdateState = function(thisWidget: Types.Combo)
            local Combo = thisWidget.Instance :: Frame
            local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame
            local PreviewContainer = Combo.PreviewContainer :: TextButton
            local PreviewLabel: TextLabel = PreviewContainer.PreviewLabel
            local DropdownButton = PreviewContainer.DropdownButton :: TextLabel
            local Dropdown: ImageLabel = DropdownButton.Dropdown

            if thisWidget.state.isOpened.value then
                AnyOpenedCombo = true
                OpenedCombo = thisWidget
                ComboOpenedTick = Axios._cycleTick
                thisWidget.lastOpenedTick = Axios._cycleTick + 1

                -- ImGui also does not do this, and the Arrow is always facing down
                Dropdown.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE
                ChildContainer.Visible = true

                UpdateChildContainerTransform(thisWidget)
            else
                if AnyOpenedCombo then
                    AnyOpenedCombo = false
                    OpenedCombo = nil
                    thisWidget.lastClosedTick = Axios._cycleTick + 1
                end
                Dropdown.Image = widgets.ICONS.DOWN_POINTING_TRIANGLE
                ChildContainer.Visible = false
            end

            local stateIndex = thisWidget.state.index.value
            PreviewLabel.Text = if typeof(stateIndex) == "EnumItem" then stateIndex.Name else tostring(stateIndex)
        end,
        ChildAdded = function(thisWidget: Types.Combo, _thisChild: Types.Widget)
            UpdateChildContainerTransform(thisWidget)
            return thisWidget.ChildContainer
        end,
        Discard = function(thisWidget: Types.Combo)
            -- If we are discarding the current combo active, we need to hide it
            if OpenedCombo and OpenedCombo == thisWidget then
                OpenedCombo = nil
                AnyOpenedCombo = false
            end

            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Format"] = function()
    local script = create_mock_script("Axios.widgets.Format")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    --stylua: ignore
    Axios.WidgetConstructor("Separator", {
        hasState = false,
        hasChildren = false,
        Args = {},
        Events = {},
        Generate = function(thisWidget: Types.Separator)
            local Separator = Instance.new("Frame")
            Separator.Name = "Axios_Separator"
            if thisWidget.parentWidget.type == "SameLine" then
                Separator.Size = UDim2.new(0, 1, Axios._config.ItemWidth.Scale, Axios._config.ItemWidth.Offset)
            else
                Separator.Size = UDim2.new(Axios._config.ItemWidth.Scale, Axios._config.ItemWidth.Offset, 0, 1)
            end
            Separator.BackgroundColor3 = Axios._config.SeparatorColor
            Separator.BackgroundTransparency = Axios._config.SeparatorTransparency
            Separator.BorderSizePixel = 0

            widgets.UIListLayout(Separator, Enum.FillDirection.Vertical, UDim.new(0, 0))
            -- this is to prevent a bug of AutomaticLayout edge case when its parent has automaticLayout enabled

            return Separator
        end,
        Update = function(_thisWidget: Types.Separator) end,
        Discard = function(thisWidget: Types.Separator)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("Indent", {
        hasState = false,
        hasChildren = true,
        Args = {
            ["Width"] = 1,
        },
        Events = {},
        Generate = function(_thisWidget: Types.Indent)
            local Indent = Instance.new("Frame")
            Indent.Name = "Axios_Indent"
            Indent.AutomaticSize = Enum.AutomaticSize.Y
            Indent.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            Indent.BackgroundTransparency = 1
            Indent.BorderSizePixel = 0

            widgets.UIListLayout(Indent, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))
            widgets.UIPadding(Indent, Vector2.zero)

            return Indent
        end,
        Update = function(thisWidget: Types.Indent)
            local Indent = thisWidget.Instance :: Frame

            Indent.UIPadding.PaddingLeft = UDim.new(0, if thisWidget.arguments.Width then thisWidget.arguments.Width else Axios._config.IndentSpacing)
        end,
        ChildAdded = function(thisWidget: Types.Indent, _thisChild: Types.Widget)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget: Types.Indent)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("SameLine", {
        hasState = false,
        hasChildren = true,
        Args = {
            ["Width"] = 1,
            ["VerticalAlignment"] = 2,
            ["HorizontalAlignment"] = 3,
        },
        Events = {},
        Generate = function(_thisWidget: Types.SameLine)
            local SameLine = Instance.new("Frame")
            SameLine.Name = "Axios_SameLine"
            SameLine.AutomaticSize = Enum.AutomaticSize.Y
            SameLine.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            SameLine.BackgroundTransparency = 1
            SameLine.BorderSizePixel = 0

            widgets.UIListLayout(SameLine, Enum.FillDirection.Horizontal, UDim.new(0, 0))

            return SameLine
        end,
        Update = function(thisWidget: Types.SameLine)
            local Sameline = thisWidget.Instance :: Frame
            local UIListLayout: UIListLayout = Sameline.UIListLayout

            UIListLayout.Padding = UDim.new(0, if thisWidget.arguments.Width then thisWidget.arguments.Width else Axios._config.ItemSpacing.X)
            if thisWidget.arguments.VerticalAlignment then
                UIListLayout.VerticalAlignment = thisWidget.arguments.VerticalAlignment
            else
                UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
            end
            if thisWidget.arguments.HorizontalAlignment then
                UIListLayout.HorizontalAlignment = thisWidget.arguments.HorizontalAlignment
            else
                UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            end
        end,
        ChildAdded = function(thisWidget: Types.SameLine, _thisChild: Types.Widget)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget: Types.SameLine)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("Group", {
        hasState = false,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(_thisWidget: Types.Group)
            local Group = Instance.new("Frame")
            Group.Name = "Axios_Group"
            Group.AutomaticSize = Enum.AutomaticSize.XY
            Group.Size = UDim2.fromOffset(0, 0)
            Group.BackgroundTransparency = 1
            Group.BorderSizePixel = 0
            Group.ClipsDescendants = false

            widgets.UIListLayout(Group, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))

            return Group
        end,
        Update = function(_thisWidget: Types.Group) end,
        ChildAdded = function(thisWidget: Types.Group, _thisChild: Types.Widget)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget: Types.Group)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Image"] = function()
    local script = create_mock_script("Axios.widgets.Image")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local abstractImage = {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Image"] = 1,
            ["Size"] = 2,
            ["Rect"] = 3,
            ["ScaleType"] = 4,
            ["ResampleMode"] = 5,
            ["TileSize"] = 6,
            ["SliceCenter"] = 7,
            ["SliceScale"] = 8,
        },
        Discard = function(thisWidget: Types.Image)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass

    --stylua: ignore
    Axios.WidgetConstructor("Image", widgets.extend(abstractImage, {
            Events = {
                ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
            },
            Generate = function(_thisWidget: Types.Image)
                local Image = Instance.new("ImageLabel")
                Image.Name = "Axios_Image"
                Image.BackgroundTransparency = 1
                Image.BorderSizePixel = 0
                Image.ImageColor3 = Axios._config.ImageColor
                Image.ImageTransparency = Axios._config.ImageTransparency

                widgets.applyFrameStyle(Image, true)

                return Image
            end,
            Update = function(thisWidget: Types.Image)
                local Image = thisWidget.Instance :: ImageLabel
    
                Image.Image = thisWidget.arguments.Image or widgets.ICONS.UNKNOWN_TEXTURE
                Image.Size = thisWidget.arguments.Size
                if thisWidget.arguments.ScaleType then
                    Image.ScaleType = thisWidget.arguments.ScaleType
                    if thisWidget.arguments.ScaleType == Enum.ScaleType.Tile and thisWidget.arguments.TileSize then
                        Image.TileSize = thisWidget.arguments.TileSize
                    elseif thisWidget.arguments.ScaleType == Enum.ScaleType.Slice then
                        if thisWidget.arguments.SliceCenter then
                            Image.SliceCenter = thisWidget.arguments.SliceCenter
                        end
                        if thisWidget.arguments.SliceScale then
                            Image.SliceScale = thisWidget.arguments.SliceScale
                        end
                    end
                end
    
                if thisWidget.arguments.Rect then
                    Image.ImageRectOffset = thisWidget.arguments.Rect.Min
                    Image.ImageRectSize = Vector2.new(thisWidget.arguments.Rect.Width, thisWidget.arguments.Rect.Height)
                end
    
                if thisWidget.arguments.ResampleMode then
                    Image.ResampleMode = thisWidget.arguments.ResampleMode
                end
            end,
        } :: Types.WidgetClass)
    )

    --stylua: ignore
    Axios.WidgetConstructor("ImageButton", widgets.extend(abstractImage, {
            Events = {
                ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
                ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
                ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
                ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
                ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
            },
            Generate = function(_thisWidget: Types.ImageButton)
                local Button = Instance.new("ImageButton")
                Button.Name = "Axios_ImageButton"
                Button.AutomaticSize = Enum.AutomaticSize.XY
                Button.BackgroundColor3 = Axios._config.FrameBgColor
                Button.BackgroundTransparency = Axios._config.FrameBgTransparency
                Button.BorderSizePixel = 0
                Button.Image = ""
                Button.ImageTransparency = 1
                Button.AutoButtonColor = false
                
                widgets.applyFrameStyle(Button, true)
                widgets.UIPadding(Button, Vector2.new(Axios._config.ImageBorderSize, Axios._config.ImageBorderSize))
                
                local Image = Instance.new("ImageLabel")
                Image.Name = "ImageLabel"
                Image.BackgroundTransparency = 1
                Image.BorderSizePixel = 0
                Image.ImageColor3 = Axios._config.ImageColor
                Image.ImageTransparency = Axios._config.ImageTransparency
                Image.Parent = Button

                widgets.applyInteractionHighlights("Background", Button, Button, {
                    Color = Axios._config.FrameBgColor,
                    Transparency = Axios._config.FrameBgTransparency,
                    HoveredColor = Axios._config.FrameBgHoveredColor,
                    HoveredTransparency = Axios._config.FrameBgHoveredTransparency,
                    ActiveColor = Axios._config.FrameBgActiveColor,
                    ActiveTransparency = Axios._config.FrameBgActiveTransparency,
                })

                return Button
            end,
            Update = function(thisWidget: Types.ImageButton)
                local Button = thisWidget.Instance :: TextButton
                local Image: ImageLabel = Button.ImageLabel
    
                Image.Image = thisWidget.arguments.Image or widgets.ICONS.UNKNOWN_TEXTURE
                Image.Size = thisWidget.arguments.Size
                if thisWidget.arguments.ScaleType then
                    Image.ScaleType = thisWidget.arguments.ScaleType
                    if thisWidget.arguments.ScaleType == Enum.ScaleType.Tile and thisWidget.arguments.TileSize then
                        Image.TileSize = thisWidget.arguments.TileSize
                    elseif thisWidget.arguments.ScaleType == Enum.ScaleType.Slice then
                        if thisWidget.arguments.SliceCenter then
                            Image.SliceCenter = thisWidget.arguments.SliceCenter
                        end
                        if thisWidget.arguments.SliceScale then
                            Image.SliceScale = thisWidget.arguments.SliceScale
                        end
                    end
                end
    
                if thisWidget.arguments.Rect then
                    Image.ImageRectOffset = thisWidget.arguments.Rect.Min
                    Image.ImageRectSize = Vector2.new(thisWidget.arguments.Rect.Width, thisWidget.arguments.Rect.Height)
                end
    
                if thisWidget.arguments.ResampleMode then
                    Image.ResampleMode = thisWidget.arguments.ResampleMode
                end
            end,
        } :: Types.WidgetClass)
    )
end

end

_modules["Axios.widgets.Input"] = function()
    local script = create_mock_script("Axios.widgets.Input")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

type InputDataTypes = "Num" | "Vector2" | "Vector3" | "UDim" | "UDim2" | "Color3" | "Color4" | "Rect" | "Enum" | "" | string
type InputType = "Input" | "Drag" | "Slider"

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local numberChanged = {
        ["Init"] = function(_thisWidget: Types.Widget) end,
        ["Get"] = function(thisWidget: Types.Input<any>)
            return thisWidget.lastNumberChangedTick == Axios._cycleTick
        end,
    }

    local function getValueByIndex<T>(value: T, index: number, arguments: Types.Arguments)
        local val = value :: unknown
        if typeof(val) == "number" then
            return val
        elseif typeof(val) == "Vector2" then
            if index == 1 then
                return val.X
            elseif index == 2 then
                return val.Y
            end
        elseif typeof(val) == "Vector3" then
            if index == 1 then
                return val.X
            elseif index == 2 then
                return val.Y
            elseif index == 3 then
                return val.Z
            end
        elseif typeof(val) == "UDim" then
            if index == 1 then
                return val.Scale
            elseif index == 2 then
                return val.Offset
            end
        elseif typeof(val) == "UDim2" then
            if index == 1 then
                return val.X.Scale
            elseif index == 2 then
                return val.X.Offset
            elseif index == 3 then
                return val.Y.Scale
            elseif index == 4 then
                return val.Y.Offset
            end
        elseif typeof(val) == "Color3" then
            local color = if arguments.UseHSV then { val:ToHSV() } else { val.R, val.G, val.B }
            if index == 1 then
                return color[1]
            elseif index == 2 then
                return color[2]
            elseif index == 3 then
                return color[3]
            end
        elseif typeof(val) == "Rect" then
            if index == 1 then
                return val.Min.X
            elseif index == 2 then
                return val.Min.Y
            elseif index == 3 then
                return val.Max.X
            elseif index == 4 then
                return val.Max.Y
            end
        elseif typeof(val) == "table" then
            return val[index]
        end

        error(`Incorrect datatype or value: {value} {typeof(value)} {index}.`)
    end

    local function updateValueByIndex<T>(value: T, index: number, newValue: number, arguments: Types.Arguments): T
        local val = value :: unknown
        if typeof(val) == "number" then
            return newValue :: any
        elseif typeof(val) == "Vector2" then
            if index == 1 then
                return Vector2.new(newValue, val.Y) :: any
            elseif index == 2 then
                return Vector2.new(val.X, newValue) :: any
            end
        elseif typeof(val) == "Vector3" then
            if index == 1 then
                return Vector3.new(newValue, val.Y, val.Z) :: any
            elseif index == 2 then
                return Vector3.new(val.X, newValue, val.Z) :: any
            elseif index == 3 then
                return Vector3.new(val.X, val.Y, newValue) :: any
            end
        elseif typeof(val) == "UDim" then
            if index == 1 then
                return UDim.new(newValue, val.Offset) :: any
            elseif index == 2 then
                return UDim.new(val.Scale, newValue) :: any
            end
        elseif typeof(val) == "UDim2" then
            if index == 1 then
                return UDim2.new(UDim.new(newValue, val.X.Offset), val.Y) :: any
            elseif index == 2 then
                return UDim2.new(UDim.new(val.X.Scale, newValue), val.Y) :: any
            elseif index == 3 then
                return UDim2.new(val.X, UDim.new(newValue, val.Y.Offset)) :: any
            elseif index == 4 then
                return UDim2.new(val.X, UDim.new(val.Y.Scale, newValue)) :: any
            end
        elseif typeof(val) == "Rect" then
            if index == 1 then
                return Rect.new(Vector2.new(newValue, val.Min.Y), val.Max) :: any
            elseif index == 2 then
                return Rect.new(Vector2.new(val.Min.X, newValue), val.Max) :: any
            elseif index == 3 then
                return Rect.new(val.Min, Vector2.new(newValue, val.Max.Y)) :: any
            elseif index == 4 then
                return Rect.new(val.Min, Vector2.new(val.Max.X, newValue)) :: any
            end
        elseif typeof(val) == "Color3" then
            if arguments.UseHSV then
                local h: number, s: number, v: number = val:ToHSV()
                if index == 1 then
                    return Color3.fromHSV(newValue, s, v) :: any
                elseif index == 2 then
                    return Color3.fromHSV(h, newValue, v) :: any
                elseif index == 3 then
                    return Color3.fromHSV(h, s, newValue) :: any
                end
            end
            if index == 1 then
                return Color3.new(newValue, val.G, val.B) :: any
            elseif index == 2 then
                return Color3.new(val.R, newValue, val.B) :: any
            elseif index == 3 then
                return Color3.new(val.R, val.G, newValue) :: any
            end
        end

        error(`Incorrect datatype or value {value} {typeof(value)} {index}.`)
    end

    local defaultIncrements: { [InputDataTypes]: { number } } = {
        Num = { 1 },
        Vector2 = { 1, 1 },
        Vector3 = { 1, 1, 1 },
        UDim = { 0.01, 1 },
        UDim2 = { 0.01, 1, 0.01, 1 },
        Color3 = { 1, 1, 1 },
        Color4 = { 1, 1, 1, 1 },
        Rect = { 1, 1, 1, 1 },
    }

    local defaultMin: { [InputDataTypes]: { number } } = {
        Num = { 0 },
        Vector2 = { 0, 0 },
        Vector3 = { 0, 0, 0 },
        UDim = { 0, 0 },
        UDim2 = { 0, 0, 0, 0 },
        Rect = { 0, 0, 0, 0 },
    }

    local defaultMax: { [InputDataTypes]: { number } } = {
        Num = { 100 },
        Vector2 = { 100, 100 },
        Vector3 = { 100, 100, 100 },
        UDim = { 1, 960 },
        UDim2 = { 1, 960, 1, 960 },
        Rect = { 960, 960, 960, 960 },
    }

    local defaultPrefx: { [InputDataTypes]: { string } } = {
        Num = { "" },
        Vector2 = { "X: ", "Y: " },
        Vector3 = { "X: ", "Y: ", "Z: " },
        UDim = { "", "" },
        UDim2 = { "", "", "", "" },
        Color3_RGB = { "R: ", "G: ", "B: " },
        Color3_HSV = { "H: ", "S: ", "V: " },
        Color4_RGB = { "R: ", "G: ", "B: ", "T: " },
        Color4_HSV = { "H: ", "S: ", "V: ", "T: " },
        Rect = { "X: ", "Y: ", "X: ", "Y: " },
    }

    local defaultSigFigs: { [InputDataTypes]: { number } } = {
        Num = { 0 },
        Vector2 = { 0, 0 },
        Vector3 = { 0, 0, 0 },
        UDim = { 3, 0 },
        UDim2 = { 3, 0, 3, 0 },
        Color3 = { 0, 0, 0 },
        Color4 = { 0, 0, 0, 0 },
        Rect = { 0, 0, 0, 0 },
    }

    local function generateAbstract<T>(inputType: InputType, dataType: InputDataTypes, components: number, defaultValue: T): Types.WidgetClass
        return {
            hasState = true,
            hasChildren = false,
            Args = {
                ["Text"] = 1,
                ["Increment"] = 2,
                ["Min"] = 3,
                ["Max"] = 4,
                ["Format"] = 5,
            },
            Events = {
                ["numberChanged"] = numberChanged,
                ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                    return thisWidget.Instance
                end),
            },
            GenerateState = function(thisWidget: Types.Input<T>)
                if thisWidget.state.number == nil then
                    thisWidget.state.number = Axios._widgetState(thisWidget, "number", defaultValue)
                end
                if thisWidget.state.editingText == nil then
                    thisWidget.state.editingText = Axios._widgetState(thisWidget, "editingText", 0)
                end
            end,
            Update = function(thisWidget: Types.Input<T>)
                local Input = thisWidget.Instance :: GuiObject
                local TextLabel: TextLabel = Input.TextLabel
                TextLabel.Text = thisWidget.arguments.Text or `Input {dataType}`

                if thisWidget.arguments.Format and typeof(thisWidget.arguments.Format) ~= "table" then
                    thisWidget.arguments.Format = { thisWidget.arguments.Format }
                elseif not thisWidget.arguments.Format then
                    -- we calculate the format for the s.f. using the max, min and increment arguments.
                    local format = {}
                    for index = 1, components do
                        local sigfigs = defaultSigFigs[dataType][index]

                        if thisWidget.arguments.Increment then
                            local value = getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
                            sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
                        end

                        if thisWidget.arguments.Max then
                            local value = getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any)
                            sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
                        end

                        if thisWidget.arguments.Min then
                            local value = getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any)
                            sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
                        end

                        if sigfigs > 0 then
                            -- we know it's a float.
                            format[index] = `%.{sigfigs}f`
                        else
                            format[index] = "%d"
                        end
                    end

                    thisWidget.arguments.Format = format
                    thisWidget.arguments.Prefix = defaultPrefx[dataType]
                end

                if inputType == "Input" and dataType == "Num" then
                    Input.SubButton.Visible = not thisWidget.arguments.NoButtons
                    Input.AddButton.Visible = not thisWidget.arguments.NoButtons
                    local InputField: TextBox = Input.InputField1
                    local rightPadding = if thisWidget.arguments.NoButtons then 0 else (2 * Axios._config.ItemInnerSpacing.X) + (2 * (Axios._config.TextSize + 2 * Axios._config.FramePadding.Y))
                    InputField.Size = UDim2.new(UDim.new(Axios._config.ContentWidth.Scale, Axios._config.ContentWidth.Offset - rightPadding), Axios._config.ContentHeight)
                end

                if inputType == "Slider" then
                    for index = 1, components do
                        local SliderField = Input:FindFirstChild("SliderField" .. tostring(index)) :: TextButton
                        local GrabBar: Frame = SliderField.GrabBar

                        local increment = thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any) or defaultIncrements[dataType][index]
                        local min = thisWidget.arguments.Min and getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any) or defaultMin[dataType][index]
                        local max = thisWidget.arguments.Max and getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any) or defaultMax[dataType][index]

                        local grabScaleSize = 1 / math.floor((1 + max - min) / increment)

                        GrabBar.Size = UDim2.fromScale(grabScaleSize, 1)
                    end

                    local callbackIndex = #Axios._postCycleCallbacks + 1
                    local desiredCycleTick = Axios._cycleTick + 1
                    Axios._postCycleCallbacks[callbackIndex] = function()
                        if Axios._cycleTick >= desiredCycleTick then
                            if thisWidget.lastCycleTick ~= -1 then
                                thisWidget.state.number.lastChangeTick = Axios._cycleTick
                                Axios._widgets[`Slider{dataType}`].UpdateState(thisWidget)
                            end
                            Axios._postCycleCallbacks[callbackIndex] = nil
                        end
                    end
                end
            end,
            Discard = function(thisWidget: Types.Input<T>)
                thisWidget.Instance:Destroy()
                widgets.discardState(thisWidget)
            end,
        } :: Types.WidgetClass
    end

    local function focusLost<T>(thisWidget: Types.Input<T>, InputField: TextBox, index: number, dataType: InputDataTypes)
        local newValue = tonumber(InputField.Text:match("-?%d*%.?%d*"))
        local state = thisWidget.state.number
        local widget = thisWidget
        if dataType == "Color4" and index == 4 then
            state = widget.state.transparency
        elseif dataType == "Color3" or dataType == "Color4" then
            state = widget.state.color
        end
        if newValue ~= nil then
            if dataType == "Color3" or dataType == "Color4" and not widget.arguments.UseFloats then
                newValue = newValue / 255
            end
            if thisWidget.arguments.Min ~= nil then
                newValue = math.max(newValue, getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any))
            end
            if thisWidget.arguments.Max ~= nil then
                newValue = math.min(newValue, getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any))
            end

            if thisWidget.arguments.Increment then
                newValue = math.round(newValue / getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)) * getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
            end

            state:set(updateValueByIndex(state.value, index, newValue, thisWidget.arguments :: any))
            thisWidget.lastNumberChangedTick = Axios._cycleTick + 1
        end

        local value = getValueByIndex(state.value, index, thisWidget.arguments :: any)
        if dataType == "Color3" or dataType == "Color4" and not widget.arguments.UseFloats then
            value = math.round(value * 255)
        end

        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
        if thisWidget.arguments.Prefix then
            format = thisWidget.arguments.Prefix[index] .. format
        end
        InputField.Text = string.format(format, value)

        thisWidget.state.editingText:set(0)
        InputField:ReleaseFocus(true)
    end

    --[[
        Input
    ]]
    local generateInputScalar: <T>(dataType: InputDataTypes, components: number, defaultValue: T) -> Types.WidgetClass
    do
        local function generateButtons(thisWidget: Types.Input<number>, parent: GuiObject, textHeight: number)
            local SubButton = widgets.abstractButton.Generate(thisWidget) :: TextButton
            SubButton.Name = "SubButton"
            SubButton.Size = UDim2.fromOffset(Axios._config.TextSize + 2 * Axios._config.FramePadding.Y, Axios._config.TextSize)
            SubButton.Text = "-"
            SubButton.TextXAlignment = Enum.TextXAlignment.Center
            SubButton.ZIndex = 5
            SubButton.LayoutOrder = 5
            SubButton.Parent = parent

            widgets.applyButtonClick(SubButton, function()
                local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                local changeValue = (thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, 1, thisWidget.arguments :: Types.Argument) or 1) * (isCtrlHeld and 100 or 1)
                local newValue = thisWidget.state.number.value - changeValue
                if thisWidget.arguments.Min ~= nil then
                    newValue = math.max(newValue, getValueByIndex(thisWidget.arguments.Min, 1, thisWidget.arguments :: Types.Argument))
                end
                if thisWidget.arguments.Max ~= nil then
                    newValue = math.min(newValue, getValueByIndex(thisWidget.arguments.Max, 1, thisWidget.arguments :: Types.Argument))
                end
                thisWidget.state.number:set(newValue)
                thisWidget.lastNumberChangedTick = Axios._cycleTick + 1
            end)

            local AddButton = widgets.abstractButton.Generate(thisWidget) :: TextButton
            AddButton.Name = "AddButton"
            AddButton.Size = UDim2.fromOffset(Axios._config.TextSize + 2 * Axios._config.FramePadding.Y, Axios._config.TextSize)
            AddButton.Text = "+"
            AddButton.TextXAlignment = Enum.TextXAlignment.Center
            AddButton.ZIndex = 6
            AddButton.LayoutOrder = 6
            AddButton.Parent = parent

            widgets.applyButtonClick(AddButton, function()
                local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                local changeValue = (thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, 1, thisWidget.arguments :: Types.Argument) or 1) * (isCtrlHeld and 100 or 1)
                local newValue = thisWidget.state.number.value + changeValue
                if thisWidget.arguments.Min ~= nil then
                    newValue = math.max(newValue, getValueByIndex(thisWidget.arguments.Min, 1, thisWidget.arguments :: Types.Argument))
                end
                if thisWidget.arguments.Max ~= nil then
                    newValue = math.min(newValue, getValueByIndex(thisWidget.arguments.Max, 1, thisWidget.arguments :: Types.Argument))
                end
                thisWidget.state.number:set(newValue)
                thisWidget.lastNumberChangedTick = Axios._cycleTick + 1
            end)

            return 2 * Axios._config.ItemInnerSpacing.X + 2 * textHeight
        end

        local function generateField<T>(thisWidget: Types.Input<T>, index: number, componentWidth: UDim, dataType: InputDataTypes)
            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField" .. tostring(index)
            InputField.AutomaticSize = Enum.AutomaticSize.Y
            InputField.Size = UDim2.new(componentWidth, Axios._config.ContentHeight)
            InputField.BackgroundColor3 = Axios._config.FrameBgColor
            InputField.BackgroundTransparency = Axios._config.FrameBgTransparency
            InputField.TextTruncate = Enum.TextTruncate.AtEnd
            InputField.ClearTextOnFocus = false
            InputField.ZIndex = index
            InputField.LayoutOrder = index
            InputField.ClipsDescendants = true

            widgets.applyFrameStyle(InputField)
            widgets.applyTextStyle(InputField)
            widgets.UISizeConstraint(InputField, Vector2.xAxis)

            InputField.FocusLost:Connect(function()
                focusLost(thisWidget, InputField, index, dataType)
            end)

            InputField.Focused:Connect(function()
                -- this highlights the entire field
                InputField.CursorPosition = #InputField.Text + 1
                InputField.SelectionStart = 1

                thisWidget.state.editingText:set(index)
            end)

            return InputField
        end

        function generateInputScalar<T>(dataType: InputDataTypes, components: number, defaultValue: T)
            local input = generateAbstract("Input", dataType, components, defaultValue)

            return widgets.extend(input, {
                Generate = function(thisWidget: Types.Input<T>)
                    local Input = Instance.new("Frame")
                    Input.Name = "Axios_Input" .. dataType
                    Input.AutomaticSize = Enum.AutomaticSize.Y
                    Input.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
                    Input.BackgroundTransparency = 1
                    Input.BorderSizePixel = 0

                    widgets.UIListLayout(Input, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                    -- we add plus and minus buttons if there is only one box. This can be disabled through the argument.
                    local rightPadding = 0
                    local textHeight = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y

                    if components == 1 then
                        rightPadding = generateButtons(thisWidget :: any, Input, textHeight)
                    end

                    -- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
                    -- for the final field, we make sure it's flush by calculating the space avaiable for it. This only makes the Vector2 box
                    -- 4 pixels shorter, all for the sake of flush.
                    local componentWidth = UDim.new(Axios._config.ContentWidth.Scale / components, (Axios._config.ContentWidth.Offset - (Axios._config.ItemInnerSpacing.X * (components - 1)) - rightPadding) / components)
                    local totalWidth = UDim.new(componentWidth.Scale * (components - 1), (componentWidth.Offset * (components - 1)) + (Axios._config.ItemInnerSpacing.X * (components - 1)) + rightPadding)
                    local lastComponentWidth = Axios._config.ContentWidth - totalWidth

                    -- we handle each component individually since they don't need to interact with each other.
                    for index = 1, components do
                        generateField(thisWidget, index, if index == components then lastComponentWidth else componentWidth, dataType).Parent = Input
                    end

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Name = "TextLabel"
                    TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.BorderSizePixel = 0
                    TextLabel.LayoutOrder = 7

                    widgets.applyTextStyle(TextLabel)

                    TextLabel.Parent = Input

                    return Input
                end,
                UpdateState = function(thisWidget: Types.Input<T>)
                    local Input = thisWidget.Instance :: GuiObject

                    for index = 1, components do
                        local InputField: TextBox = Input:FindFirstChild("InputField" .. tostring(index))
                        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
                        if thisWidget.arguments.Prefix then
                            format = thisWidget.arguments.Prefix[index] .. format
                        end
                        InputField.Text = string.format(format, getValueByIndex(thisWidget.state.number.value, index, thisWidget.arguments :: any))
                    end
                end,
            })
        end
    end

    --[[
        Drag
    ]]
    local generateDragScalar: <T>(dataType: InputDataTypes, components: number, defaultValue: T) -> Types.WidgetClass
    local generateColorDragScalar: (dataType: InputDataTypes, ...any) -> Types.WidgetClass
    do
        local PreviouseMouseXPosition = 0
        local AnyActiveDrag = false
        local ActiveDrag: Types.Input<Types.InputDataType>? = nil
        local ActiveIndex = 0
        local ActiveDataType: InputDataTypes | "" = ""

        local function updateActiveDrag()
            local currentMouseX = widgets.getMouseLocation().X
            local mouseXDelta = currentMouseX - PreviouseMouseXPosition
            PreviouseMouseXPosition = currentMouseX
            if AnyActiveDrag == false then
                return
            end
            if ActiveDrag == nil then
                return
            end

            local state = ActiveDrag.state.number
            if ActiveDataType == "Color3" or ActiveDataType == "Color4" then
                local Drag = ActiveDrag
                state = Drag.state.color
                if ActiveIndex == 4 then
                    state = Drag.state.transparency
                end
            end

            local increment = ActiveDrag.arguments.Increment and getValueByIndex(ActiveDrag.arguments.Increment, ActiveIndex, ActiveDrag.arguments :: any) or defaultIncrements[ActiveDataType][ActiveIndex]
            increment *= (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) and 10 or 1
            increment *= (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)) and 0.1 or 1
            -- we increase the speed for Color3 and Color4 since it's too slow because the increment argument needs to be low.
            increment *= (ActiveDataType == "Color3" or ActiveDataType == "Color4") and 5 or 1

            local value = getValueByIndex(state.value, ActiveIndex, ActiveDrag.arguments :: any)
            local newValue = value + (mouseXDelta * increment)

            if ActiveDrag.arguments.Min ~= nil then
                newValue = math.max(newValue, getValueByIndex(ActiveDrag.arguments.Min, ActiveIndex, ActiveDrag.arguments :: any))
            end
            if ActiveDrag.arguments.Max ~= nil then
                newValue = math.min(newValue, getValueByIndex(ActiveDrag.arguments.Max, ActiveIndex, ActiveDrag.arguments :: any))
            end

            state:set(updateValueByIndex(state.value, ActiveIndex, newValue, ActiveDrag.arguments :: any))
            ActiveDrag.lastNumberChangedTick = Axios._cycleTick + 1
        end

        local function DragMouseDown(thisWidget: Types.Input<Types.InputDataType>, dataTypes: InputDataTypes, index: number, x: number, y: number)
            local currentTime = widgets.getTime()
            local isTimeValid = currentTime - thisWidget.lastClickedTime < Axios._config.MouseDoubleClickTime
            local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if (isTimeValid and (Vector2.new(x, y) - thisWidget.lastClickedPosition).Magnitude < Axios._config.MouseDoubleClickMaxDist) or isCtrlHeld then
                thisWidget.state.editingText:set(index)
            else
                thisWidget.lastClickedTime = currentTime
                thisWidget.lastClickedPosition = Vector2.new(x, y)

                AnyActiveDrag = true
                ActiveDrag = thisWidget
                ActiveIndex = index
                ActiveDataType = dataTypes
                updateActiveDrag()
            end
        end

        widgets.registerEvent("InputChanged", function()
            if not Axios._started then
                return
            end
            updateActiveDrag()
        end)

        widgets.registerEvent("InputEnded", function(inputObject: InputObject)
            if not Axios._started then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveDrag then
                AnyActiveDrag = false
                ActiveDrag = nil
                ActiveIndex = 0
            end
        end)

        local function generateField<T>(thisWidget: Types.Input<T>, index: number, componentSize: UDim2, dataType: InputDataTypes)
            local DragField = Instance.new("TextButton")
            DragField.Name = "DragField" .. tostring(index)
            DragField.AutomaticSize = Enum.AutomaticSize.Y
            DragField.Size = componentSize
            DragField.BackgroundColor3 = Axios._config.FrameBgColor
            DragField.BackgroundTransparency = Axios._config.FrameBgTransparency
            DragField.Text = ""
            DragField.AutoButtonColor = false
            DragField.LayoutOrder = index
            DragField.ClipsDescendants = true

            widgets.applyFrameStyle(DragField)
            widgets.applyTextStyle(DragField)
            widgets.UISizeConstraint(DragField, Vector2.xAxis)

            DragField.TextXAlignment = Enum.TextXAlignment.Center

            widgets.applyInteractionHighlights("Background", DragField, DragField, {
                Color = Axios._config.FrameBgColor,
                Transparency = Axios._config.FrameBgTransparency,
                HoveredColor = Axios._config.FrameBgHoveredColor,
                HoveredTransparency = Axios._config.FrameBgHoveredTransparency,
                ActiveColor = Axios._config.FrameBgActiveColor,
                ActiveTransparency = Axios._config.FrameBgActiveTransparency,
            })

            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.Size = UDim2.fromScale(1, 1)
            InputField.BackgroundTransparency = 1
            InputField.ClearTextOnFocus = false
            InputField.TextTruncate = Enum.TextTruncate.AtEnd
            InputField.ClipsDescendants = true
            InputField.Visible = false

            widgets.applyFrameStyle(InputField, true)
            widgets.applyTextStyle(InputField)

            InputField.Parent = DragField

            InputField.FocusLost:Connect(function()
                focusLost(thisWidget, InputField, index, dataType)
            end)

            InputField.Focused:Connect(function()
                -- this highlights the entire field
                InputField.CursorPosition = #InputField.Text + 1
                InputField.SelectionStart = 1

                thisWidget.state.editingText:set(index)
            end)

            widgets.applyButtonDown(DragField, function(x: number, y: number)
                DragMouseDown(thisWidget :: any, dataType, index, x, y)
            end)

            return DragField
        end

        function generateDragScalar<T>(dataType: InputDataTypes, components: number, defaultValue: T)
            local input = generateAbstract("Drag", dataType, components, defaultValue)

            return widgets.extend(input, {
                Generate = function(thisWidget: Types.Input<T>)
                    thisWidget.lastClickedTime = -1
                    thisWidget.lastClickedPosition = Vector2.zero

                    local Drag = Instance.new("Frame")
                    Drag.Name = "Axios_Drag" .. dataType
                    Drag.AutomaticSize = Enum.AutomaticSize.Y
                    Drag.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
                    Drag.BackgroundTransparency = 1
                    Drag.BorderSizePixel = 0

                    widgets.UIListLayout(Drag, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                    -- we add a color box if it is Color3 or Color4.
                    local rightPadding = 0
                    local textHeight = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y

                    if dataType == "Color3" or dataType == "Color4" then
                        rightPadding += Axios._config.ItemInnerSpacing.X + textHeight

                        local ColorBox = Instance.new("ImageLabel")
                        ColorBox.Name = "ColorBox"
                        ColorBox.Size = UDim2.fromOffset(textHeight, textHeight)
                        ColorBox.BorderSizePixel = 0
                        ColorBox.Image = widgets.ICONS.ALPHA_BACKGROUND_TEXTURE
                        ColorBox.ImageTransparency = 1
                        ColorBox.LayoutOrder = 5

                        widgets.applyFrameStyle(ColorBox, true)

                        ColorBox.Parent = Drag
                    end

                    -- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
                    -- for the final field, we make sure it's flush by calculating the space avaiable for it. This only makes the Vector2 box
                    -- 4 pixels shorter, all for the sake of flush.
                    local componentWidth = UDim.new(Axios._config.ContentWidth.Scale / components, (Axios._config.ContentWidth.Offset - (Axios._config.ItemInnerSpacing.X * (components - 1)) - rightPadding) / components)
                    local totalWidth = UDim.new(componentWidth.Scale * (components - 1), (componentWidth.Offset * (components - 1)) + (Axios._config.ItemInnerSpacing.X * (components - 1)) + rightPadding)
                    local lastComponentWidth = Axios._config.ContentWidth - totalWidth

                    for index = 1, components do
                        generateField(thisWidget, index, if index == components then UDim2.new(lastComponentWidth, Axios._config.ContentHeight) else UDim2.new(componentWidth, Axios._config.ContentHeight), dataType).Parent = Drag
                    end

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Name = "TextLabel"
                    TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.BorderSizePixel = 0
                    TextLabel.LayoutOrder = 6

                    widgets.applyTextStyle(TextLabel)

                    TextLabel.Parent = Drag

                    return Drag
                end,
                UpdateState = function(thisWidget: Types.Input<T>)
                    local Drag = thisWidget.Instance :: Frame

                    local widget = thisWidget :: any
                    for index = 1, components do
                        local state = thisWidget.state.number
                        if dataType == "Color3" or dataType == "Color4" then
                            state = widget.state.color
                            if index == 4 then
                                state = widget.state.transparency
                            end
                        end
                        local DragField = Drag:FindFirstChild("DragField" .. tostring(index)) :: TextButton
                        local InputField: TextBox = DragField.InputField
                        local value = getValueByIndex(state.value, index, thisWidget.arguments :: any)
                        if (dataType == "Color3" or dataType == "Color4") and not widget.arguments.UseFloats then
                            value = math.round(value * 255)
                        end

                        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
                        if thisWidget.arguments.Prefix then
                            format = thisWidget.arguments.Prefix[index] .. format
                        end
                        DragField.Text = string.format(format, value)
                        InputField.Text = tostring(value)

                        if thisWidget.state.editingText.value == index then
                            InputField.Visible = true
                            InputField:CaptureFocus()
                            DragField.TextTransparency = 1
                        else
                            InputField.Visible = false
                            DragField.TextTransparency = Axios._config.TextTransparency
                        end
                    end

                    if dataType == "Color3" or dataType == "Color4" then
                        local ColorBox: ImageLabel = Drag.ColorBox

                        ColorBox.BackgroundColor3 = widget.state.color.value

                        if dataType == "Color4" then
                            ColorBox.ImageTransparency = 1 - widget.state.transparency.value
                        end
                    end
                end,
            })
        end

        function generateColorDragScalar(dataType: InputDataTypes, ...: any)
            local defaultValues = { ... }
            local input = generateDragScalar(dataType, dataType == "Color4" and 4 or 3, defaultValues[1])

            return widgets.extend(input, {
                Args = {
                    ["Text"] = 1,
                    ["UseFloats"] = 2,
                    ["UseHSV"] = 3,
                    ["Format"] = 4,
                },
                Update = function(thisWidget: Types.InputColor4)
                    local Input = thisWidget.Instance :: GuiObject
                    local TextLabel: TextLabel = Input.TextLabel
                    TextLabel.Text = thisWidget.arguments.Text or `Drag {dataType}`

                    if thisWidget.arguments.Format and typeof(thisWidget.arguments.Format) ~= "table" then
                        thisWidget.arguments.Format = { thisWidget.arguments.Format }
                    elseif not thisWidget.arguments.Format then
                        if thisWidget.arguments.UseFloats then
                            thisWidget.arguments.Format = { "%.3f" }
                        else
                            thisWidget.arguments.Format = { "%d" }
                        end

                        thisWidget.arguments.Prefix = defaultPrefx[dataType .. if thisWidget.arguments.UseHSV then "_HSV" else "_RGB"]
                    end

                    thisWidget.arguments.Min = { 0, 0, 0, 0 }
                    thisWidget.arguments.Max = { 1, 1, 1, 1 }
                    thisWidget.arguments.Increment = { 0.001, 0.001, 0.001, 0.001 }

                    -- since the state values have changed display, we call an update. The check is because state is not
                    -- initialised on creation, so it would error otherwise.
                    if thisWidget.state then
                        thisWidget.state.color.lastChangeTick = Axios._cycleTick
                        if dataType == "Color4" then
                            thisWidget.state.transparency.lastChangeTick = Axios._cycleTick
                        end
                        Axios._widgets[thisWidget.type].UpdateState(thisWidget)
                    end
                end,
                GenerateState = function(thisWidget: Types.InputColor4)
                    if thisWidget.state.color == nil then
                        thisWidget.state.color = Axios._widgetState(thisWidget, "color", defaultValues[1])
                    end
                    if dataType == "Color4" then
                        if thisWidget.state.transparency == nil then
                            thisWidget.state.transparency = Axios._widgetState(thisWidget, "transparency", defaultValues[2])
                        end
                    end
                    if thisWidget.state.editingText == nil then
                        thisWidget.state.editingText = Axios._widgetState(thisWidget, "editingText", false)
                    end
                end,
            })
        end
    end

    --[[
        Slider
    ]]
    local generateSliderScalar: <T>(dataType: InputDataTypes, components: number, defaultValue: T) -> Types.WidgetClass
    local generateEnumSliderScalar: (enum: Enum, item: EnumItem) -> Types.WidgetClass
    do
        local AnyActiveSlider = false
        local ActiveSlider: Types.Input<Types.InputDataType>? = nil
        local ActiveIndex = 0
        local ActiveDataType: InputDataTypes | "" = ""

        local function updateActiveSlider()
            if AnyActiveSlider == false then
                return
            end
            if ActiveSlider == nil then
                return
            end

            local Slider = ActiveSlider.Instance :: Frame
            local SliderField = Slider:FindFirstChild("SliderField" .. tostring(ActiveIndex)) :: TextButton
            local GrabBar: Frame = SliderField.GrabBar

            local increment = ActiveSlider.arguments.Increment and getValueByIndex(ActiveSlider.arguments.Increment, ActiveIndex, ActiveSlider.arguments :: any) or defaultIncrements[ActiveDataType][ActiveIndex]
            local min = ActiveSlider.arguments.Min and getValueByIndex(ActiveSlider.arguments.Min, ActiveIndex, ActiveSlider.arguments :: any) or defaultMin[ActiveDataType][ActiveIndex]
            local max = ActiveSlider.arguments.Max and getValueByIndex(ActiveSlider.arguments.Max, ActiveIndex, ActiveSlider.arguments :: any) or defaultMax[ActiveDataType][ActiveIndex]

            local GrabWidth = GrabBar.AbsoluteSize.X
            local Offset = widgets.getMouseLocation().X - (SliderField.AbsolutePosition.X - widgets.GuiOffset.X + GrabWidth / 2)
            local Ratio = Offset / (SliderField.AbsoluteSize.X - GrabWidth)
            local Positions = math.floor((max - min) / increment)
            local newValue = math.clamp(math.round(Ratio * Positions) * increment + min, min, max)

            ActiveSlider.state.number:set(updateValueByIndex(ActiveSlider.state.number.value, ActiveIndex, newValue, ActiveSlider.arguments :: any))
            ActiveSlider.lastNumberChangedTick = Axios._cycleTick + 1
        end

        local function SliderMouseDown(thisWidget: Types.Input<Types.InputDataType>, dataType: InputDataTypes, index: number)
            local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if isCtrlHeld then
                thisWidget.state.editingText:set(index)
            else
                AnyActiveSlider = true
                ActiveSlider = thisWidget
                ActiveIndex = index
                ActiveDataType = dataType
                updateActiveSlider()
            end
        end

        widgets.registerEvent("InputChanged", function()
            if not Axios._started then
                return
            end
            updateActiveSlider()
        end)

        widgets.registerEvent("InputEnded", function(inputObject: InputObject)
            if not Axios._started then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveSlider then
                AnyActiveSlider = false
                ActiveSlider = nil
                ActiveIndex = 0
                ActiveDataType = ""
            end
        end)

        local function generateField<T>(thisWidget: Types.Input<T>, index: number, componentSize: UDim2, dataType: InputDataTypes)
            local SliderField = Instance.new("TextButton")
            SliderField.Name = "SliderField" .. tostring(index)
            SliderField.AutomaticSize = Enum.AutomaticSize.Y
            SliderField.Size = componentSize
            SliderField.BackgroundColor3 = Axios._config.FrameBgColor
            SliderField.BackgroundTransparency = Axios._config.FrameBgTransparency
            SliderField.Text = ""
            SliderField.AutoButtonColor = false
            SliderField.LayoutOrder = index
            SliderField.ClipsDescendants = true

            widgets.applyFrameStyle(SliderField)
            widgets.applyTextStyle(SliderField)
            widgets.UISizeConstraint(SliderField, Vector2.xAxis)

            local OverlayText = Instance.new("TextLabel")
            OverlayText.Name = "OverlayText"
            OverlayText.Size = UDim2.fromScale(1, 1)
            OverlayText.BackgroundTransparency = 1
            OverlayText.BorderSizePixel = 0
            OverlayText.ZIndex = 10
            OverlayText.ClipsDescendants = true

            widgets.applyTextStyle(OverlayText)

            OverlayText.TextXAlignment = Enum.TextXAlignment.Center

            OverlayText.Parent = SliderField

            widgets.applyInteractionHighlights("Background", SliderField, SliderField, {
                Color = Axios._config.FrameBgColor,
                Transparency = Axios._config.FrameBgTransparency,
                HoveredColor = Axios._config.FrameBgHoveredColor,
                HoveredTransparency = Axios._config.FrameBgHoveredTransparency,
                ActiveColor = Axios._config.FrameBgActiveColor,
                ActiveTransparency = Axios._config.FrameBgActiveTransparency,
            })

            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.Size = UDim2.fromScale(1, 1)
            InputField.BackgroundTransparency = 1
            InputField.ClearTextOnFocus = false
            InputField.TextTruncate = Enum.TextTruncate.AtEnd
            InputField.ClipsDescendants = true
            InputField.Visible = false

            widgets.applyFrameStyle(InputField, true)
            widgets.applyTextStyle(InputField)

            InputField.Parent = SliderField

            InputField.FocusLost:Connect(function()
                focusLost(thisWidget, InputField, index, dataType)
            end)

            InputField.Focused:Connect(function()
                -- this highlights the entire field
                InputField.CursorPosition = #InputField.Text + 1
                InputField.SelectionStart = 1

                thisWidget.state.editingText:set(index)
            end)

            widgets.applyButtonDown(SliderField, function()
                SliderMouseDown(thisWidget :: any, dataType, index)
            end)

            local GrabBar = Instance.new("Frame")
            GrabBar.Name = "GrabBar"
            GrabBar.AnchorPoint = Vector2.new(0.5, 0.5)
            GrabBar.Position = UDim2.fromScale(0, 0.5)
            GrabBar.BackgroundColor3 = Axios._config.SliderGrabColor
            GrabBar.Transparency = Axios._config.SliderGrabTransparency
            GrabBar.BorderSizePixel = 0
            GrabBar.ZIndex = 5

            widgets.applyInteractionHighlights("Background", SliderField, GrabBar, {
                Color = Axios._config.SliderGrabColor,
                Transparency = Axios._config.SliderGrabTransparency,
                HoveredColor = Axios._config.SliderGrabColor,
                HoveredTransparency = Axios._config.SliderGrabTransparency,
                ActiveColor = Axios._config.SliderGrabActiveColor,
                ActiveTransparency = Axios._config.SliderGrabActiveTransparency,
            })

            if Axios._config.GrabRounding > 0 then
                widgets.UICorner(GrabBar, Axios._config.GrabRounding)
            end

            widgets.UISizeConstraint(GrabBar, Vector2.new(Axios._config.GrabMinSize, 0))

            GrabBar.Parent = SliderField

            return SliderField
        end

        function generateSliderScalar<T>(dataType: InputDataTypes, components: number, defaultValue: T)
            local input = generateAbstract("Slider", dataType, components, defaultValue)

            return widgets.extend(input, {
                Generate = function(thisWidget: Types.Input<T>)
                    local Slider = Instance.new("Frame")
                    Slider.Name = "Axios_Slider" .. dataType
                    Slider.AutomaticSize = Enum.AutomaticSize.Y
                    Slider.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
                    Slider.BackgroundTransparency = 1
                    Slider.BorderSizePixel = 0

                    widgets.UIListLayout(Slider, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                    -- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
                    -- for the final field, we make sure it's flush by calculating the space avaiable for it. This only makes the Vector2 box
                    -- 4 pixels shorter, all for the sake of flush.
                    local componentWidth = UDim.new(Axios._config.ContentWidth.Scale / components, (Axios._config.ContentWidth.Offset - (Axios._config.ItemInnerSpacing.X * (components - 1))) / components)
                    local totalWidth = UDim.new(componentWidth.Scale * (components - 1), (componentWidth.Offset * (components - 1)) + (Axios._config.ItemInnerSpacing.X * (components - 1)))
                    local lastComponentWidth = Axios._config.ContentWidth - totalWidth

                    for index = 1, components do
                        generateField(thisWidget, index, if index == components then UDim2.new(lastComponentWidth, Axios._config.ContentHeight) else UDim2.new(componentWidth, Axios._config.ContentHeight), dataType).Parent = Slider
                    end

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Name = "TextLabel"
                    TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.BorderSizePixel = 0
                    TextLabel.LayoutOrder = 5

                    widgets.applyTextStyle(TextLabel)

                    TextLabel.Parent = Slider

                    return Slider
                end,
                UpdateState = function(thisWidget: Types.Input<T>)
                    local Slider = thisWidget.Instance :: Frame

                    for index = 1, components do
                        local SliderField = Slider:FindFirstChild("SliderField" .. tostring(index)) :: TextButton
                        local InputField: TextBox = SliderField.InputField
                        local OverlayText: TextLabel = SliderField.OverlayText
                        local GrabBar: Frame = SliderField.GrabBar

                        local value = getValueByIndex(thisWidget.state.number.value, index, thisWidget.arguments :: any)
                        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
                        if thisWidget.arguments.Prefix then
                            format = thisWidget.arguments.Prefix[index] .. format
                        end

                        OverlayText.Text = string.format(format, value)
                        InputField.Text = tostring(value)

                        local increment = thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any) or defaultIncrements[dataType][index]
                        local min = thisWidget.arguments.Min and getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any) or defaultMin[dataType][index]
                        local max = thisWidget.arguments.Max and getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any) or defaultMax[dataType][index]

                        local SliderWidth = SliderField.AbsoluteSize.X
                        local PaddedWidth = SliderWidth - GrabBar.AbsoluteSize.X
                        local Ratio = (value - min) / (max - min)
                        local Positions = math.floor((max - min) / increment)
                        local ClampedRatio = math.clamp(math.floor((Ratio * Positions)) / Positions, 0, 1)
                        local PaddedRatio = ((PaddedWidth / SliderWidth) * ClampedRatio) + ((1 - (PaddedWidth / SliderWidth)) / 2)

                        GrabBar.Position = UDim2.fromScale(PaddedRatio, 0.5)

                        if thisWidget.state.editingText.value == index then
                            InputField.Visible = true
                            OverlayText.Visible = false
                            GrabBar.Visible = false
                            InputField:CaptureFocus()
                        else
                            InputField.Visible = false
                            OverlayText.Visible = true
                            GrabBar.Visible = true
                        end
                    end
                end,
            })
        end

        function generateEnumSliderScalar(enum: Enum, item: EnumItem)
            local input: Types.WidgetClass = generateSliderScalar("Enum", 1, item.Value)
            local valueToName = { string }

            for _, enumItem in enum:GetEnumItems() do
                valueToName[enumItem.Value] = enumItem.Name
            end

            return widgets.extend(input, {
                Args = {
                    ["Text"] = 1,
                },
                Update = function(thisWidget: Types.InputEnum)
                    local Input = thisWidget.Instance :: GuiObject
                    local TextLabel: TextLabel = Input.TextLabel
                    TextLabel.Text = thisWidget.arguments.Text or "Input Enum"

                    thisWidget.arguments.Increment = 1
                    thisWidget.arguments.Min = 0
                    thisWidget.arguments.Max = #enum:GetEnumItems() - 1

                    local SliderField = Input:FindFirstChild("SliderField1") :: TextButton
                    local GrabBar: Frame = SliderField.GrabBar

                    local grabScaleSize = 1 / math.floor(#enum:GetEnumItems())

                    GrabBar.Size = UDim2.fromScale(grabScaleSize, 1)
                end,
                GenerateState = function(thisWidget: Types.InputEnum)
                    if thisWidget.state.number == nil then
                        thisWidget.state.number = Axios._widgetState(thisWidget, "number", item.Value)
                    end
                    if thisWidget.state.enumItem == nil then
                        thisWidget.state.enumItem = Axios._widgetState(thisWidget, "enumItem", item)
                    end
                    if thisWidget.state.editingText == nil then
                        thisWidget.state.editingText = Axios._widgetState(thisWidget, "editingText", false)
                    end
                end,
            })
        end
    end

    do
        local inputNum: Types.WidgetClass = generateInputScalar("Num", 1, 0)
        inputNum.Args["NoButtons"] = 6
        Axios.WidgetConstructor("InputNum", inputNum)
    end
    Axios.WidgetConstructor("InputVector2", generateInputScalar("Vector2", 2, Vector2.zero))
    Axios.WidgetConstructor("InputVector3", generateInputScalar("Vector3", 3, Vector3.zero))
    Axios.WidgetConstructor("InputUDim", generateInputScalar("UDim", 2, UDim.new()))
    Axios.WidgetConstructor("InputUDim2", generateInputScalar("UDim2", 4, UDim2.new()))
    Axios.WidgetConstructor("InputRect", generateInputScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

    Axios.WidgetConstructor("DragNum", generateDragScalar("Num", 1, 0))
    Axios.WidgetConstructor("DragVector2", generateDragScalar("Vector2", 2, Vector2.zero))
    Axios.WidgetConstructor("DragVector3", generateDragScalar("Vector3", 3, Vector3.zero))
    Axios.WidgetConstructor("DragUDim", generateDragScalar("UDim", 2, UDim.new()))
    Axios.WidgetConstructor("DragUDim2", generateDragScalar("UDim2", 4, UDim2.new()))
    Axios.WidgetConstructor("DragRect", generateDragScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

    Axios.WidgetConstructor("InputColor3", generateColorDragScalar("Color3", Color3.fromRGB(0, 0, 0)))
    Axios.WidgetConstructor("InputColor4", generateColorDragScalar("Color4", Color3.fromRGB(0, 0, 0), 0))

    Axios.WidgetConstructor("SliderNum", generateSliderScalar("Num", 1, 0))
    Axios.WidgetConstructor("SliderVector2", generateSliderScalar("Vector2", 2, Vector2.zero))
    Axios.WidgetConstructor("SliderVector3", generateSliderScalar("Vector3", 3, Vector3.zero))
    Axios.WidgetConstructor("SliderUDim", generateSliderScalar("UDim", 2, UDim.new()))
    Axios.WidgetConstructor("SliderUDim2", generateSliderScalar("UDim2", 4, UDim2.new()))
    Axios.WidgetConstructor("SliderRect", generateSliderScalar("Rect", 4, Rect.new(0, 0, 0, 0)))
    -- Axios.WidgetConstructor("SliderEnum", generateSliderScalar("Enum", 4, 0))

    -- stylua: ignore
    Axios.WidgetConstructor("InputText", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["TextHint"] = 2,
            ["ReadOnly"] = 3,
            ["MultiLine"] = 4,
        },
        Events = {
            ["textChanged"] = {
                ["Init"] = function(thisWidget: Types.InputText)
                    thisWidget.lastTextChangedTick = 0
                end,
                ["Get"] = function(thisWidget: Types.InputText)
                    return thisWidget.lastTextChangedTick == Axios._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.InputText)
            local InputText: Frame = Instance.new("Frame")
            InputText.Name = "Axios_InputText"
            InputText.AutomaticSize = Enum.AutomaticSize.Y
            InputText.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            InputText.BackgroundTransparency = 1
            InputText.BorderSizePixel = 0
            widgets.UIListLayout(InputText, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local InputField: TextBox = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.AutomaticSize = Enum.AutomaticSize.Y
            InputField.Size = UDim2.new(Axios._config.ContentWidth, Axios._config.ContentHeight)
            InputField.BackgroundColor3 = Axios._config.FrameBgColor
            InputField.BackgroundTransparency = Axios._config.FrameBgTransparency
            InputField.Text = ""
            InputField.TextYAlignment = Enum.TextYAlignment.Top
            InputField.PlaceholderColor3 = Axios._config.TextDisabledColor
            InputField.ClearTextOnFocus = false
            InputField.ClipsDescendants = true

            widgets.applyFrameStyle(InputField)
            widgets.applyTextStyle(InputField)
            widgets.UISizeConstraint(InputField, Vector2.xAxis) -- prevents sizes beaking when getting too small.
            -- InputField.UIPadding.PaddingLeft = UDim.new(0, Axios._config.ItemInnerSpacing.X)
            -- InputField.UIPadding.PaddingRight = UDim.new(0, 0)
            InputField.Parent = InputText

            InputField.FocusLost:Connect(function()
                thisWidget.state.text:set(InputField.Text)
                thisWidget.lastTextChangedTick = Axios._cycleTick + 1
            end)

            local frameHeight: number = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y

            local TextLabel: TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.X
            TextLabel.Size = UDim2.fromOffset(0, frameHeight)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = InputText

            return InputText
        end,
        GenerateState = function(thisWidget: Types.InputText)
            if thisWidget.state.text == nil then
                thisWidget.state.text = Axios._widgetState(thisWidget, "text", "")
            end
        end,
        Update = function(thisWidget: Types.InputText)
            local InputText = thisWidget.Instance :: Frame
            local TextLabel: TextLabel = InputText.TextLabel
            local InputField: TextBox = InputText.InputField

            TextLabel.Text = thisWidget.arguments.Text or "Input Text"
            InputField.PlaceholderText = thisWidget.arguments.TextHint or ""
            InputField.TextEditable = not thisWidget.arguments.ReadOnly
            InputField.MultiLine = thisWidget.arguments.MultiLine or false
        end,
        UpdateState = function(thisWidget: Types.InputText)
            local InputText = thisWidget.Instance :: Frame
            local InputField: TextBox = InputText.InputField
    
            InputField.Text = thisWidget.state.text.value
        end,
        Discard = function(thisWidget: Types.InputText)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Menu"] = function()
    local script = create_mock_script("Axios.widgets.Menu")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local AnyMenuOpen = false
    local ActiveMenu: Types.Menu? = nil
    local MenuStack: { Types.Menu } = {}

    local function EmptyMenuStack(menuIndex: number?)
        for index = #MenuStack, menuIndex and menuIndex + 1 or 1, -1 do
            local widget = MenuStack[index]
            widget.state.isOpened:set(false)

            widget.Instance.BackgroundColor3 = Axios._config.HeaderColor
            widget.Instance.BackgroundTransparency = 1

            table.remove(MenuStack, index)
        end

        if #MenuStack == 0 then
            AnyMenuOpen = false
            ActiveMenu = nil
        end
    end

    local function UpdateChildContainerTransform(thisWidget: Types.Menu)
        local submenu = thisWidget.parentWidget.type == "Menu"

        local Menu = thisWidget.Instance :: Frame
        local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame
        ChildContainer.Size = UDim2.fromOffset(Menu.AbsoluteSize.X, 0)
        if ChildContainer.Parent == nil then
            return
        end

        local menuPosition = Menu.AbsolutePosition - widgets.GuiOffset
        local menuSize = Menu.AbsoluteSize
        local containerSize = ChildContainer.AbsoluteSize
        local borderSize = Axios._config.PopupBorderSize
        local screenSize: Vector2 = ChildContainer.Parent.AbsoluteSize

        local x = menuPosition.X
        local y
        local anchor = Vector2.zero

        if submenu then
            if menuPosition.X + containerSize.X > screenSize.X then
                anchor = Vector2.xAxis
            else
                x = menuPosition.X + menuSize.X
            end
        end

        if menuPosition.Y + containerSize.Y > screenSize.Y then
            -- too low.
            y = menuPosition.Y - borderSize + (submenu and menuSize.Y or 0)
            anchor += Vector2.yAxis
        else
            y = menuPosition.Y + borderSize + (submenu and 0 or menuSize.Y)
        end

        ChildContainer.Position = UDim2.fromOffset(x, y)
        ChildContainer.AnchorPoint = anchor
    end

    widgets.registerEvent("InputBegan", function(inputObject: InputObject)
        if not Axios._started then
            return
        end
        if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.MouseButton2 then
            return
        end
        if AnyMenuOpen == false then
            return
        end
        if ActiveMenu == nil then
            return
        end

        -- this only checks if we clicked outside all the menus. If we clicked in any menu, then the hover function handles this.
        local isInMenu = false
        local MouseLocation = widgets.getMouseLocation()
        for _, menu in MenuStack do
            for _, container in { menu.ChildContainer, menu.Instance } do
                local rectMin = container.AbsolutePosition - widgets.GuiOffset
                local rectMax = rectMin + container.AbsoluteSize
                if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
                    isInMenu = true
                    break
                end
            end
            if isInMenu then
                break
            end
        end

        if not isInMenu then
            EmptyMenuStack()
        end
    end)

    --stylua: ignore
    Axios.WidgetConstructor("MenuBar", {
        hasState = false,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(_thisWidget: Types.MenuBar)
            local MenuBar = Instance.new("Frame")
            MenuBar.Name = "Axios_MenuBar"
            MenuBar.AutomaticSize = Enum.AutomaticSize.Y
            MenuBar.Size = UDim2.fromScale(1, 0)
            MenuBar.BackgroundColor3 = Axios._config.MenubarBgColor
            MenuBar.BackgroundTransparency = Axios._config.MenubarBgTransparency
            MenuBar.BorderSizePixel = 0
            MenuBar.ClipsDescendants = true

            widgets.UIPadding(MenuBar, Vector2.new(Axios._config.WindowPadding.X, 1))
            widgets.UIListLayout(MenuBar, Enum.FillDirection.Horizontal, UDim.new()).VerticalAlignment = Enum.VerticalAlignment.Center
            widgets.applyFrameStyle(MenuBar, true, true)

            return MenuBar
        end,
        Update = function(_thisWidget: Types.Widget)
            
        end,
        ChildAdded = function(thisWidget: Types.MenuBar, _thisChild: Types.Widget)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget: Types.MenuBar)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("Menu", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["opened"] = {
                ["Init"] = function(_thisWidget: Types.Menu) end,
                ["Get"] = function(thisWidget: Types.Menu)
                    return thisWidget.lastOpenedTick == Axios._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget: Types.Menu) end,
                ["Get"] = function(thisWidget: Types.Menu)
                    return thisWidget.lastClosedTick == Axios._cycleTick
                end,
            },
        },
        Generate = function(thisWidget: Types.Menu)
            local Menu: TextButton
            thisWidget.ButtonColors = {
                Color = Axios._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Axios._config.HeaderHoveredColor,
                HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                ActiveColor = Axios._config.HeaderHoveredColor,
                ActiveTransparency = Axios._config.HeaderHoveredTransparency,
            }
            if thisWidget.parentWidget.type == "Menu" then
                -- this Menu is a sub-Menu
                Menu = Instance.new("TextButton")
                Menu.Name = "Menu"
                Menu.AutomaticSize = Enum.AutomaticSize.Y
                Menu.Size = UDim2.fromScale(1, 0)
                Menu.BackgroundColor3 = Axios._config.HeaderColor
                Menu.BackgroundTransparency = 1
                Menu.BorderSizePixel = 0
                Menu.Text = ""
                Menu.AutoButtonColor = false

                local UIPadding = widgets.UIPadding(Menu, Axios._config.FramePadding)
                UIPadding.PaddingTop = UIPadding.PaddingTop - UDim.new(0, 1)
                widgets.UIListLayout(Menu, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Name = "TextLabel"
                TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                TextLabel.BackgroundTransparency = 1
                TextLabel.BorderSizePixel = 0

                widgets.applyTextStyle(TextLabel)

                TextLabel.Parent = Menu

                local frameSize = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y
                local padding = math.round(0.2 * frameSize)
                local iconSize = frameSize - 2 * padding

                local Icon = Instance.new("ImageLabel")
                Icon.Name = "Icon"
                Icon.Size = UDim2.fromOffset(iconSize, iconSize)
                Icon.BackgroundTransparency = 1
                Icon.BorderSizePixel = 0
                Icon.ImageColor3 = Axios._config.TextColor
                Icon.ImageTransparency = Axios._config.TextTransparency
                Icon.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE
                Icon.LayoutOrder = 1

                Icon.Parent = Menu
            else
                Menu = Instance.new("TextButton")
                Menu.Name = "Menu"
                Menu.AutomaticSize = Enum.AutomaticSize.XY
                Menu.Size = UDim2.fromScale(0, 0)
                Menu.BackgroundColor3 = Axios._config.HeaderColor
                Menu.BackgroundTransparency = 1
                Menu.BorderSizePixel = 0
                Menu.Text = ""
                Menu.AutoButtonColor = false
                Menu.ClipsDescendants = true

                widgets.applyTextStyle(Menu)
                widgets.UIPadding(Menu, Vector2.new(Axios._config.ItemSpacing.X, Axios._config.FramePadding.Y))
            end
            widgets.applyInteractionHighlights("Background", Menu, Menu, thisWidget.ButtonColors)

            widgets.applyButtonClick(Menu, function()
                local openMenu = if #MenuStack <= 1 then not thisWidget.state.isOpened.value else true
                thisWidget.state.isOpened:set(openMenu)

                AnyMenuOpen = openMenu
                ActiveMenu = openMenu and thisWidget or nil
                -- the hovering should handle all of the menus after the first one.
                if #MenuStack <= 1 then
                    if openMenu then
                        table.insert(MenuStack, thisWidget)
                    else
                        table.remove(MenuStack)
                    end
                end
            end)

            widgets.applyMouseEnter(Menu, function()
                if AnyMenuOpen and ActiveMenu and ActiveMenu ~= thisWidget then
                    local parentMenu = thisWidget.parentWidget :: Types.Menu
                    local parentIndex = table.find(MenuStack, parentMenu)

                    EmptyMenuStack(parentIndex)
                    thisWidget.state.isOpened:set(true)
                    ActiveMenu = thisWidget
                    AnyMenuOpen = true
                    table.insert(MenuStack, thisWidget)
                end
            end)

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "MenuContainer"
            ChildContainer.AutomaticSize = Enum.AutomaticSize.XY
            ChildContainer.Size = UDim2.fromOffset(0, 0)
            ChildContainer.BackgroundColor3 = Axios._config.PopupBgColor
            ChildContainer.BackgroundTransparency = Axios._config.PopupBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Axios._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Axios._config.ScrollbarGrabColor
            ChildContainer.ScrollBarThickness = Axios._config.ScrollbarSize
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            ChildContainer.ZIndex = 6
            ChildContainer.LayoutOrder = 6
            ChildContainer.ClipsDescendants = true

            -- Unfortunatley, ScrollingFrame does not work with UICorner
            -- if Axios._config.PopupRounding > 0 then
            --     widgets.UICorner(ChildContainer, Axios._config.PopupRounding)
            -- end

            widgets.UIStroke(ChildContainer, Axios._config.WindowBorderSize, Axios._config.BorderColor, Axios._config.BorderTransparency)
            widgets.UIPadding(ChildContainer, Vector2.new(2, Axios._config.WindowPadding.Y - Axios._config.ItemSpacing.Y))
            
            widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, 1)).VerticalAlignment = Enum.VerticalAlignment.Top

            local RootPopupScreenGui = Axios._rootInstance and Axios._rootInstance:FindFirstChild("PopupScreenGui") :: GuiObject
            ChildContainer.Parent = RootPopupScreenGui
            
            
            thisWidget.ChildContainer = ChildContainer
            return Menu
        end,
        Update = function(thisWidget: Types.Menu)
            local Menu = thisWidget.Instance :: TextButton
            local TextLabel: TextLabel
            if thisWidget.parentWidget.type == "Menu" then
                TextLabel = Menu.TextLabel
            else
                TextLabel = Menu
            end
            TextLabel.Text = thisWidget.arguments.Text or "Menu"
        end,
        ChildAdded = function(thisWidget: Types.Menu, _thisChild: Types.Widget)
            UpdateChildContainerTransform(thisWidget)
            return thisWidget.ChildContainer
        end,
        ChildDiscarded = function(thisWidget: Types.Menu, _thisChild: Types.Widget)
            UpdateChildContainerTransform(thisWidget)
        end,
        GenerateState = function(thisWidget: Types.Menu)
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Axios._widgetState(thisWidget, "isOpened", false)
            end
        end,
        UpdateState = function(thisWidget: Types.Menu)
            local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame

            if thisWidget.state.isOpened.value then
                thisWidget.lastOpenedTick = Axios._cycleTick + 1
                thisWidget.ButtonColors.Transparency = Axios._config.HeaderTransparency
                ChildContainer.Visible = true

                UpdateChildContainerTransform(thisWidget)
            else
                thisWidget.lastClosedTick = Axios._cycleTick + 1
                thisWidget.ButtonColors.Transparency = 1
                ChildContainer.Visible = false
            end
        end,
        Discard = function(thisWidget: Types.Menu)
            -- properly handle removing a menu if open and deleted
            if AnyMenuOpen then
                local parentMenu = thisWidget.parentWidget :: Types.Menu
                local parentIndex = table.find(MenuStack, parentMenu)
                if parentIndex then
                    EmptyMenuStack(parentIndex)
                    if #MenuStack ~= 0 then
                        ActiveMenu = parentMenu
                        AnyMenuOpen = true
                    end
                end
            end

            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("MenuItem", {
        hasState = false,
        hasChildren = false,
        Args = {
            Text = 1,
            KeyCode = 2,
            ModifierKey = 3,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.MenuItem)
            local MenuItem = Instance.new("TextButton")
            MenuItem.Name = "Axios_MenuItem"
            MenuItem.AutomaticSize = Enum.AutomaticSize.Y
            MenuItem.Size = UDim2.fromScale(1, 0)
            MenuItem.BackgroundTransparency = 1
            MenuItem.BorderSizePixel = 0
            MenuItem.Text = ""
            MenuItem.AutoButtonColor = false

            local UIPadding = widgets.UIPadding(MenuItem, Axios._config.FramePadding)
            UIPadding.PaddingTop = UIPadding.PaddingTop - UDim.new(0, 1)
            widgets.UIListLayout(MenuItem, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X))

            widgets.applyInteractionHighlights("Background", MenuItem, MenuItem, {
                Color = Axios._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Axios._config.HeaderHoveredColor,
                HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                ActiveColor = Axios._config.HeaderHoveredColor,
                ActiveTransparency = Axios._config.HeaderHoveredTransparency,
            })

            widgets.applyButtonClick(MenuItem, function()
                EmptyMenuStack()
            end)

            widgets.applyMouseEnter(MenuItem, function()
                local parentMenu = thisWidget.parentWidget :: Types.Menu
                if AnyMenuOpen and ActiveMenu and ActiveMenu ~= parentMenu then
                    local parentIndex = table.find(MenuStack, parentMenu)

                    EmptyMenuStack(parentIndex)
                    ActiveMenu = parentMenu
                    AnyMenuOpen = true
                end
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = MenuItem

            local Shortcut = Instance.new("TextLabel")
            Shortcut.Name = "Shortcut"
            Shortcut.AutomaticSize = Enum.AutomaticSize.XY
            Shortcut.BackgroundTransparency = 1
            Shortcut.BorderSizePixel = 0
            Shortcut.LayoutOrder = 1

            widgets.applyTextStyle(Shortcut)

            Shortcut.Text = ""
            Shortcut.TextColor3 = Axios._config.TextDisabledColor
            Shortcut.TextTransparency = Axios._config.TextDisabledTransparency

            Shortcut.Parent = MenuItem

            return MenuItem
        end,
        Update = function(thisWidget: Types.MenuItem)
            local MenuItem = thisWidget.Instance :: TextButton
            local TextLabel: TextLabel = MenuItem.TextLabel
            local Shortcut: TextLabel = MenuItem.Shortcut

            TextLabel.Text = thisWidget.arguments.Text
            if thisWidget.arguments.KeyCode then
                if thisWidget.arguments.ModifierKey then
                    Shortcut.Text = thisWidget.arguments.ModifierKey.Name .. " + " .. thisWidget.arguments.KeyCode.Name
                else
                    Shortcut.Text = thisWidget.arguments.KeyCode.Name
                end
            end
        end,
        Discard = function(thisWidget: Types.MenuItem)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("MenuToggle", {
        hasState = true,
        hasChildren = false,
        Args = {
            Text = 1,
            KeyCode = 2,
            ModifierKey = 3,
        },
        Events = {
            ["checked"] = {
                ["Init"] = function(_thisWidget: Types.MenuToggle) end,
                ["Get"] = function(thisWidget: Types.MenuToggle): boolean
                    return thisWidget.lastCheckedTick == Axios._cycleTick
                end,
            },
            ["unchecked"] = {
                ["Init"] = function(_thisWidget: Types.MenuToggle) end,
                ["Get"] = function(thisWidget: Types.MenuToggle): boolean
                    return thisWidget.lastUncheckedTick == Axios._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.MenuToggle)
            local MenuToggle = Instance.new("TextButton")
            MenuToggle.Name = "Axios_MenuToggle"
            MenuToggle.AutomaticSize = Enum.AutomaticSize.Y
            MenuToggle.Size = UDim2.fromScale(1, 0)
            MenuToggle.BackgroundTransparency = 1
            MenuToggle.BorderSizePixel = 0
            MenuToggle.Text = ""
            MenuToggle.AutoButtonColor = false

            local UIPadding = widgets.UIPadding(MenuToggle, Axios._config.FramePadding)
            UIPadding.PaddingTop = UIPadding.PaddingTop - UDim.new(0, 1)
            widgets.UIListLayout(MenuToggle, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            widgets.applyInteractionHighlights("Background", MenuToggle, MenuToggle, {
                Color = Axios._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Axios._config.HeaderHoveredColor,
                HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                ActiveColor = Axios._config.HeaderHoveredColor,
                ActiveTransparency = Axios._config.HeaderHoveredTransparency,
            })

            widgets.applyButtonClick(MenuToggle, function()
                thisWidget.state.isChecked:set(not thisWidget.state.isChecked.value)
                EmptyMenuStack()
            end)

            widgets.applyMouseEnter(MenuToggle, function()
                local parentMenu = thisWidget.parentWidget :: Types.Menu
                if AnyMenuOpen and ActiveMenu and ActiveMenu ~= parentMenu then
                    local parentIndex = table.find(MenuStack, parentMenu)

                    EmptyMenuStack(parentIndex)
                    ActiveMenu = parentMenu
                    AnyMenuOpen = true
                end
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = MenuToggle

            local Shortcut = Instance.new("TextLabel")
            Shortcut.Name = "Shortcut"
            Shortcut.AutomaticSize = Enum.AutomaticSize.XY
            Shortcut.BackgroundTransparency = 1
            Shortcut.BorderSizePixel = 0
            Shortcut.LayoutOrder = 1

            widgets.applyTextStyle(Shortcut)

            Shortcut.Text = ""
            Shortcut.TextColor3 = Axios._config.TextDisabledColor
            Shortcut.TextTransparency = Axios._config.TextDisabledTransparency

            Shortcut.Parent = MenuToggle

            local frameSize = Axios._config.TextSize + 2 * Axios._config.FramePadding.Y
            local padding = math.round(0.2 * frameSize)
            local iconSize = frameSize - 2 * padding

            local Icon = Instance.new("ImageLabel")
            Icon.Name = "Icon"
            Icon.Size = UDim2.fromOffset(iconSize, iconSize)
            Icon.BackgroundTransparency = 1
            Icon.BorderSizePixel = 0
            Icon.ImageColor3 = Axios._config.TextColor
            Icon.ImageTransparency = Axios._config.TextTransparency
            Icon.Image = widgets.ICONS.CHECKMARK
            Icon.LayoutOrder = 2

            Icon.Parent = MenuToggle

            return MenuToggle
        end,
        GenerateState = function(thisWidget: Types.MenuToggle)
            if thisWidget.state.isChecked == nil then
                thisWidget.state.isChecked = Axios._widgetState(thisWidget, "isChecked", false)
            end
        end,
        Update = function(thisWidget: Types.MenuToggle)
            local MenuToggle = thisWidget.Instance :: TextButton
            local TextLabel: TextLabel = MenuToggle.TextLabel
            local Shortcut: TextLabel = MenuToggle.Shortcut

            TextLabel.Text = thisWidget.arguments.Text
            if thisWidget.arguments.KeyCode then
                if thisWidget.arguments.ModifierKey then
                    Shortcut.Text = thisWidget.arguments.ModifierKey.Name .. " + " .. thisWidget.arguments.KeyCode.Name
                else
                    Shortcut.Text = thisWidget.arguments.KeyCode.Name
                end
            end
        end,
        UpdateState = function(thisWidget: Types.MenuToggle)
            local MenuItem = thisWidget.Instance :: TextButton
            local Icon: ImageLabel = MenuItem.Icon

            if thisWidget.state.isChecked.value then
                Icon.ImageTransparency = Axios._config.TextTransparency
                thisWidget.lastCheckedTick = Axios._cycleTick + 1
            else
                Icon.ImageTransparency = 1
                thisWidget.lastUncheckedTick = Axios._cycleTick + 1
            end
        end,
        Discard = function(thisWidget: Types.MenuToggle)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Plot"] = function()
    local script = create_mock_script("Axios.widgets.Plot")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    -- stylua: ignore
    Axios.WidgetConstructor("ProgressBar", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Format"] = 2,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["changed"] = {
                ["Init"] = function(_thisWidget: Types.ProgressBar) end,
                ["Get"] = function(thisWidget: Types.ProgressBar)
                    return thisWidget.lastChangedTick == Axios._cycleTick
                end,
            },
        },
        Generate = function(_thisWidget: Types.ProgressBar)
            local ProgressBar = Instance.new("Frame")
            ProgressBar.Name = "Axios_ProgressBar"
            ProgressBar.AutomaticSize = Enum.AutomaticSize.Y
            ProgressBar.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            ProgressBar.BackgroundTransparency = 1

            widgets.UIListLayout(ProgressBar, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local Bar = Instance.new("Frame")
            Bar.Name = "Bar"
            Bar.AutomaticSize = Enum.AutomaticSize.Y
            Bar.Size = UDim2.new(Axios._config.ContentWidth, Axios._config.ContentHeight)
            Bar.BackgroundColor3 = Axios._config.FrameBgColor
            Bar.BackgroundTransparency = Axios._config.FrameBgTransparency
            Bar.BorderSizePixel = 0
            Bar.ClipsDescendants = true

            widgets.applyFrameStyle(Bar, true)

            Bar.Parent = ProgressBar

            local Progress = Instance.new("TextLabel")
            Progress.Name = "Progress"
            Progress.AutomaticSize = Enum.AutomaticSize.Y
            Progress.Size = UDim2.new(UDim.new(0, 0), Axios._config.ContentHeight)
            Progress.BackgroundColor3 = Axios._config.PlotHistogramColor
            Progress.BackgroundTransparency = Axios._config.PlotHistogramTransparency
            Progress.BorderSizePixel = 0

            widgets.applyTextStyle(Progress)
            widgets.UIPadding(Progress, Axios._config.FramePadding)
            widgets.UICorner(Progress, Axios._config.FrameRounding)

            Progress.Text = ""
            Progress.Parent = Bar

            local Value = Instance.new("TextLabel")
            Value.Name = "Value"
            Value.AutomaticSize = Enum.AutomaticSize.XY
            Value.Size = UDim2.new(UDim.new(0, 0), Axios._config.ContentHeight)
            Value.BackgroundTransparency = 1
            Value.BorderSizePixel = 0
            Value.ZIndex = 1

            widgets.applyTextStyle(Value)
            widgets.UIPadding(Value, Axios._config.FramePadding)

            Value.Parent = Bar

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.AnchorPoint = Vector2.new(0, 0.5)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)
            widgets.UIPadding(Value, Axios._config.FramePadding)

            TextLabel.Parent = ProgressBar

            return ProgressBar
        end,
        GenerateState = function(thisWidget: Types.ProgressBar)
            if thisWidget.state.progress == nil then
                thisWidget.state.progress = Axios._widgetState(thisWidget, "Progress", 0)
            end
        end,
        Update = function(thisWidget: Types.ProgressBar)
            local Progress = thisWidget.Instance :: Frame
            local TextLabel: TextLabel = Progress.TextLabel
            local Bar = Progress.Bar :: Frame
            local Value: TextLabel = Bar.Value

            if thisWidget.arguments.Format ~= nil and typeof(thisWidget.arguments.Format) == "string" then
                Value.Text = thisWidget.arguments.Format
            end

            TextLabel.Text = thisWidget.arguments.Text or "Progress Bar"
        end,
        UpdateState = function(thisWidget: Types.ProgressBar)
            local ProgressBar = thisWidget.Instance :: Frame
            local Bar = ProgressBar.Bar :: Frame
            local Progress: TextLabel = Bar.Progress
            local Value: TextLabel = Bar.Value

            local progress = math.clamp(thisWidget.state.progress.value, 0, 1)
            local totalWidth = Bar.AbsoluteSize.X
            local textWidth = Value.AbsoluteSize.X
            if totalWidth * (1 - progress) < textWidth then
                Value.AnchorPoint = Vector2.xAxis
                Value.Position = UDim2.fromScale(1, 0)
            else
                Value.AnchorPoint = Vector2.zero
                Value.Position = UDim2.fromScale(progress, 0)
            end

            Progress.Size = UDim2.new(UDim.new(progress, 0), Progress.Size.Height)
            if thisWidget.arguments.Format ~= nil and typeof(thisWidget.arguments.Format) == "string" then
                Value.Text = thisWidget.arguments.Format
            else
                Value.Text = string.format("%d%%", progress * 100)
            end
            thisWidget.lastChangedTick = Axios._cycleTick + 1
        end,
        Discard = function(thisWidget: Types.ProgressBar)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)

    local function createLine(parent: Frame, index: number)
        local Block = Instance.new("Frame")
        Block.Name = tostring(index)
        Block.AnchorPoint = Vector2.new(0.5, 0.5)
        Block.BackgroundColor3 = Axios._config.PlotLinesColor
        Block.BackgroundTransparency = Axios._config.PlotLinesTransparency
        Block.BorderSizePixel = 0

        Block.Parent = parent

        return Block
    end

    local function clearLine(thisWidget: Types.PlotLines)
        if thisWidget.HoveredLine then
            thisWidget.HoveredLine.BackgroundColor3 = Axios._config.PlotLinesColor
            thisWidget.HoveredLine.BackgroundTransparency = Axios._config.PlotLinesTransparency
            thisWidget.HoveredLine = false
            thisWidget.state.hovered:set(nil)
        end
    end

    local function updateLine(thisWidget: Types.PlotLines, silent: true?)
        local PlotLines = thisWidget.Instance :: Frame
        local Background = PlotLines.Background :: Frame
        local Plot = Background.Plot :: Frame

        local mousePosition = widgets.getMouseLocation()

        local position = Plot.AbsolutePosition - widgets.GuiOffset
        local scale = (mousePosition.X - position.X) / Plot.AbsoluteSize.X
        local index = math.ceil(scale * #thisWidget.Lines)
        local line: Frame? = thisWidget.Lines[index]

        if line then
            if line ~= thisWidget.HoveredLine and not silent then
                clearLine(thisWidget)
            end
            local start: number? = thisWidget.state.values.value[index]
            local stop: number? = thisWidget.state.values.value[index + 1]
            if start and stop then
                if math.floor(start) == start and math.floor(stop) == stop then
                    thisWidget.Tooltip.Text = ("%d: %d\n%d: %d"):format(index, start, index + 1, stop)
                else
                    thisWidget.Tooltip.Text = ("%d: %.3f\n%d: %.3f"):format(index, start, index + 1, stop)
                end
            end
            thisWidget.HoveredLine = line
            line.BackgroundColor3 = Axios._config.PlotLinesHoveredColor
            line.BackgroundTransparency = Axios._config.PlotLinesHoveredTransparency
            if silent then
                thisWidget.state.hovered.value = { start, stop }
            else
                thisWidget.state.hovered:set({ start, stop })
            end
        end
    end

    -- stylua: ignore
    Axios.WidgetConstructor("PlotLines", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Height"] = 2,
            ["Min"] = 3,
            ["Max"] = 4,
            ["TextOverlay"] = 5,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.PlotLines)
            local PlotLines = Instance.new("Frame")
            PlotLines.Name = "Axios_PlotLines"
            PlotLines.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            PlotLines.BackgroundTransparency = 1
            PlotLines.BorderSizePixel = 0

            widgets.UIListLayout(PlotLines, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local Background = Instance.new("Frame")
            Background.Name = "Background"
            Background.Size = UDim2.new(Axios._config.ContentWidth, UDim.new(1, 0))
            Background.BackgroundColor3 = Axios._config.FrameBgColor
            Background.BackgroundTransparency = Axios._config.FrameBgTransparency
            widgets.applyFrameStyle(Background)

            Background.Parent = PlotLines

            local Plot = Instance.new("Frame")
            Plot.Name = "Plot"
            Plot.Size = UDim2.fromScale(1, 1)
            Plot.BackgroundTransparency = 1
            Plot.BorderSizePixel = 0
            Plot.ClipsDescendants = true

            Plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                thisWidget.state.values.lastChangeTick = Axios._cycleTick
                Axios._widgets.PlotLines.UpdateState(thisWidget)
            end)

            local OverlayText = Instance.new("TextLabel")
            OverlayText.Name = "OverlayText"
            OverlayText.AutomaticSize = Enum.AutomaticSize.XY
            OverlayText.AnchorPoint = Vector2.new(0.5, 0)
            OverlayText.Size = UDim2.fromOffset(0, 0)
            OverlayText.Position = UDim2.fromScale(0.5, 0)
            OverlayText.BackgroundTransparency = 1
            OverlayText.BorderSizePixel = 0
            OverlayText.ZIndex = 2
            
            widgets.applyTextStyle(OverlayText)

            OverlayText.Parent = Plot

            local Tooltip = Instance.new("TextLabel")
            Tooltip.Name = "Axios_Tooltip"
            Tooltip.AutomaticSize = Enum.AutomaticSize.XY
            Tooltip.Size = UDim2.fromOffset(0, 0)
            Tooltip.BackgroundColor3 = Axios._config.PopupBgColor
            Tooltip.BackgroundTransparency = Axios._config.PopupBgTransparency
            Tooltip.BorderSizePixel = 0
            Tooltip.Visible = false

            widgets.applyTextStyle(Tooltip)
            widgets.UIStroke(Tooltip, Axios._config.PopupBorderSize, Axios._config.BorderActiveColor, Axios._config.BorderActiveTransparency)
            widgets.UIPadding(Tooltip, Axios._config.WindowPadding)
            if Axios._config.PopupRounding > 0 then
                widgets.UICorner(Tooltip, Axios._config.PopupRounding)
            end

            local popup = Axios._rootInstance and Axios._rootInstance:FindFirstChild("PopupScreenGui")
            Tooltip.Parent = popup and popup:FindFirstChild("TooltipContainer")

            thisWidget.Tooltip = Tooltip

            widgets.applyMouseMoved(Plot, function()
                updateLine(thisWidget)
            end)

            widgets.applyMouseLeave(Plot, function()
                clearLine(thisWidget)
            end)

            Plot.Parent = Background

            thisWidget.Lines = {}
            thisWidget.HoveredLine = false

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.Size = UDim2.fromOffset(0, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.ZIndex = 3
            TextLabel.LayoutOrder = 3

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = PlotLines

            return PlotLines
        end,
        GenerateState = function(thisWidget: Types.PlotLines)
            if thisWidget.state.values == nil then
                thisWidget.state.values = Axios._widgetState(thisWidget, "values", { 0, 1 })
            end
            if thisWidget.state.hovered == nil then
                thisWidget.state.hovered = Axios._widgetState(thisWidget, "hovered", nil)
            end
        end,
        Update = function(thisWidget: Types.PlotLines)
            local PlotLines = thisWidget.Instance :: Frame
            local TextLabel: TextLabel = PlotLines.TextLabel
            local Background = PlotLines.Background :: Frame
            local Plot = Background.Plot :: Frame
            local OverlayText: TextLabel = Plot.OverlayText

            TextLabel.Text = thisWidget.arguments.Text or "Plot Lines"
            OverlayText.Text = thisWidget.arguments.TextOverlay or ""
            PlotLines.Size = UDim2.new(1, 0, 0, thisWidget.arguments.Height or 0)
        end,
        UpdateState = function(thisWidget: Types.PlotLines)
            if thisWidget.state.hovered.lastChangeTick == Axios._cycleTick then
                if thisWidget.state.hovered.value then
                    thisWidget.Tooltip.Visible = true
                else
                    thisWidget.Tooltip.Visible = false
                end
            end

            if thisWidget.state.values.lastChangeTick == Axios._cycleTick then
                local PlotLines = thisWidget.Instance :: Frame
                local Background = PlotLines.Background :: Frame
                local Plot = Background.Plot :: Frame

                local values = thisWidget.state.values.value
                local count = #values - 1
                local numLines = #thisWidget.Lines

                local min = thisWidget.arguments.Min or math.huge
                local max = thisWidget.arguments.Max or -math.huge

                if min == nil or max == nil then
                    for _, value in values do
                        min = math.min(min, value)
                        max = math.max(max, value)
                    end
                end

                -- add or remove blocks depending on how many are needed
                if numLines < count then
                    for index = numLines + 1, count do
                        table.insert(thisWidget.Lines, createLine(Plot, index))
                    end
                elseif numLines > count then
                    for _ = count + 1, numLines do
                        local line = table.remove(thisWidget.Lines)
                        if line then
                            line:Destroy()
                        end
                    end
                end

                local range = max - min
                local size = Plot.AbsoluteSize
                
                for index = 1, count do
                    local start = values[index]
                    local stop = values[index + 1]
                    local a = size * Vector2.new((index - 1) / count, (max - start) / range)
                    local b = size * Vector2.new(index / count, (max - stop) / range)
                    local position = (a + b) / 2

                    thisWidget.Lines[index].Size = UDim2.fromOffset((b - a).Magnitude + 1, 1)
                    thisWidget.Lines[index].Position = UDim2.fromOffset(position.X, position.Y)
                    thisWidget.Lines[index].Rotation = math.atan2(b.Y - a.Y, b.X - a.X) * (180 / math.pi)
                end

                -- only update the hovered block if it exists.
                if thisWidget.HoveredLine then
                    updateLine(thisWidget, true)
                end
            end
        end,
        Discard = function(thisWidget: Types.PlotLines)
            thisWidget.Instance:Destroy()
            thisWidget.Tooltip:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)

    local function createBlock(parent: Frame, index: number)
        local Block = Instance.new("Frame")
        Block.Name = tostring(index)
        Block.BackgroundColor3 = Axios._config.PlotHistogramColor
        Block.BackgroundTransparency = Axios._config.PlotHistogramTransparency
        Block.BorderSizePixel = 0

        Block.Parent = parent

        return Block
    end

    local function clearBlock(thisWidget: Types.PlotHistogram)
        if thisWidget.HoveredBlock then
            thisWidget.HoveredBlock.BackgroundColor3 = Axios._config.PlotHistogramColor
            thisWidget.HoveredBlock.BackgroundTransparency = Axios._config.PlotHistogramTransparency
            thisWidget.HoveredBlock = false
            thisWidget.state.hovered:set(nil)
        end
    end

    local function updateBlock(thisWidget: Types.PlotHistogram, silent: true?)
        local PlotHistogram = thisWidget.Instance :: Frame
        local Background = PlotHistogram.Background :: Frame
        local Plot = Background.Plot :: Frame

        local mousePosition = widgets.getMouseLocation()

        local position = Plot.AbsolutePosition - widgets.GuiOffset
        local scale = (mousePosition.X - position.X) / Plot.AbsoluteSize.X
        local index = math.ceil(scale * #thisWidget.Blocks)
        local block: Frame? = thisWidget.Blocks[index]

        if block then
            if block ~= thisWidget.HoveredBlock and not silent then
                clearBlock(thisWidget)
            end
            local value: number? = thisWidget.state.values.value[index]
            if value then
                thisWidget.Tooltip.Text = if math.floor(value) == value then ("%d: %d"):format(index, value) else ("%d: %.3f"):format(index, value)
            end
            thisWidget.HoveredBlock = block
            block.BackgroundColor3 = Axios._config.PlotHistogramHoveredColor
            block.BackgroundTransparency = Axios._config.PlotHistogramHoveredTransparency
            if silent then
                thisWidget.state.hovered.value = value
            else
                thisWidget.state.hovered:set(value)
            end
        end
    end

    -- stylua: ignore
    Axios.WidgetConstructor("PlotHistogram", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Height"] = 2,
            ["Min"] = 3,
            ["Max"] = 4,
            ["TextOverlay"] = 5,
            ["BaseLine"] = 6,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.PlotHistogram)
            local PlotHistogram = Instance.new("Frame")
            PlotHistogram.Name = "Axios_PlotHistogram"
            PlotHistogram.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            PlotHistogram.BackgroundTransparency = 1
            PlotHistogram.BorderSizePixel = 0

            widgets.UIListLayout(PlotHistogram, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local Background = Instance.new("Frame")
            Background.Name = "Background"
            Background.Size = UDim2.new(Axios._config.ContentWidth, UDim.new(1, 0))
            Background.BackgroundColor3 = Axios._config.FrameBgColor
            Background.BackgroundTransparency = Axios._config.FrameBgTransparency
            widgets.applyFrameStyle(Background)
            
            local UIPadding = (Background :: any).UIPadding
            UIPadding.PaddingRight = UDim.new(0, Axios._config.FramePadding.X - 1)

            Background.Parent = PlotHistogram

            local Plot = Instance.new("Frame")
            Plot.Name = "Plot"
            Plot.Size = UDim2.fromScale(1, 1)
            Plot.BackgroundTransparency = 1
            Plot.BorderSizePixel = 0
            Plot.ClipsDescendants = true

            local OverlayText = Instance.new("TextLabel")
            OverlayText.Name = "OverlayText"
            OverlayText.AutomaticSize = Enum.AutomaticSize.XY
            OverlayText.AnchorPoint = Vector2.new(0.5, 0)
            OverlayText.Size = UDim2.fromOffset(0, 0)
            OverlayText.Position = UDim2.fromScale(0.5, 0)
            OverlayText.BackgroundTransparency = 1
            OverlayText.BorderSizePixel = 0
            OverlayText.ZIndex = 2
            
            widgets.applyTextStyle(OverlayText)

            OverlayText.Parent = Plot

            local Tooltip = Instance.new("TextLabel")
            Tooltip.Name = "Axios_Tooltip"
            Tooltip.AutomaticSize = Enum.AutomaticSize.XY
            Tooltip.Size = UDim2.fromOffset(0, 0)
            Tooltip.BackgroundColor3 = Axios._config.PopupBgColor
            Tooltip.BackgroundTransparency = Axios._config.PopupBgTransparency
            Tooltip.BorderSizePixel = 0
            Tooltip.Visible = false

            widgets.applyTextStyle(Tooltip)
            widgets.UIStroke(Tooltip, Axios._config.PopupBorderSize, Axios._config.BorderActiveColor, Axios._config.BorderActiveTransparency)
            widgets.UIPadding(Tooltip, Axios._config.WindowPadding)
            if Axios._config.PopupRounding > 0 then
                widgets.UICorner(Tooltip, Axios._config.PopupRounding)
            end

            local popup = Axios._rootInstance and Axios._rootInstance:FindFirstChild("PopupScreenGui")
            Tooltip.Parent = popup and popup:FindFirstChild("TooltipContainer")

            thisWidget.Tooltip = Tooltip

            widgets.applyMouseMoved(Plot, function()
                updateBlock(thisWidget)
            end)

            widgets.applyMouseLeave(Plot, function()
                clearBlock(thisWidget)
            end)

            Plot.Parent = Background

            thisWidget.Blocks = {}
            thisWidget.HoveredBlock = false

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.Size = UDim2.fromOffset(0, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.ZIndex = 3
            TextLabel.LayoutOrder = 3

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = PlotHistogram

            return PlotHistogram
        end,
        GenerateState = function(thisWidget: Types.PlotHistogram)
            if thisWidget.state.values == nil then
                thisWidget.state.values = Axios._widgetState(thisWidget, "values", { 1 })
            end     
            if thisWidget.state.hovered == nil then
                thisWidget.state.hovered = Axios._widgetState(thisWidget, "hovered", nil)
            end     
        end,
        Update = function(thisWidget: Types.PlotHistogram)
            local PlotLines = thisWidget.Instance :: Frame
            local TextLabel: TextLabel = PlotLines.TextLabel
            local Background = PlotLines.Background :: Frame
            local Plot = Background.Plot :: Frame
            local OverlayText: TextLabel = Plot.OverlayText

            TextLabel.Text = thisWidget.arguments.Text or "Plot Histogram"
            OverlayText.Text = thisWidget.arguments.TextOverlay or ""
            PlotLines.Size = UDim2.new(1, 0, 0, thisWidget.arguments.Height or 0)
        end,
        UpdateState = function(thisWidget: Types.PlotHistogram)
            if thisWidget.state.hovered.lastChangeTick == Axios._cycleTick then
                if thisWidget.state.hovered.value then
                    thisWidget.Tooltip.Visible = true
                else
                    thisWidget.Tooltip.Visible = false
                end
            end

            if thisWidget.state.values.lastChangeTick == Axios._cycleTick then
                local PlotHistogram = thisWidget.Instance :: Frame
                local Background = PlotHistogram.Background :: Frame
                local Plot = Background.Plot :: Frame

                local values = thisWidget.state.values.value
                local count = #values
                local numBlocks = #thisWidget.Blocks

                local min = thisWidget.arguments.Min or math.huge
                local max = thisWidget.arguments.Max or -math.huge
                local baseline = thisWidget.arguments.BaseLine or 0

                if min == nil or max == nil then
                    for _, value in values do
                        min = math.min(min or value, value)
                        max = math.max(max or value, value)
                    end
                end

                -- add or remove blocks depending on how many are needed
                if numBlocks < count then
                    for index = numBlocks + 1, count do
                        table.insert(thisWidget.Blocks, createBlock(Plot, index))                    
                    end
                elseif numBlocks > count then
                    for _ = count + 1, numBlocks do
                        local block= table.remove(thisWidget.Blocks)
                        if block then
                            block:Destroy()
                        end
                    end
                end
                
                local range = max - min
                local width = UDim.new(1 / count, -1)
                for index = 1, count do
                    local num = values[index]
                    if num >= 0 then
                        thisWidget.Blocks[index].Size = UDim2.new(width, UDim.new((num - baseline) / range))
                        thisWidget.Blocks[index].Position = UDim2.fromScale((index - 1) / count, (max - num) / range)
                    else
                        thisWidget.Blocks[index].Size = UDim2.new(width, UDim.new((baseline - num) / range))
                        thisWidget.Blocks[index].Position = UDim2.fromScale((index - 1) / count, (max - baseline) / range)
                    end
                end

                -- only update the hovered block if it exists.
                if thisWidget.HoveredBlock then
                    updateBlock(thisWidget, true)
                end
            end
        end,
        Discard = function(thisWidget: Types.PlotHistogram)
            thisWidget.Instance:Destroy()
            thisWidget.Tooltip:Destroy()
            widgets.discardState(thisWidget)            
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.RadioButton"] = function()
    local script = create_mock_script("Axios.widgets.RadioButton")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    --stylua: ignore
    Axios.WidgetConstructor("RadioButton", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Index"] = 2,
        },
        Events = {
            ["selected"] = {
                ["Init"] = function(_thisWidget: Types.RadioButton) end,
                ["Get"] = function(thisWidget: Types.RadioButton)
                    return thisWidget.lastSelectedTick == Axios._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget: Types.RadioButton) end,
                ["Get"] = function(thisWidget: Types.RadioButton)
                    return thisWidget.lastUnselectedTick == Axios._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget: Types.RadioButton) end,
                ["Get"] = function(thisWidget: Types.RadioButton)
                    return thisWidget.state.index.value == thisWidget.arguments.Index
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.RadioButton)
            local RadioButton = Instance.new("TextButton")
            RadioButton.Name = "Axios_RadioButton"
            RadioButton.AutomaticSize = Enum.AutomaticSize.XY
            RadioButton.Size = UDim2.fromOffset(0, 0)
            RadioButton.BackgroundTransparency = 1
            RadioButton.BorderSizePixel = 0
            RadioButton.Text = ""
            RadioButton.AutoButtonColor = false

            widgets.UIListLayout(RadioButton, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local buttonSize = Axios._config.TextSize + 2 * (Axios._config.FramePadding.Y - 1)
            local Button = Instance.new("Frame")
            Button.Name = "Button"
            Button.Size = UDim2.fromOffset(buttonSize, buttonSize)
            Button.BackgroundColor3 = Axios._config.FrameBgColor
            Button.BackgroundTransparency = Axios._config.FrameBgTransparency
            Button.Parent = RadioButton

            widgets.UICorner(Button)
            widgets.UIPadding(Button, Vector2.new(math.max(1, math.floor(buttonSize / 5)), math.max(1, math.floor(buttonSize / 5))))

            local Circle = Instance.new("Frame")
            Circle.Name = "Circle"
            Circle.Size = UDim2.fromScale(1, 1)
            Circle.BackgroundColor3 = Axios._config.CheckMarkColor
            Circle.BackgroundTransparency = Axios._config.CheckMarkTransparency
            widgets.UICorner(Circle)
            
            Circle.Parent = Button

            widgets.applyInteractionHighlights("Background", RadioButton, Button, {
                Color = Axios._config.FrameBgColor,
                Transparency = Axios._config.FrameBgTransparency,
                HoveredColor = Axios._config.FrameBgHoveredColor,
                HoveredTransparency = Axios._config.FrameBgHoveredTransparency,
                ActiveColor = Axios._config.FrameBgActiveColor,
                ActiveTransparency = Axios._config.FrameBgActiveTransparency,
            })

            widgets.applyButtonClick(RadioButton, function()
                thisWidget.state.index:set(thisWidget.arguments.Index)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1
            
            widgets.applyTextStyle(TextLabel)
            TextLabel.Parent = RadioButton

            return RadioButton
        end,
        Update = function(thisWidget: Types.RadioButton)
            local RadioButton = thisWidget.Instance :: TextButton
            local TextLabel: TextLabel = RadioButton.TextLabel

            TextLabel.Text = thisWidget.arguments.Text or "Radio Button"
            if thisWidget.state then
                thisWidget.state.index.lastChangeTick = Axios._cycleTick
                Axios._widgets[thisWidget.type].UpdateState(thisWidget)
            end
        end,
        Discard = function(thisWidget: Types.RadioButton)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
        GenerateState = function(thisWidget: Types.RadioButton)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Axios._widgetState(thisWidget, "index", thisWidget.arguments.Index)
            end
        end,
        UpdateState = function(thisWidget: Types.RadioButton)
            local RadioButton = thisWidget.Instance :: TextButton
            local Button = RadioButton.Button :: Frame
            local Circle: Frame = Button.Circle

            if thisWidget.state.index.value == thisWidget.arguments.Index then
                -- only need to hide the circle
                Circle.BackgroundTransparency = Axios._config.CheckMarkTransparency
                thisWidget.lastSelectedTick = Axios._cycleTick + 1
            else
                Circle.BackgroundTransparency = 1
                thisWidget.lastUnselectedTick = Axios._cycleTick + 1
            end
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Root"] = function()
    local script = create_mock_script("Axios.widgets.Root")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local NumNonWindowChildren: number = 0

    --stylua: ignore
    Axios.WidgetConstructor("Root", {
        hasState = false,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(_thisWidget: Types.Root)
            local Root = Instance.new("Folder")
            Root.Name = "Axios_Root"

            local PseudoWindowScreenGui
            if Axios._config.UseScreenGUIs then
                PseudoWindowScreenGui = Instance.new("ScreenGui")
                PseudoWindowScreenGui.ResetOnSpawn = false
                PseudoWindowScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                PseudoWindowScreenGui.ScreenInsets = Axios._config.ScreenInsets
                PseudoWindowScreenGui.IgnoreGuiInset = Axios._config.IgnoreGuiInset
                PseudoWindowScreenGui.DisplayOrder = Axios._config.DisplayOrderOffset
            else
                PseudoWindowScreenGui = Instance.new("Frame")
                PseudoWindowScreenGui.AnchorPoint = Vector2.new(0.5, 0.5)
                PseudoWindowScreenGui.Position = UDim2.fromScale(0.5, 0.5)
                PseudoWindowScreenGui.Size = UDim2.fromScale(1, 1)
                PseudoWindowScreenGui.BackgroundTransparency = 1
                PseudoWindowScreenGui.ZIndex = Axios._config.DisplayOrderOffset
            end
            PseudoWindowScreenGui.Name = "PseudoWindowScreenGui"
            PseudoWindowScreenGui.Parent = Root

            local PopupScreenGui
            if Axios._config.UseScreenGUIs then
                PopupScreenGui = Instance.new("ScreenGui")
                PopupScreenGui.ResetOnSpawn = false
                PopupScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                PopupScreenGui.DisplayOrder = Axios._config.DisplayOrderOffset + 1024 -- room for 1024 regular windows before overlap
                PopupScreenGui.ScreenInsets = Axios._config.ScreenInsets
                PopupScreenGui.IgnoreGuiInset = Axios._config.IgnoreGuiInset
            else
                PopupScreenGui = Instance.new("Frame")
                PopupScreenGui.AnchorPoint = Vector2.new(0.5, 0.5)
                PopupScreenGui.Position = UDim2.fromScale(0.5, 0.5)
                PopupScreenGui.Size = UDim2.fromScale(1, 1)
                PopupScreenGui.BackgroundTransparency = 1
                PopupScreenGui.ZIndex = Axios._config.DisplayOrderOffset + 1024
            end
            PopupScreenGui.Name = "PopupScreenGui"
            PopupScreenGui.Parent = Root

            local TooltipContainer = Instance.new("Frame")
            TooltipContainer.Name = "TooltipContainer"
            TooltipContainer.AutomaticSize = Enum.AutomaticSize.XY
            TooltipContainer.Size = UDim2.fromOffset(0, 0)
            TooltipContainer.BackgroundTransparency = 1
            TooltipContainer.BorderSizePixel = 0

            widgets.UIListLayout(TooltipContainer, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.PopupBorderSize))

            TooltipContainer.Parent = PopupScreenGui

            local MenuBarContainer = Instance.new("Frame")
            MenuBarContainer.Name = "MenuBarContainer"
            MenuBarContainer.AutomaticSize = Enum.AutomaticSize.Y
            MenuBarContainer.Size = UDim2.fromScale(1, 0)
            MenuBarContainer.BackgroundTransparency = 1
            MenuBarContainer.BorderSizePixel = 0

            MenuBarContainer.Parent = PopupScreenGui

            local PseudoWindow = Instance.new("Frame")
            PseudoWindow.Name = "PseudoWindow"
            PseudoWindow.AutomaticSize = Enum.AutomaticSize.XY
            PseudoWindow.Size = UDim2.new(0, 0, 0, 0)
            PseudoWindow.Position = UDim2.fromOffset(0, 22)
            PseudoWindow.BackgroundTransparency = Axios._config.WindowBgTransparency
            PseudoWindow.BackgroundColor3 = Axios._config.WindowBgColor
            PseudoWindow.BorderSizePixel = Axios._config.WindowBorderSize
            PseudoWindow.BorderColor3 = Axios._config.BorderColor

            PseudoWindow.Selectable = false
            PseudoWindow.SelectionGroup = true
            PseudoWindow.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
            PseudoWindow.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
            PseudoWindow.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
            PseudoWindow.SelectionBehaviorRight = Enum.SelectionBehavior.Stop

            PseudoWindow.Visible = false

            widgets.UIPadding(PseudoWindow, Axios._config.WindowPadding)
            widgets.UIListLayout(PseudoWindow, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))

            PseudoWindow.Parent = PseudoWindowScreenGui

            return Root
        end,
        Update = function(thisWidget: Types.Root)
            if NumNonWindowChildren > 0 then
                local Root = thisWidget.Instance :: any
                local PseudoWindowScreenGui = Root.PseudoWindowScreenGui :: any
                local PseudoWindow: Frame = PseudoWindowScreenGui.PseudoWindow
                PseudoWindow.Visible = true
            end
        end,
        Discard = function(thisWidget: Types.Root)
            NumNonWindowChildren = 0
            thisWidget.Instance:Destroy()
        end,
        ChildAdded = function(thisWidget: Types.Root, thisChild: Types.Widget)
            local Root = thisWidget.Instance :: any

            if thisChild.type == "Window" then
                return thisWidget.Instance
            elseif thisChild.type == "Tooltip" then
                return Root.PopupScreenGui.TooltipContainer
            elseif thisChild.type == "MenuBar" then
                return Root.PopupScreenGui.MenuBarContainer
            else
                local PseudoWindowScreenGui = Root.PseudoWindowScreenGui :: any
                local PseudoWindow: Frame = PseudoWindowScreenGui.PseudoWindow

                NumNonWindowChildren += 1
                PseudoWindow.Visible = true

                return PseudoWindow
            end
        end,
        ChildDiscarded = function(thisWidget: Types.Root, thisChild: Types.Widget)
            if thisChild.type ~= "Window" and thisChild.type ~= "Tooltip" and thisChild.type ~= "MenuBar" then
                NumNonWindowChildren -= 1
                if NumNonWindowChildren == 0 then
                    local Root = thisWidget.Instance :: any
                    local PseudoWindowScreenGui = Root.PseudoWindowScreenGui :: any
                    local PseudoWindow: Frame = PseudoWindowScreenGui.PseudoWindow
                    PseudoWindow.Visible = false
                end
            end
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Tab"] = function()
    local script = create_mock_script("Axios.widgets.Tab")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local function openTab(TabBar: Types.TabBar, Index: number)
        if TabBar.state.index.value > 0 then
            return
        end

        TabBar.state.index:set(Index)
    end

    local function closeTab(TabBar: Types.TabBar, Index: number)
        if TabBar.state.index.value ~= Index then
            return
        end

        -- search left for open tabs
        for i = Index - 1, 1, -1 do
            if TabBar.Tabs[i].state.isOpened.value == true then
                TabBar.state.index:set(i)
                return
            end
        end

        -- search right for open tabs
        for i = Index, #TabBar.Tabs do
            if TabBar.Tabs[i].state.isOpened.value == true then
                TabBar.state.index:set(i)
                return
            end
        end

        -- no open tabs, so wait for one
        TabBar.state.index:set(0)
    end

    --stylua: ignore
    Axios.WidgetConstructor("TabBar", {
        hasState = true,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(thisWidget: Types.TabBar)
            local TabBar = Instance.new("Frame")
            TabBar.Name = "Axios_TabBar"
            TabBar.AutomaticSize = Enum.AutomaticSize.Y
            TabBar.Size = UDim2.fromScale(1, 0)
            TabBar.BackgroundTransparency = 1
            TabBar.BorderSizePixel = 0

            widgets.UIListLayout(TabBar, Enum.FillDirection.Vertical, UDim.new()).VerticalAlignment = Enum.VerticalAlignment.Bottom
            
            local Bar = Instance.new("Frame")
            Bar.Name = "Bar"
            Bar.AutomaticSize = Enum.AutomaticSize.Y
            Bar.Size = UDim2.fromScale(1, 0)
            Bar.BackgroundTransparency = 1
            Bar.BorderSizePixel = 0
            
            widgets.UIListLayout(Bar, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X))

            Bar.Parent = TabBar

            local Underline = Instance.new("Frame")
            Underline.Name = "Underline"
            Underline.Size = UDim2.new(1, 0, 0, 1)
            Underline.BackgroundColor3 = Axios._config.TabActiveColor
            Underline.BackgroundTransparency = Axios._config.TabActiveTransparency
            Underline.BorderSizePixel = 0
            Underline.LayoutOrder = 1

            Underline.Parent = TabBar

            local ChildContainer = Instance.new("Frame")
            ChildContainer.Name = "TabContainer"
            ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
            ChildContainer.Size = UDim2.fromScale(1, 0)
            ChildContainer.BackgroundTransparency = 1
            ChildContainer.BorderSizePixel = 0
            ChildContainer.LayoutOrder = 2
            ChildContainer.ClipsDescendants = true

            ChildContainer.Parent = TabBar

            thisWidget.ChildContainer = ChildContainer
            thisWidget.Tabs = {}

            return TabBar
        end,
        Update = function(_thisWidget: Types.TabBar) end,
        ChildAdded = function(thisWidget: Types.TabBar, thisChild: Types.Tab)
            assert(thisChild.type == "Tab", "Only Axios.Tab can be parented to Axios.TabBar.")
            local TabBar = thisWidget.Instance :: Frame
            thisChild.ChildContainer.Parent = thisWidget.ChildContainer
            thisChild.Index = #thisWidget.Tabs + 1
            thisWidget.state.index.ConnectedWidgets[thisChild.ID] = thisChild
            table.insert(thisWidget.Tabs, thisChild)

            return TabBar.Bar
        end,
        ChildDiscarded = function(thisWidget: Types.TabBar, thisChild: Types.Tab)
            local Index = thisChild.Index
            table.remove(thisWidget.Tabs, Index)

            for i = Index, #thisWidget.Tabs do
                thisWidget.Tabs[i].Index = i
            end

            closeTab(thisWidget, Index)
        end,
        GenerateState = function(thisWidget: Types.Tab)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Axios._widgetState(thisWidget, "index", 1)
            end
        end,
        UpdateState = function(_thisWidget: Types.Tab)
        end,
        Discard = function(thisWidget: Types.TabBar)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("Tab", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
            ["Hideable"] = 2,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
            ["selected"] = {
                ["Init"] = function(_thisWidget: Types.Tab) end,
                ["Get"] = function(thisWidget: Types.Tab)
                    return thisWidget.lastSelectedTick == Axios._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget: Types.Tab) end,
                ["Get"] = function(thisWidget: Types.Tab)
                    return thisWidget.lastUnselectedTick == Axios._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget: Types.Tab) end,
                ["Get"] = function(thisWidget: Types.Tab)
                    return thisWidget.state.index.value == thisWidget.Index
                end,
            },
            ["opened"] = {
                ["Init"] = function(_thisWidget: Types.Tab) end,
                ["Get"] = function(thisWidget: Types.Tab)
                    return thisWidget.lastOpenedTick == Axios._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget: Types.Tab) end,
                ["Get"] = function(thisWidget: Types.Tab)
                    return thisWidget.lastClosedTick == Axios._cycleTick
                end,
            },
        },
        Generate = function(thisWidget: Types.Tab)
            local Tab = Instance.new("TextButton")
            Tab.Name = "Axios_Tab"
            Tab.AutomaticSize = Enum.AutomaticSize.XY
            Tab.BackgroundColor3 = Axios._config.TabColor
            Tab.BackgroundTransparency = Axios._config.TabTransparency
            Tab.BorderSizePixel = 0
            Tab.Text = ""
            Tab.AutoButtonColor = false

            thisWidget.ButtonColors = {
                Color = Axios._config.TabColor,
                Transparency = Axios._config.TabTransparency,
                HoveredColor = Axios._config.TabHoveredColor,
                HoveredTransparency = Axios._config.TabHoveredTransparency,
                ActiveColor = Axios._config.TabActiveColor,
                ActiveTransparency = Axios._config.TabActiveTransparency,
            }

            widgets.UIPadding(Tab, Vector2.new(Axios._config.FramePadding.X, 0))
            widgets.applyFrameStyle(Tab, true, true)
            widgets.UIListLayout(Tab, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center
            widgets.applyInteractionHighlights("Background", Tab, Tab, thisWidget.ButtonColors)
            widgets.applyButtonClick(Tab, function()
                thisWidget.state.index:set(thisWidget.Index)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)
            widgets.UIPadding(TextLabel, Vector2.new(0, Axios._config.FramePadding.Y))

            TextLabel.Parent = Tab

            local ButtonSize = Axios._config.TextSize + ((Axios._config.FramePadding.Y - 1) * 2)

            local CloseButton = Instance.new("TextButton")
            CloseButton.Name = "CloseButton"
            CloseButton.Size = UDim2.fromOffset(ButtonSize, ButtonSize)
            CloseButton.BackgroundTransparency = 1
            CloseButton.BorderSizePixel = 0
            CloseButton.Text = ""
            CloseButton.AutoButtonColor = false
            CloseButton.LayoutOrder = 1

            widgets.UICorner(CloseButton)
            widgets.applyButtonClick(CloseButton, function()
                thisWidget.state.isOpened:set(false)
                closeTab(thisWidget.parentWidget, thisWidget.Index)
            end)

            widgets.applyInteractionHighlights("Background", CloseButton, CloseButton, {
                Color = Axios._config.TabColor,
                Transparency = 1,
                HoveredColor = Axios._config.ButtonHoveredColor,
                HoveredTransparency = Axios._config.ButtonHoveredTransparency,
                ActiveColor = Axios._config.ButtonActiveColor,
                ActiveTransparency = Axios._config.ButtonActiveTransparency,
            })

            CloseButton.Parent = Tab

            local Icon = Instance.new("ImageLabel")
            Icon.Name = "Icon"
            Icon.AnchorPoint = Vector2.new(0.5, 0.5)
            Icon.Position = UDim2.fromScale(0.5, 0.5)
            Icon.Size = UDim2.fromOffset(math.floor(0.7 * ButtonSize), math.floor(0.7 * ButtonSize))
            Icon.BackgroundTransparency = 1
            Icon.BorderSizePixel = 0
            Icon.Image = widgets.ICONS.MULTIPLICATION_SIGN
            Icon.ImageTransparency = 1

            widgets.applyInteractionHighlights("Image", Tab, Icon, {
                Color = Axios._config.TextColor,
                Transparency = 1,
                HoveredColor = Axios._config.TextColor,
                HoveredTransparency = Axios._config.TextTransparency,
                ActiveColor = Axios._config.TextColor,
                ActiveTransparency = Axios._config.TextTransparency,
            })
            Icon.Parent = CloseButton

            local ChildContainer = Instance.new("Frame")
            ChildContainer.Name = "TabContainer"
            ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
            ChildContainer.Size = UDim2.fromScale(1, 0)
            ChildContainer.BackgroundTransparency = 1
            ChildContainer.BorderSizePixel = 0
            
            ChildContainer.ClipsDescendants = true
            widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))
            widgets.UIPadding(ChildContainer, Vector2.new(0, Axios._config.ItemSpacing.Y)).PaddingBottom = UDim.new()

            thisWidget.ChildContainer = ChildContainer

            return Tab
        end,
        Update = function(thisWidget: Types.Tab)
            local Tab = thisWidget.Instance :: TextButton
            local TextLabel: TextLabel = Tab.TextLabel
            local CloseButton: TextButton = Tab.CloseButton

            TextLabel.Text = thisWidget.arguments.Text
            CloseButton.Visible = if thisWidget.arguments.Hideable == true then true else false
        end,
        ChildAdded = function(thisWidget: Types.Tab, _thisChild: Types.Widget)
            return thisWidget.ChildContainer
        end,
        GenerateState = function(thisWidget: Types.Tab)
            thisWidget.state.index = thisWidget.parentWidget.state.index
            thisWidget.state.index.ConnectedWidgets[thisWidget.ID] = thisWidget

            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Axios._widgetState(thisWidget, "isOpened", true)
            end
        end,
        UpdateState = function(thisWidget: Types.Tab)
            local Tab = thisWidget.Instance :: TextButton
            local Container = thisWidget.ChildContainer :: Frame

            if thisWidget.state.isOpened.lastChangeTick == Axios._cycleTick then
                if thisWidget.state.isOpened.value == true then
                    thisWidget.lastOpenedTick = Axios._cycleTick + 1
                    openTab(thisWidget.parentWidget, thisWidget.Index)
                    Tab.Visible = true
                else
                    thisWidget.lastClosedTick = Axios._cycleTick + 1
                    closeTab(thisWidget.parentWidget, thisWidget.Index)
                    Tab.Visible = false
                end
            end

            if thisWidget.state.index.lastChangeTick == Axios._cycleTick then
                if thisWidget.state.index.value == thisWidget.Index then
                    thisWidget.ButtonColors.Color = Axios._config.TabActiveColor
                    thisWidget.ButtonColors.Transparency = Axios._config.TabActiveTransparency
            Tab.BackgroundColor3 = Axios._config.TabActiveColor
                    Tab.BackgroundTransparency = Axios._config.TabActiveTransparency
                    Container.Visible = true
                    thisWidget.lastSelectedTick = Axios._cycleTick + 1
                else
                    thisWidget.ButtonColors.Color = Axios._config.TabColor
                    thisWidget.ButtonColors.Transparency = Axios._config.TabTransparency
                    Tab.BackgroundColor3 = Axios._config.TabColor
                    Tab.BackgroundTransparency = Axios._config.TabTransparency
                    Container.Visible = false
                    thisWidget.lastUnselectedTick = Axios._cycleTick + 1
                end
            end
        end,
        Discard = function(thisWidget: Types.Tab)
            if thisWidget.state.isOpened.value == true then
                closeTab(thisWidget.parentWidget, thisWidget.Index)
            end
            
            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Table"] = function()
    local script = create_mock_script("Axios.widgets.Table")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

-- Tables need an overhaul.

--[[
	Axios.Table(
		{
			NumColumns,
			Header,
			RowBackground,
			OuterBorders,
			InnerBorders
		}
	)

	Config = {
		CellPadding: Vector2,
		CellSize: UDim2,
	}

	Axios.NextColumn()
	Axios.NextRow()
	Axios.SetColumnIndex(index: number)
	Axios.SetRowIndex(index: number)

	Axios.NextHeaderColumn()
	Axios.SetHeaderColumnIndex(index: number)

	Axios.SetColumnWidth(index: number, width: number | UDim)
]]

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local Tables: { [Types.ID]: Types.Table } = {}
    local TableMinWidths: { [Types.Table]: { boolean } } = {}
    local AnyActiveTable = false
    local ActiveTable: Types.Table? = nil
    local ActiveColumn = 0
    local ActiveLeftWidth = -1
    local ActiveRightWidth = -1
    local MousePositionX = 0

    local function CalculateMinColumnWidth(thisWidget: Types.Table, index: number)
        local width = 0
        for _, row in thisWidget._cellInstances do
            local cell = row[index]
            for _, child in cell:GetChildren() do
                if child:IsA("GuiObject") then
                    width = math.max(width, child.AbsoluteSize.X)
                end
            end
        end

        thisWidget._minWidths[index] = width + 2 * Axios._config.CellPadding.X
    end

    table.insert(Axios._postCycleCallbacks, function()
        for _, thisWidget in Tables do
            for rowIndex, cycleTick in thisWidget._rowCycles do
                if cycleTick < Axios._cycleTick - 1 then
                    local Row = thisWidget._rowInstances[rowIndex]
                    local RowBorder = thisWidget._rowBorders[rowIndex - 1]
                    if Row ~= nil then
                        Row:Destroy()
                    end
                    if RowBorder ~= nil then
                        RowBorder:Destroy()
                    end
                    thisWidget._rowInstances[rowIndex] = nil
                    thisWidget._rowBorders[rowIndex - 1] = nil
                    thisWidget._cellInstances[rowIndex] = nil
                    thisWidget._rowCycles[rowIndex] = nil
                end
            end

            thisWidget._rowIndex = 1
            thisWidget._columnIndex = 1

            -- update the border container size to be the same, albeit *every* frame!
            local Table = thisWidget.Instance :: Frame
            local BorderContainer: Frame = Table.BorderContainer
            BorderContainer.Size = UDim2.new(1, 0, 0, thisWidget._rowContainer.AbsoluteSize.Y)
            thisWidget._columnBorders[0].Size = UDim2.fromOffset(5, thisWidget._rowContainer.AbsoluteSize.Y)
        end

        for thisWidget, columns in TableMinWidths do
            local refresh = false
            for column, _ in columns do
                CalculateMinColumnWidth(thisWidget, column)
                refresh = true
            end
            if refresh then
                table.clear(columns)
                Axios._widgets["Table"].UpdateState(thisWidget)
            end
        end
    end)

    local function UpdateActiveColumn()
        if AnyActiveTable == false or ActiveTable == nil then
            return
        end

        local widths = ActiveTable.state.widths
        local NumColumns = ActiveTable.arguments.NumColumns
        local Table = ActiveTable.Instance :: Frame
        local BorderContainer = Table.BorderContainer :: Frame
        local Fixed = ActiveTable.arguments.FixedWidth
        local Padding = 2 * Axios._config.CellPadding.X

        if ActiveLeftWidth == -1 then
            ActiveLeftWidth = widths.value[ActiveColumn]
            if ActiveLeftWidth == 0 then
                ActiveLeftWidth = Padding / Table.AbsoluteSize.X
            end
            ActiveRightWidth = widths.value[ActiveColumn + 1] or -1
            if ActiveRightWidth == 0 then
                ActiveRightWidth = Padding / Table.AbsoluteSize.X
            end
        end

        local BorderX = Table.AbsolutePosition.X
        local LeftX: number -- the start of the current column
        -- local CurrentX: number = BorderContainer:FindFirstChild(`Border_{ActiveColumn}`).AbsolutePosition.X + 3 - BorderX -- the current column position
        local RightX: number -- the end of the next column
        if ActiveColumn == 1 then
            LeftX = 0
        else
            LeftX = math.floor(BorderContainer:FindFirstChild(`Border_{ActiveColumn - 1}`).AbsolutePosition.X + 3 - BorderX)
        end
        if ActiveColumn >= NumColumns - 1 then
            RightX = Table.AbsoluteSize.X
        else
            RightX = math.floor(BorderContainer:FindFirstChild(`Border_{ActiveColumn + 1}`).AbsolutePosition.X + 3 - BorderX)
        end

        local TableX: number = BorderX - widgets.GuiOffset.X
        local DeltaX: number = math.clamp(widgets.getMouseLocation().X, LeftX + TableX + Padding, RightX + TableX - Padding) - MousePositionX
        local LeftOffset = (MousePositionX - TableX) - LeftX
        local LeftRatio = ActiveLeftWidth / LeftOffset

        if Fixed then
            widths.value[ActiveColumn] = math.clamp(math.round(ActiveLeftWidth + DeltaX), Padding, Table.AbsoluteSize.X - LeftX)
        else
            local Change = LeftRatio * DeltaX
            widths.value[ActiveColumn] = math.clamp(ActiveLeftWidth + Change, 0, (RightX - LeftX - Padding) / Table.AbsoluteSize.X)
            if ActiveColumn < NumColumns then
                widths.value[ActiveColumn + 1] = math.clamp(ActiveRightWidth - Change, 0, 1)
            end
        end

        widths:set(widths.value, true)
    end

    local function ColumnMouseDown(thisWidget: Types.Table, index: number)
        AnyActiveTable = true
        ActiveTable = thisWidget
        ActiveColumn = index
        ActiveLeftWidth = -1
        ActiveRightWidth = -1
        MousePositionX = widgets.getMouseLocation().X
    end

    widgets.registerEvent("InputChanged", function()
        if not Axios._started then
            return
        end
        UpdateActiveColumn()
    end)

    widgets.registerEvent("InputEnded", function(inputObject: InputObject)
        if not Axios._started then
            return
        end
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveTable then
            AnyActiveTable = false
            ActiveTable = nil
            ActiveColumn = 0
            ActiveLeftWidth = -1
            ActiveRightWidth = -1
            MousePositionX = 0
        end
    end)

    local function GenerateCell(_thisWidget: Types.Table, index: number, width: UDim, header: boolean)
        local Cell: TextButton
        if header then
            Cell = Instance.new("TextButton")
            Cell.Text = ""
            Cell.AutoButtonColor = false
        else
            Cell = (Instance.new("Frame") :: GuiObject) :: TextButton
        end
        Cell.Name = `Cell_{index}`
        Cell.AutomaticSize = Enum.AutomaticSize.Y
        Cell.Size = UDim2.new(width, UDim.new())
        Cell.BackgroundTransparency = 1
        Cell.ZIndex = index
        Cell.LayoutOrder = index
        Cell.ClipsDescendants = true

        if header then
            widgets.applyInteractionHighlights("Background", Cell, Cell, {
                Color = Axios._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Axios._config.HeaderHoveredColor,
                HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                ActiveColor = Axios._config.HeaderActiveColor,
                ActiveTransparency = Axios._config.HeaderActiveTransparency,
            })
        end

        widgets.UIPadding(Cell, Axios._config.CellPadding)
        widgets.UIListLayout(Cell, Enum.FillDirection.Vertical, UDim.new())
        widgets.UISizeConstraint(Cell, Vector2.new(2 * Axios._config.CellPadding.X, 0))

        return Cell
    end

    local function GenerateColumnBorder(thisWidget: Types.Table, index: number, style: "Light" | "Strong")
        local Border = Instance.new("ImageButton")
        Border.Name = `Border_{index}`
        Border.Size = UDim2.new(0, 5, 1, 0)
        Border.BackgroundTransparency = 1
        Border.Image = ""
        Border.ImageTransparency = 1
        Border.AutoButtonColor = false
        Border.ZIndex = index
        Border.LayoutOrder = 2 * index

        local offset = if index == thisWidget.arguments.NumColumns then 3 else 2

        local Line = Instance.new("Frame")
        Line.Name = "Line"
        Line.Size = UDim2.new(0, 1, 1, 0)
        Line.Position = UDim2.fromOffset(offset, 0)
        Line.BackgroundColor3 = Axios._config[`TableBorder{style}Color`]
        Line.BackgroundTransparency = Axios._config[`TableBorder{style}Transparency`]
        Line.BorderSizePixel = 0

        Line.Parent = Border

        local Hover = Instance.new("Frame")
        Hover.Name = "Hover"
        Hover.Position = UDim2.fromOffset(offset, 0)
        Hover.Size = UDim2.new(0, 1, 1, 0)
        Hover.BackgroundColor3 = Axios._config[`TableBorder{style}Color`]
        Hover.BackgroundTransparency = Axios._config[`TableBorder{style}Transparency`]
        Hover.BorderSizePixel = 0

        Hover.Visible = thisWidget.arguments.Resizable

        Hover.Parent = Border

        widgets.applyInteractionHighlights("Background", Border, Hover, {
            Color = Axios._config.ResizeGripColor,
            Transparency = 1,
            HoveredColor = Axios._config.ResizeGripHoveredColor,
            HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
            ActiveColor = Axios._config.ResizeGripActiveColor,
            ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
        })

        widgets.applyButtonDown(Border, function()
            if thisWidget.arguments.Resizable then
                ColumnMouseDown(thisWidget, index)
            end
        end)

        return Border
    end

    -- creates a new row and all columns, and adds all to the table's row and cell instance tables, but does not parent
    local function GenerateRow(thisWidget: Types.Table, index: number)
        local Row: Frame = Instance.new("Frame")
        Row.Name = `Row_{index}`
        Row.AutomaticSize = Enum.AutomaticSize.Y
        Row.Size = UDim2.fromScale(1, 0)
        if index == 0 then
            Row.BackgroundColor3 = Axios._config.TableHeaderColor
            Row.BackgroundTransparency = Axios._config.TableHeaderTransparency
        elseif thisWidget.arguments.RowBackground == true then
            if (index % 2) == 0 then
                Row.BackgroundColor3 = Axios._config.TableRowBgAltColor
                Row.BackgroundTransparency = Axios._config.TableRowBgAltTransparency
            else
                Row.BackgroundColor3 = Axios._config.TableRowBgColor
                Row.BackgroundTransparency = Axios._config.TableRowBgTransparency
            end
        else
            Row.BackgroundTransparency = 1
        end
        Row.BorderSizePixel = 0
        Row.ZIndex = 2 * index - 1
        Row.LayoutOrder = 2 * index - 1
        Row.ClipsDescendants = true

        widgets.UIListLayout(Row, Enum.FillDirection.Horizontal, UDim.new())

        thisWidget._cellInstances[index] = table.create(thisWidget.arguments.NumColumns)
        for columnIndex = 1, thisWidget.arguments.NumColumns do
            local Cell = GenerateCell(thisWidget, columnIndex, thisWidget._widths[columnIndex], index == 0)
            Cell.Parent = Row
            thisWidget._cellInstances[index][columnIndex] = Cell
        end

        thisWidget._rowInstances[index] = Row

        return Row
    end

    local function GenerateRowBorder(_thisWidget: Types.Table, index: number, style: "Light" | "Strong")
        local Border = Instance.new("Frame")
        Border.Name = `Border_{index}`
        Border.Size = UDim2.fromScale(1, 0)
        Border.BackgroundTransparency = 1
        Border.ZIndex = 2 * index
        Border.LayoutOrder = 2 * index

        local Line = Instance.new("Frame")
        Line.Name = "Line"
        Line.AnchorPoint = Vector2.new(0, 0.5)
        Line.Size = UDim2.new(1, 0, 0, 1)
        Line.BackgroundColor3 = Axios._config[`TableBorder{style}Color`]
        Line.BackgroundTransparency = Axios._config[`TableBorder{style}Transparency`]
        Line.BorderSizePixel = 0

        Line.Parent = Border

        return Border
    end

    --stylua: ignore
    Axios.WidgetConstructor("Table", {
        hasState = true,
        hasChildren = true,
        Args = {
            NumColumns = 1,
            Header = 2,
            RowBackground = 3,
            OuterBorders = 4,
            InnerBorders = 5,
            Resizable = 6,
            FixedWidth = 7,
            ProportionalWidth = 8,
            LimitTableWidth = 9,
        },
        Events = {},
        Generate = function(thisWidget: Types.Table)
            Tables[thisWidget.ID] = thisWidget
            TableMinWidths[thisWidget] = {}

            local Table = Instance.new("Frame")
            Table.Name = "Axios_Table"
            Table.AutomaticSize = Enum.AutomaticSize.Y
            Table.Size = UDim2.fromScale(1, 0)
            Table.BackgroundTransparency = 1

            local RowContainer = Instance.new("Frame")
            RowContainer.Name = "RowContainer"
            RowContainer.AutomaticSize = Enum.AutomaticSize.Y
            RowContainer.Size = UDim2.fromScale(1, 0)
            RowContainer.BackgroundTransparency = 1
            RowContainer.ZIndex = 1

            widgets.UISizeConstraint(RowContainer)
            widgets.UIListLayout(RowContainer, Enum.FillDirection.Vertical, UDim.new())

            RowContainer.Parent = Table
			thisWidget._rowContainer = RowContainer

            local BorderContainer = Instance.new("Frame")
            BorderContainer.Name = "BorderContainer"
            BorderContainer.Size = UDim2.fromScale(1, 1)
            BorderContainer.BackgroundTransparency = 1
            BorderContainer.ZIndex = 2
            BorderContainer.ClipsDescendants = true

            widgets.UISizeConstraint(BorderContainer)            
            widgets.UIListLayout(BorderContainer, Enum.FillDirection.Horizontal, UDim.new())
            widgets.UIStroke(BorderContainer, 1, Axios._config.TableBorderStrongColor, Axios._config.TableBorderStrongTransparency)

            BorderContainer.Parent = Table

            thisWidget._columnIndex = 1
            thisWidget._rowIndex = 1
            thisWidget._rowInstances = {}
            thisWidget._cellInstances = {}
            thisWidget._rowBorders = {}
            thisWidget._columnBorders = {}
            thisWidget._rowCycles = {}

            local callbackIndex = #Axios._postCycleCallbacks + 1
            local desiredCycleTick = Axios._cycleTick + 1
            Axios._postCycleCallbacks[callbackIndex] = function()
                if Axios._cycleTick >= desiredCycleTick then
                    if thisWidget.lastCycleTick ~= -1 then
                        thisWidget.state.widths.lastChangeTick = Axios._cycleTick
                        Axios._widgets["Table"].UpdateState(thisWidget)
                    end
                    Axios._postCycleCallbacks[callbackIndex] = nil
                end
            end

            return Table
        end,
        GenerateState = function(thisWidget: Types.Table)
            local NumColumns = thisWidget.arguments.NumColumns
            if thisWidget.state.widths == nil then
                local Widths: { number } = table.create(NumColumns, 1 / NumColumns)
                thisWidget.state.widths = Axios._widgetState(thisWidget, "widths", Widths)
            end
            thisWidget._widths = table.create(NumColumns, UDim.new())
            thisWidget._minWidths = table.create(NumColumns, 0)

            local Table = thisWidget.Instance :: Frame
            local BorderContainer: Frame = Table.BorderContainer

            thisWidget._cellInstances[-1] = table.create(NumColumns)
            for index = 1, NumColumns do
                local Border = GenerateColumnBorder(thisWidget, index, "Light")
                Border.Visible = thisWidget.arguments.InnerBorders
                thisWidget._columnBorders[index] = Border
                Border.Parent = BorderContainer

                local Cell = GenerateCell(thisWidget, index, thisWidget._widths[index], false)
                local UISizeConstraint = Cell:FindFirstChild("UISizeConstraint") :: UISizeConstraint
                UISizeConstraint.MinSize = Vector2.new(
                    2 * Axios._config.CellPadding.X + (if index > 1 then -2 else 0) + (if index < NumColumns then -3 else 0),
                    0
                )
                Cell.LayoutOrder = 2 * index - 1
                thisWidget._cellInstances[-1][index] = Cell
                Cell.Parent = BorderContainer
            end

            local TableColumnBorder = GenerateColumnBorder(thisWidget, NumColumns, "Strong")
            thisWidget._columnBorders[0] = TableColumnBorder
            TableColumnBorder.Parent = Table
        end,
        Update = function(thisWidget: Types.Table)
            local NumColumns = thisWidget.arguments.NumColumns
            assert(NumColumns >= 1, "Axios.Table must have at least one column.")

            if thisWidget._widths ~= nil and #thisWidget._widths ~= NumColumns then
                -- disallow changing the number of columns. It's too much effort
                thisWidget.arguments.NumColumns = #thisWidget._widths
                warn("NumColumns cannot change once set. See documentation.")
            end

            for rowIndex, row in thisWidget._rowInstances do
                if rowIndex == 0 then
                    row.BackgroundColor3 = Axios._config.TableHeaderColor
                    row.BackgroundTransparency = Axios._config.TableHeaderTransparency
                elseif thisWidget.arguments.RowBackground == true then
                    if (rowIndex % 2) == 0 then
                        row.BackgroundColor3 = Axios._config.TableRowBgAltColor
                        row.BackgroundTransparency = Axios._config.TableRowBgAltTransparency
                    else
                        row.BackgroundColor3 = Axios._config.TableRowBgColor
                        row.BackgroundTransparency = Axios._config.TableRowBgTransparency
                    end
                else
                    row.BackgroundTransparency = 1
                end
            end
            
            for _, Border: Frame in thisWidget._rowBorders do
                Border.Visible = thisWidget.arguments.InnerBorders
            end

            for _, Border: GuiButton in thisWidget._columnBorders do
                Border.Visible = thisWidget.arguments.InnerBorders or thisWidget.arguments.Resizable
            end

            for _, border in thisWidget._columnBorders do
                local hover = border:FindFirstChild("Hover") :: Frame?
                if hover then
                    hover.Visible = thisWidget.arguments.Resizable
                end
            end

            if thisWidget._columnBorders[NumColumns] ~= nil then
                thisWidget._columnBorders[NumColumns].Visible =
                    not thisWidget.arguments.LimitTableWidth and (thisWidget.arguments.Resizable or thisWidget.arguments.InnerBorders)
                thisWidget._columnBorders[0].Visible =
                    thisWidget.arguments.LimitTableWidth and (thisWidget.arguments.Resizable or thisWidget.arguments.OuterBorders)
            end
            
            -- the header border visibility must be updated after settings all borders
            -- visiblity or not
            local HeaderRow: Frame? = thisWidget._rowInstances[0]
            local HeaderBorder: Frame? = thisWidget._rowBorders[0]
            if HeaderRow ~= nil then
                HeaderRow.Visible = thisWidget.arguments.Header
            end
            if HeaderBorder ~= nil then
                HeaderBorder.Visible = thisWidget.arguments.Header and thisWidget.arguments.InnerBorders
            end

            local Table = thisWidget.Instance :: Frame
            local BorderContainer = Table.BorderContainer :: Frame
            BorderContainer.UIStroke.Enabled = thisWidget.arguments.OuterBorders

            for index = 1, thisWidget.arguments.NumColumns do
                TableMinWidths[thisWidget][index] = true
            end

            if thisWidget._widths ~= nil then
                Axios._widgets["Table"].UpdateState(thisWidget)
            end
        end,
        UpdateState = function(thisWidget: Types.Table)
            local Table = thisWidget.Instance :: Frame
            local BorderContainer = Table.BorderContainer :: Frame
            local RowContainer = Table.RowContainer :: Frame
            local NumColumns = thisWidget.arguments.NumColumns
            local ColumnWidths = thisWidget.state.widths.value
            local MinWidths = thisWidget._minWidths
            
            local Fixed = thisWidget.arguments.FixedWidth
            local Proportional = thisWidget.arguments.ProportionalWidth

            if not thisWidget.arguments.Resizable then
                if Fixed then
                    if Proportional then
                        for index = 1, NumColumns do
                            ColumnWidths[index] = MinWidths[index]
                        end
                    else
                        local maxWidth = 0
                        for _, width in MinWidths do
                            maxWidth = math.max(maxWidth, width)
                        end
                        for index = 1, NumColumns do
                            ColumnWidths[index] = maxWidth
                        end
                    end
                else
                    if Proportional then
                        local TotalWidth = 0
                        for _, width in MinWidths do
                            TotalWidth += width
                        end
                        local Ratio = 1 / TotalWidth
                        for index = 1, NumColumns do
                            ColumnWidths[index] = Ratio * MinWidths[index]
                        end
                    else
                        local width = 1 / NumColumns
                        for index = 1, NumColumns do
                            ColumnWidths[index] = width
                        end
                    end
                end
            end

            local Position = UDim.new()
            for index = 1, NumColumns do
                local ColumnWidth = ColumnWidths[index]

                local Width = UDim.new(
                    if Fixed then 0 else math.clamp(ColumnWidth, 0, 1),
                    if Fixed then math.max(ColumnWidth, 0) else 0
                )
                thisWidget._widths[index] = Width
                Position += Width

                for _, row in thisWidget._cellInstances do
                    row[index].Size = UDim2.new(Width, UDim.new())
                end

                thisWidget._cellInstances[-1][index].Size = UDim2.new(Width + UDim.new(0,
                    (if index > 1 then -2 else 0) - 3
                ), UDim.new())
            end

            -- if the table has a fixed width and we want to cap it, we calculate the table width necessary
            local Width = Position.Offset
            if not thisWidget.arguments.FixedWidth or not thisWidget.arguments.LimitTableWidth then
                Width = math.huge
            end

            BorderContainer.UISizeConstraint.MaxSize = Vector2.new(Width, math.huge)
            RowContainer.UISizeConstraint.MaxSize = Vector2.new(Width, math.huge)
            thisWidget._columnBorders[0].Position = UDim2.fromOffset(Width - 3, 0)
        end,
        ChildAdded = function(thisWidget: Types.Table, _: Types.Widget)
            local rowIndex = thisWidget._rowIndex
            local columnIndex = thisWidget._columnIndex
            -- determine if the row exists yet
            local Row = thisWidget._rowInstances[rowIndex]
            thisWidget._rowCycles[rowIndex] = Axios._cycleTick
            TableMinWidths[thisWidget][columnIndex] = true

            if Row ~= nil then
                return thisWidget._cellInstances[rowIndex][columnIndex]
            end

            Row = GenerateRow(thisWidget, rowIndex)
            if rowIndex == 0 then
                Row.Visible = thisWidget.arguments.Header
            end
            Row.Parent = thisWidget._rowContainer

            if rowIndex > 0 then
                local Border = GenerateRowBorder(thisWidget, rowIndex - 1, if rowIndex == 1 then "Strong" else "Light")
                Border.Visible = thisWidget.arguments.InnerBorders and (if rowIndex == 1 then (thisWidget.arguments.Header and thisWidget.arguments.InnerBorders) and (thisWidget._rowInstances[0] ~= nil) else true)
                thisWidget._rowBorders[rowIndex - 1] = Border
                Border.Parent = thisWidget._rowContainer
            end

            return thisWidget._cellInstances[rowIndex][columnIndex]
        end,
        ChildDiscarded = function(thisWidget: Types.Table, thisChild: Types.Widget)
            local Cell = thisChild.Instance.Parent

            if Cell ~= nil then
                local columnIndex = tonumber(Cell.Name:sub(6))
                
                if columnIndex then
                    TableMinWidths[thisWidget][columnIndex] = true
                end
            end
        end,
        Discard = function(thisWidget: Types.Table)
            Tables[thisWidget.ID] = nil
            TableMinWidths[thisWidget] = nil
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Text"] = function()
    local script = create_mock_script("Axios.widgets.Text")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    --stylua: ignore
    Axios.WidgetConstructor("Text", {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Wrapped"] = 2,
            ["Color"] = 3,
            ["RichText"] = 4,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(_thisWidget: Types.Text)
            local Text = Instance.new("TextLabel")
            Text.Name = "Axios_Text"
            Text.AutomaticSize = Enum.AutomaticSize.XY
            Text.Size = UDim2.fromOffset(0, 0)
            Text.BackgroundTransparency = 1
            Text.BorderSizePixel = 0

            widgets.applyTextStyle(Text)
            widgets.UIPadding(Text, Vector2.new(0, 2))

            return Text
        end,
        Update = function(thisWidget: Types.Text)
            local Text = thisWidget.Instance :: TextLabel
            if thisWidget.arguments.Text == nil then
                error("Text argument is required for Axios.Text().", 5)
            end
            if thisWidget.arguments.Wrapped ~= nil then
                Text.TextWrapped = thisWidget.arguments.Wrapped
            else
                Text.TextWrapped = Axios._config.TextWrapped
            end
            if thisWidget.arguments.Color then
                Text.TextColor3 = thisWidget.arguments.Color
            else
                Text.TextColor3 = Axios._config.TextColor
            end
            if thisWidget.arguments.RichText ~= nil then
                Text.RichText = thisWidget.arguments.RichText
            else
                Text.RichText = Axios._config.RichText
            end

            Text.Text = thisWidget.arguments.Text
        end,
        Discard = function(thisWidget: Types.Text)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    --stylua: ignore
    Axios.WidgetConstructor("SeparatorText", {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(_thisWidget: Types.SeparatorText)
            local SeparatorText = Instance.new("Frame")
            SeparatorText.Name = "Axios_SeparatorText"
            SeparatorText.AutomaticSize = Enum.AutomaticSize.Y
            SeparatorText.Size = UDim2.new(Axios._config.ItemWidth, UDim.new())
            SeparatorText.BackgroundTransparency = 1
            SeparatorText.BorderSizePixel = 0
            SeparatorText.ClipsDescendants = true

            widgets.UIPadding(SeparatorText, Vector2.new(0, Axios._config.SeparatorTextPadding.Y))
            widgets.UIListLayout(SeparatorText, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemSpacing.X))

            SeparatorText.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = SeparatorText

            local Left = Instance.new("Frame")
            Left.Name = "Left"
            Left.AnchorPoint = Vector2.new(1, 0.5)
            Left.Size = UDim2.fromOffset(Axios._config.SeparatorTextPadding.X - Axios._config.ItemSpacing.X, Axios._config.SeparatorTextBorderSize)
            Left.BackgroundColor3 = Axios._config.SeparatorColor
            Left.BackgroundTransparency = Axios._config.SeparatorTransparency
            Left.BorderSizePixel = 0

            Left.Parent = SeparatorText

            local Right = Instance.new("Frame")
            Right.Name = "Right"
            Right.AnchorPoint = Vector2.new(1, 0.5)
            Right.Size = UDim2.new(1, 0, 0, Axios._config.SeparatorTextBorderSize)
            Right.BackgroundColor3 = Axios._config.SeparatorColor
            Right.BackgroundTransparency = Axios._config.SeparatorTransparency
            Right.BorderSizePixel = 0
            Right.LayoutOrder = 2

            Right.Parent = SeparatorText

            return SeparatorText
        end,
        Update = function(thisWidget: Types.SeparatorText)
            local SeparatorText = thisWidget.Instance :: Frame
            local TextLabel: TextLabel = SeparatorText.TextLabel
            if thisWidget.arguments.Text == nil then
                error("Text argument is required for Axios.SeparatorText().", 5)
            end
            TextLabel.Text = thisWidget.arguments.Text
        end,
        Discard = function(thisWidget: Types.SeparatorText)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)
end

end

_modules["Axios.widgets.Tree"] = function()
    local script = create_mock_script("Axios.widgets.Tree")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local abstractTree = {
        hasState = true,
        hasChildren = true,
        Events = {
            ["collapsed"] = {
                ["Init"] = function(_thisWidget: Types.CollapsingHeader) end,
                ["Get"] = function(thisWidget: Types.CollapsingHeader)
                    return thisWidget.lastCollapsedTick == Axios._cycleTick
                end,
            },
            ["uncollapsed"] = {
                ["Init"] = function(_thisWidget: Types.CollapsingHeader) end,
                ["Get"] = function(thisWidget: Types.CollapsingHeader)
                    return thisWidget.lastUncollapsedTick == Axios._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Discard = function(thisWidget: Types.CollapsingHeader)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
        ChildAdded = function(thisWidget: Types.CollapsingHeader, _thisChild: Types.Widget)
            local ChildContainer = thisWidget.ChildContainer :: Frame

            ChildContainer.Visible = thisWidget.state.isUncollapsed.value

            return ChildContainer
        end,
        UpdateState = function(thisWidget: Types.CollapsingHeader)
            local isUncollapsed = thisWidget.state.isUncollapsed.value
            local Tree = thisWidget.Instance :: Frame
            local ChildContainer = thisWidget.ChildContainer :: Frame
            local Header = Tree.Header :: Frame
            local Button = Header.Button :: TextButton
            local Arrow: ImageLabel = Button.Arrow

            Arrow.Image = (isUncollapsed and widgets.ICONS.DOWN_POINTING_TRIANGLE or widgets.ICONS.RIGHT_POINTING_TRIANGLE)
            if isUncollapsed then
                thisWidget.lastUncollapsedTick = Axios._cycleTick + 1
            else
                thisWidget.lastCollapsedTick = Axios._cycleTick + 1
            end

            ChildContainer.Visible = isUncollapsed
        end,
        GenerateState = function(thisWidget: Types.CollapsingHeader)
            if thisWidget.state.isUncollapsed == nil then
                thisWidget.state.isUncollapsed = Axios._widgetState(thisWidget, "isUncollapsed", thisWidget.arguments.DefaultOpen or false)
            end
        end,
    } :: Types.WidgetClass

    --stylua: ignore
    Axios.WidgetConstructor(
        "Tree",
        widgets.extend(abstractTree, {
            Args = {
                ["Text"] = 1,
                ["SpanAvailWidth"] = 2,
                ["NoIndent"] = 3,
                ["DefaultOpen"] = 4,
            },
            Generate = function(thisWidget: Types.Tree)
                local Tree = Instance.new("Frame")
                Tree.Name = "Axios_Tree"
                Tree.AutomaticSize = Enum.AutomaticSize.Y
                Tree.Size = UDim2.new(Axios._config.ItemWidth, UDim.new(0, 0))
                Tree.BackgroundTransparency = 1
                Tree.BorderSizePixel = 0

                widgets.UIListLayout(Tree, Enum.FillDirection.Vertical, UDim.new(0, 0))

                local ChildContainer = Instance.new("Frame")
                ChildContainer.Name = "TreeContainer"
                ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
                ChildContainer.Size = UDim2.fromScale(1, 0)
                ChildContainer.BackgroundTransparency = 1
                ChildContainer.BorderSizePixel = 0
                ChildContainer.LayoutOrder = 1
                ChildContainer.Visible = false
                -- ChildContainer.ClipsDescendants = true

                widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))
                widgets.UIPadding(ChildContainer, Vector2.zero).PaddingTop = UDim.new(0, Axios._config.ItemSpacing.Y)

                ChildContainer.Parent = Tree

                local Header = Instance.new("Frame")
                Header.Name = "Header"
                Header.AutomaticSize = Enum.AutomaticSize.Y
                Header.Size = UDim2.fromScale(1, 0)
                Header.BackgroundTransparency = 1
                Header.BorderSizePixel = 0
                Header.Parent = Tree

                local Button = Instance.new("TextButton")
                Button.Name = "Button"
                Button.BackgroundTransparency = 1
                Button.BorderSizePixel = 0
                Button.Text = ""
                Button.AutoButtonColor = false

                widgets.applyInteractionHighlights("Background", Button, Header, {
                    Color = Color3.fromRGB(0, 0, 0),
                    Transparency = 1,
                    HoveredColor = Axios._config.HeaderHoveredColor,
                    HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                    ActiveColor = Axios._config.HeaderActiveColor,
                    ActiveTransparency = Axios._config.HeaderActiveTransparency,
                })

                widgets.UIPadding(Button, Vector2.zero).PaddingLeft = UDim.new(0, Axios._config.FramePadding.X)
                widgets.UIListLayout(Button, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.FramePadding.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                Button.Parent = Header

                local Arrow = Instance.new("ImageLabel")
                Arrow.Name = "Arrow"
                Arrow.Size = UDim2.fromOffset(Axios._config.TextSize, math.floor(Axios._config.TextSize * 0.7))
                Arrow.BackgroundTransparency = 1
                Arrow.BorderSizePixel = 0
                Arrow.ImageColor3 = Axios._config.TextColor
                Arrow.ImageTransparency = Axios._config.TextTransparency
                Arrow.ScaleType = Enum.ScaleType.Fit

                Arrow.Parent = Button

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Name = "TextLabel"
                TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                TextLabel.Size = UDim2.fromOffset(0, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.BorderSizePixel = 0

                widgets.UIPadding(TextLabel, Vector2.zero).PaddingRight = UDim.new(0, 21)
                widgets.applyTextStyle(TextLabel)

                TextLabel.Parent = Button

                widgets.applyButtonClick(Button, function()
                    thisWidget.state.isUncollapsed:set(not thisWidget.state.isUncollapsed.value)
                end)

                thisWidget.ChildContainer = ChildContainer
                return Tree
            end,
            Update = function(thisWidget: Types.Tree)
                local Tree = thisWidget.Instance :: Frame
                local ChildContainer = thisWidget.ChildContainer :: Frame
                local Header = Tree.Header :: Frame
                local Button = Header.Button :: TextButton
                local TextLabel: TextLabel = Button.TextLabel
                local Padding: UIPadding = ChildContainer.UIPadding

                TextLabel.Text = thisWidget.arguments.Text or "Tree"
                if thisWidget.arguments.SpanAvailWidth then
                    Button.AutomaticSize = Enum.AutomaticSize.Y
                    Button.Size = UDim2.fromScale(1, 0)
                else
                    Button.AutomaticSize = Enum.AutomaticSize.XY
                    Button.Size = UDim2.fromScale(0, 0)
                end

                if thisWidget.arguments.NoIndent then
                    Padding.PaddingLeft = UDim.new(0, 0)
                else
                    Padding.PaddingLeft = UDim.new(0, Axios._config.IndentSpacing)
                end
            end,
        })
    )

    --stylua: ignore
    Axios.WidgetConstructor(
        "CollapsingHeader",
        widgets.extend(abstractTree, {
            Args = {
                ["Text"] = 1,
                ["DefaultOpen"] = 2
            },
            Generate = function(thisWidget: Types.CollapsingHeader)
                local CollapsingHeader = Instance.new("Frame")
                CollapsingHeader.Name = "Axios_CollapsingHeader"
                CollapsingHeader.AutomaticSize = Enum.AutomaticSize.Y
                CollapsingHeader.Size = UDim2.new(Axios._config.ItemWidth, UDim.new(0, 0))
                CollapsingHeader.BackgroundTransparency = 1
                CollapsingHeader.BorderSizePixel = 0

                widgets.UIListLayout(CollapsingHeader, Enum.FillDirection.Vertical, UDim.new(0, 0))

                local ChildContainer = Instance.new("Frame")
                ChildContainer.Name = "CollapsingHeaderContainer"
                ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
                ChildContainer.Size = UDim2.fromScale(1, 0)
                ChildContainer.BackgroundTransparency = 1
                ChildContainer.BorderSizePixel = 0
                ChildContainer.LayoutOrder = 1
                ChildContainer.Visible = false
                -- ChildContainer.ClipsDescendants = true

                widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y))
                widgets.UIPadding(ChildContainer, Vector2.zero).PaddingTop = UDim.new(0, Axios._config.ItemSpacing.Y)

                ChildContainer.Parent = CollapsingHeader

                local Header = Instance.new("Frame")
                Header.Name = "Header"
                Header.AutomaticSize = Enum.AutomaticSize.Y
                Header.Size = UDim2.fromScale(1, 0)
                Header.BackgroundTransparency = 1
                Header.BorderSizePixel = 0
                Header.Parent = CollapsingHeader

                local Button = Instance.new("TextButton")
                Button.Name = "Button"
                Button.AutomaticSize = Enum.AutomaticSize.Y
                Button.Size = UDim2.fromScale(1, 0)
                Button.BackgroundColor3 = Axios._config.HeaderColor
                Button.BackgroundTransparency = Axios._config.HeaderTransparency
                Button.BorderSizePixel = 0
                Button.Text = ""
                Button.AutoButtonColor = false
                Button.ClipsDescendants = true

                widgets.UIPadding(Button, Axios._config.FramePadding) -- we add a custom padding because it extends on both sides
                widgets.applyFrameStyle(Button, true)
                widgets.UIListLayout(Button, Enum.FillDirection.Horizontal, UDim.new(0, 2 * Axios._config.FramePadding.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                widgets.applyInteractionHighlights("Background", Button, Button, {
                    Color = Axios._config.HeaderColor,
                    Transparency = Axios._config.HeaderTransparency,
                    HoveredColor = Axios._config.HeaderHoveredColor,
                    HoveredTransparency = Axios._config.HeaderHoveredTransparency,
                    ActiveColor = Axios._config.HeaderActiveColor,
                    ActiveTransparency = Axios._config.HeaderActiveTransparency,
                })

                Button.Parent = Header

                local Arrow = Instance.new("ImageLabel")
                Arrow.Name = "Arrow"
                Arrow.AutomaticSize = Enum.AutomaticSize.Y
                Arrow.Size = UDim2.fromOffset(Axios._config.TextSize, math.ceil(Axios._config.TextSize * 0.8))
                Arrow.BackgroundTransparency = 1
                Arrow.BorderSizePixel = 0
                Arrow.ImageColor3 = Axios._config.TextColor
                Arrow.ImageTransparency = Axios._config.TextTransparency
                Arrow.ScaleType = Enum.ScaleType.Fit

                Arrow.Parent = Button

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Name = "TextLabel"
                TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                TextLabel.Size = UDim2.fromOffset(0, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.BorderSizePixel = 0

                widgets.UIPadding(TextLabel, Vector2.zero).PaddingRight = UDim.new(0, 21)
                widgets.applyTextStyle(TextLabel)

                TextLabel.Parent = Button

                widgets.applyButtonClick(Button, function()
                    thisWidget.state.isUncollapsed:set(not thisWidget.state.isUncollapsed.value)
                end)

                thisWidget.ChildContainer = ChildContainer
                return CollapsingHeader
            end,
            Update = function(thisWidget: Types.CollapsingHeader)
                local Tree = thisWidget.Instance :: Frame
                local Header = Tree.Header :: Frame
                local Button = Header.Button :: TextButton
                local TextLabel: TextLabel = Button.TextLabel

                TextLabel.Text = thisWidget.arguments.Text or "Collapsing Header"
            end,
        })
    )
end

end

_modules["Axios.widgets.Window"] = function()
    local script = create_mock_script("Axios.widgets.Window")
    local require = axios_require
local Types = require(script.Parent.Parent.Types)

return function(Axios: Types.Internal, widgets: Types.WidgetUtility)
    local function relocateTooltips()
        if Axios._rootInstance == nil then
            return
        end
        local PopupScreenGui = Axios._rootInstance:FindFirstChild("PopupScreenGui")
        local TooltipContainer: Frame = PopupScreenGui.TooltipContainer
        local mouseLocation = widgets.getMouseLocation()
        local newPosition = widgets.findBestWindowPosForPopup(mouseLocation, TooltipContainer.AbsoluteSize, Axios._config.DisplaySafeAreaPadding, PopupScreenGui.AbsoluteSize)
        TooltipContainer.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
    end

    widgets.registerEvent("InputChanged", function()
        if not Axios._started then
            return
        end
        relocateTooltips()
    end)

    --stylua: ignore
    Axios.WidgetConstructor("Tooltip", {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
        },
        Events = {},
        Generate = function(thisWidget: Types.Tooltip)
            thisWidget.parentWidget = Axios._rootWidget -- only allow root as parent

            local Tooltip = Instance.new("Frame")
            Tooltip.Name = "Axios_Tooltip"
            Tooltip.AutomaticSize = Enum.AutomaticSize.Y
            Tooltip.Size = UDim2.new(Axios._config.ContentWidth, UDim.new(0, 0))
            Tooltip.BorderSizePixel = 0
            Tooltip.BackgroundTransparency = 1

            local TooltipText = Instance.new("TextLabel")
            TooltipText.Name = "TooltipText"
            TooltipText.AutomaticSize = Enum.AutomaticSize.XY
            TooltipText.Size = UDim2.fromOffset(0, 0)
            TooltipText.BackgroundColor3 = Axios._config.PopupBgColor
            TooltipText.BackgroundTransparency = Axios._config.PopupBgTransparency

            widgets.applyTextStyle(TooltipText)
            widgets.UIStroke(TooltipText, Axios._config.PopupBorderSize, Axios._config.BorderActiveColor, Axios._config.BorderActiveTransparency)
            widgets.UIPadding(TooltipText, Axios._config.WindowPadding)
            if Axios._config.PopupRounding > 0 then
                widgets.UICorner(TooltipText, Axios._config.PopupRounding)
            end

            TooltipText.Parent = Tooltip

            return Tooltip
        end,
        Update = function(thisWidget: Types.Tooltip)
            local Tooltip = thisWidget.Instance :: Frame
            local TooltipText: TextLabel = Tooltip.TooltipText
            if thisWidget.arguments.Text == nil then
                error("Text argument is required for Axios.Tooltip().", 5)
            end
            TooltipText.Text = thisWidget.arguments.Text
            relocateTooltips()
        end,
        Discard = function(thisWidget: Types.Tooltip)
            thisWidget.Instance:Destroy()
        end,
    } :: Types.WidgetClass)

    local windowDisplayOrder = 0 -- incremental count which is used for determining focused windows ZIndex
    local dragWindow: Types.Window? -- window being dragged, may be nil
    local isDragging = false
    local moveDeltaCursorPosition: Vector2 -- cursor offset from drag origin (top left of window)

    local resizeWindow: Types.Window? -- window being resized, may be nil
    local isResizing = false
    local isInsideResize = false -- is cursor inside of the focused window resize outer padding
    local isInsideWindow = false -- is cursor inside of the focused window
    local resizeFromTopBottom = Enum.TopBottom.Top
    local resizeFromLeftRight = Enum.LeftRight.Left

    local lastCursorPosition: Vector2

    local focusedWindow: Types.Window? -- window with focus, may be nil
    local anyFocusedWindow = false -- is there any focused window?

    local windowWidgets: { [Types.ID]: Types.Window } = {} -- array of widget objects of type window

    local function quickSwapWindows()
        -- ctrl + tab swapping functionality
        if Axios._config.UseScreenGUIs == false then
            return
        end

        local lowest = 0xFFFF
        local lowestWidget: Types.Window

        for _, widget in windowWidgets do
            if widget.state.isOpened.value and not widget.arguments.NoNav then
                if widget.Instance:IsA("ScreenGui") then
                    local value = widget.Instance.DisplayOrder
                    if value < lowest then
                        lowest = value
                        lowestWidget = widget
                    end
                end
            end
        end

        if not lowestWidget then
            return
        end

        if lowestWidget.state.isUncollapsed.value == false then
            lowestWidget.state.isUncollapsed:set(true)
        end
        Axios.SetFocusedWindow(lowestWidget)
    end

    local function fitSizeToWindowBounds(thisWidget: Types.Window, intentedSize: Vector2)
        local windowSize = Vector2.new(thisWidget.state.position.value.X, thisWidget.state.position.value.Y)
        local minWindowSize = (Axios._config.TextSize + 2 * Axios._config.FramePadding.Y) * 2
        local usableSize = widgets.getScreenSizeForWindow(thisWidget)
        local safeAreaPadding = Vector2.new(Axios._config.WindowBorderSize + Axios._config.DisplaySafeAreaPadding.X, Axios._config.WindowBorderSize + Axios._config.DisplaySafeAreaPadding.Y)

        local maxWindowSize = (usableSize - windowSize - safeAreaPadding)
        return Vector2.new(math.clamp(intentedSize.X, minWindowSize, math.max(maxWindowSize.X, minWindowSize)), math.clamp(intentedSize.Y, minWindowSize, math.max(maxWindowSize.Y, minWindowSize)))
    end

    local function fitPositionToWindowBounds(thisWidget: Types.Window, intendedPosition: Vector2)
        local thisWidgetInstance = thisWidget.Instance
        local usableSize = widgets.getScreenSizeForWindow(thisWidget)
        local safeAreaPadding = Vector2.new(Axios._config.WindowBorderSize + Axios._config.DisplaySafeAreaPadding.X, Axios._config.WindowBorderSize + Axios._config.DisplaySafeAreaPadding.Y)

        return Vector2.new(
            math.clamp(intendedPosition.X, safeAreaPadding.X, math.max(safeAreaPadding.X, usableSize.X - thisWidgetInstance.WindowButton.AbsoluteSize.X - safeAreaPadding.X)),
            math.clamp(intendedPosition.Y, safeAreaPadding.Y, math.max(safeAreaPadding.Y, usableSize.Y - thisWidgetInstance.WindowButton.AbsoluteSize.Y - safeAreaPadding.Y))
        )
    end

    Axios.SetFocusedWindow = function(thisWidget: Types.Window?)
        if focusedWindow == thisWidget then
            return
        end

        if anyFocusedWindow and focusedWindow ~= nil then
            if windowWidgets[focusedWindow.ID] then
                local Window = focusedWindow.Instance :: Frame
                local WindowButton = Window.WindowButton :: TextButton
                local Content = WindowButton.Content :: Frame
                local TitleBar: Frame = Content.TitleBar
                -- update appearance to unfocus
                if focusedWindow.state.isUncollapsed.value then
                    TitleBar.BackgroundColor3 = Axios._config.TitleBgColor
                    TitleBar.BackgroundTransparency = Axios._config.TitleBgTransparency
                else
                    TitleBar.BackgroundColor3 = Axios._config.TitleBgCollapsedColor
                    TitleBar.BackgroundTransparency = Axios._config.TitleBgCollapsedTransparency
                end
                WindowButton.UIStroke.Color = Axios._config.BorderColor
            end

            anyFocusedWindow = false
            focusedWindow = nil
        end

        if thisWidget ~= nil then
            -- update appearance to focus
            anyFocusedWindow = true
            focusedWindow = thisWidget
            local Window = thisWidget.Instance :: Frame
            local WindowButton = Window.WindowButton :: TextButton
            local Content = WindowButton.Content :: Frame
            local TitleBar: Frame = Content.TitleBar

            TitleBar.BackgroundColor3 = Axios._config.TitleBgActiveColor
            TitleBar.BackgroundTransparency = Axios._config.TitleBgActiveTransparency
            WindowButton.UIStroke.Color = Axios._config.BorderActiveColor

            windowDisplayOrder += 1
            if thisWidget.usesScreenGuis then
                Window.DisplayOrder = windowDisplayOrder + Axios._config.DisplayOrderOffset
            else
                Window.ZIndex = windowDisplayOrder + Axios._config.DisplayOrderOffset
            end

            if thisWidget.state.isUncollapsed.value == false then
                thisWidget.state.isUncollapsed:set(true)
            end

            local firstSelectedObject: GuiObject? = widgets.GuiService.SelectedObject
            if firstSelectedObject then
                if TitleBar.Visible then
                    widgets.GuiService:Select(TitleBar)
                else
                    widgets.GuiService:Select(thisWidget.ChildContainer)
                end
            end
        end
    end

    widgets.registerEvent("InputBegan", function(input: InputObject)
        if not Axios._started then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local inWindow = false
            local position = widgets.getMouseLocation()
            for _, window in windowWidgets do
                local Window = window.Instance
                if not Window then
                    continue
                end
                local WindowButton = Window.WindowButton :: TextButton
                local ResizeBorder: TextButton = WindowButton.ResizeBorder
                if ResizeBorder and widgets.isPosInsideRect(position, ResizeBorder.AbsolutePosition - widgets.GuiOffset, ResizeBorder.AbsolutePosition - widgets.GuiOffset + ResizeBorder.AbsoluteSize) then
                    inWindow = true
                    break
                end
            end

            if not inWindow then
                Axios.SetFocusedWindow(nil)
            end
        end

        if input.KeyCode == Enum.KeyCode.Tab and (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            quickSwapWindows()
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 and isInsideResize and not isInsideWindow and anyFocusedWindow and focusedWindow then
            local midWindow = focusedWindow.state.position.value + (focusedWindow.state.size.value / 2)
            local cursorPosition = widgets.getMouseLocation() - midWindow

            -- check which axis its closest to, then check which side is closest with math.sign
            if math.abs(cursorPosition.X) * focusedWindow.state.size.value.Y >= math.abs(cursorPosition.Y) * focusedWindow.state.size.value.X then
                resizeFromTopBottom = Enum.TopBottom.Center
                resizeFromLeftRight = if math.sign(cursorPosition.X) == -1 then Enum.LeftRight.Left else Enum.LeftRight.Right
            else
                resizeFromLeftRight = Enum.LeftRight.Center
                resizeFromTopBottom = if math.sign(cursorPosition.Y) == -1 then Enum.TopBottom.Top else Enum.TopBottom.Bottom
            end
            isResizing = true
            resizeWindow = focusedWindow
        end
    end)

    widgets.registerEvent("TouchTapInWorld", function(_, gameProcessedEvent: boolean)
        if not Axios._started then
            return
        end
        if not gameProcessedEvent then
            Axios.SetFocusedWindow(nil)
        end
    end)

    widgets.registerEvent("InputChanged", function(input: InputObject)
        if not Axios._started then
            return
        end
        if isDragging and dragWindow then
            local mouseLocation
            if input.UserInputType == Enum.UserInputType.Touch then
                local location = input.Position
                mouseLocation = Vector2.new(location.X, location.Y)
            else
                mouseLocation = widgets.getMouseLocation()
            end
            local Window = dragWindow.Instance :: Frame
            local dragInstance: TextButton = Window.WindowButton
            local intendedPosition = mouseLocation - moveDeltaCursorPosition
            local newPos = fitPositionToWindowBounds(dragWindow, intendedPosition)

            -- state shouldnt be used like this, but calling :set would run the entire UpdateState function for the window, which is slow.
            dragInstance.Position = UDim2.fromOffset(newPos.X, newPos.Y)
            dragWindow.state.position.value = newPos
        end
        if isResizing and resizeWindow and resizeWindow.arguments.NoResize ~= true then
            local Window = resizeWindow.Instance :: Frame
            local resizeInstance: TextButton = Window.WindowButton
            local windowPosition = Vector2.new(resizeInstance.Position.X.Offset, resizeInstance.Position.Y.Offset)
            local windowSize = Vector2.new(resizeInstance.Size.X.Offset, resizeInstance.Size.Y.Offset)

            local mouseDelta
            if input.UserInputType == Enum.UserInputType.Touch then
                mouseDelta = input.Delta
            else
                mouseDelta = widgets.getMouseLocation() - lastCursorPosition
            end

            local intendedPosition = windowPosition + Vector2.new(if resizeFromLeftRight == Enum.LeftRight.Left then mouseDelta.X else 0, if resizeFromTopBottom == Enum.TopBottom.Top then mouseDelta.Y else 0)

            local intendedSize = windowSize
                + Vector2.new(
                    if resizeFromLeftRight == Enum.LeftRight.Left then -mouseDelta.X elseif resizeFromLeftRight == Enum.LeftRight.Right then mouseDelta.X else 0,
                    if resizeFromTopBottom == Enum.TopBottom.Top then -mouseDelta.Y elseif resizeFromTopBottom == Enum.TopBottom.Bottom then mouseDelta.Y else 0
                )

            local newSize = fitSizeToWindowBounds(resizeWindow, intendedSize)
            local newPosition = fitPositionToWindowBounds(resizeWindow, intendedPosition)

            resizeInstance.Size = UDim2.fromOffset(newSize.X, newSize.Y)
            resizeWindow.state.size.value = newSize
            resizeInstance.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
            resizeWindow.state.position.value = newPosition
        end

        lastCursorPosition = widgets.getMouseLocation()
    end)

    widgets.registerEvent("InputEnded", function(input, _)
        if not Axios._started then
            return
        end
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isDragging and dragWindow then
            local Window = dragWindow.Instance :: Frame
            local dragInstance: TextButton = Window.WindowButton
            isDragging = false
            dragWindow.state.position:set(Vector2.new(dragInstance.Position.X.Offset, dragInstance.Position.Y.Offset))
        end
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isResizing and resizeWindow then
            local Window = resizeWindow.Instance :: Instance
            isResizing = false
            resizeWindow.state.size:set(Window.WindowButton.AbsoluteSize)
        end

        if input.KeyCode == Enum.KeyCode.ButtonX then
            quickSwapWindows()
        end
    end)

    --stylua: ignore
    Axios.WidgetConstructor("Window", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Title"] = 1,
            ["NoTitleBar"] = 2,
            ["NoBackground"] = 3,
            ["NoCollapse"] = 4,
            ["NoClose"] = 5,
            ["NoMove"] = 6,
            ["NoScrollbar"] = 7,
            ["NoResize"] = 8,
            ["NoNav"] = 9,
            ["NoMenu"] = 10,
        },
        Events = {
            ["closed"] = {
                ["Init"] = function(_thisWidget: Types.Window) end,
                ["Get"] = function(thisWidget: Types.Window)
                    return thisWidget.lastClosedTick == Axios._cycleTick
                end,
            },
            ["opened"] = {
                ["Init"] = function(_thisWidget: Types.Window) end,
                ["Get"] = function(thisWidget: Types.Window)
                    return thisWidget.lastOpenedTick == Axios._cycleTick
                end,
            },
            ["collapsed"] = {
                ["Init"] = function(_thisWidget: Types.Window) end,
                ["Get"] = function(thisWidget: Types.Window)
                    return thisWidget.lastCollapsedTick == Axios._cycleTick
                end,
            },
            ["uncollapsed"] = {
                ["Init"] = function(_thisWidget: Types.Window) end,
                ["Get"] = function(thisWidget: Types.Window)
                    return thisWidget.lastUncollapsedTick == Axios._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                local Window = thisWidget.Instance :: Frame
                return Window.WindowButton
            end),
        },
        Generate = function(thisWidget: Types.Window)
            thisWidget.parentWidget = Axios._rootWidget -- only allow root as parent

            thisWidget.usesScreenGuis = Axios._config.UseScreenGUIs
            windowWidgets[thisWidget.ID] = thisWidget

            local Window
            if thisWidget.usesScreenGuis then
                Window = Instance.new("ScreenGui")
                Window.ResetOnSpawn = false
                Window.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                Window.DisplayOrder = Axios._config.DisplayOrderOffset
                Window.ScreenInsets = Axios._config.ScreenInsets
                Window.IgnoreGuiInset = Axios._config.IgnoreGuiInset
            else
                Window = Instance.new("Frame")
                Window.AnchorPoint = Vector2.new(0.5, 0.5)
                Window.Position = UDim2.fromScale(0.5, 0.5)
                Window.Size = UDim2.fromScale(1, 1)
                Window.BackgroundTransparency = 1
                Window.ZIndex = Axios._config.DisplayOrderOffset
            end
            Window.Name = "Axios_Window"

            local WindowButton = Instance.new("TextButton")
            WindowButton.Name = "WindowButton"
            WindowButton.Size = UDim2.fromOffset(0, 0)
            WindowButton.BackgroundTransparency = 1
            WindowButton.BorderSizePixel = 0
            WindowButton.Text = ""
            WindowButton.AutoButtonColor = false
            WindowButton.ClipsDescendants = false
            WindowButton.Selectable = false
            
            WindowButton.SelectionImageObject = Axios.SelectionImageObject
            WindowButton.SelectionGroup = true
            WindowButton.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
            WindowButton.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
            WindowButton.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
            WindowButton.SelectionBehaviorRight = Enum.SelectionBehavior.Stop

            widgets.UIStroke(WindowButton, Axios._config.WindowBorderSize, Axios._config.BorderColor, Axios._config.BorderTransparency)

            WindowButton.Parent = Window

            widgets.applyInputBegan(WindowButton, function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end
                if thisWidget.state.isUncollapsed.value then
                    Axios.SetFocusedWindow(thisWidget)
                end
                if not thisWidget.arguments.NoMove and input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragWindow = thisWidget
                    isDragging = true
                    moveDeltaCursorPosition = widgets.getMouseLocation() - thisWidget.state.position.value
                end
            end)

            local Content = Instance.new("Frame")
            Content.Name = "Content"
            Content.AnchorPoint = Vector2.new(0.5, 0.5)
            Content.Position = UDim2.fromScale(0.5, 0.5)
            Content.Size = UDim2.fromScale(1, 1)
            Content.BackgroundTransparency = 1
            Content.ClipsDescendants = true
            Content.Parent = WindowButton

            local UIListLayout = widgets.UIListLayout(Content, Enum.FillDirection.Vertical, UDim.new(0, 0))
            UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "WindowContainer"
            ChildContainer.Size = UDim2.fromScale(1, 1)
            ChildContainer.BackgroundColor3 = Axios._config.WindowBgColor
            ChildContainer.BackgroundTransparency = Axios._config.WindowBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Axios._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Axios._config.ScrollbarGrabColor
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            ChildContainer.LayoutOrder = thisWidget.ZIndex + 0xFFFF
            ChildContainer.ClipsDescendants = true

            widgets.UIPadding(ChildContainer, Axios._config.WindowPadding)

            ChildContainer.Parent = Content

            local UIFlexItem = Instance.new("UIFlexItem")
            UIFlexItem.FlexMode = Enum.UIFlexMode.Fill
            UIFlexItem.ItemLineAlignment = Enum.ItemLineAlignment.End
            UIFlexItem.Parent = ChildContainer

            ChildContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                -- "wrong" use of state here, for optimization
                thisWidget.state.scrollDistance.value = ChildContainer.CanvasPosition.Y
            end)

            widgets.applyInputBegan(ChildContainer, function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end
                if thisWidget.state.isUncollapsed.value then
                    Axios.SetFocusedWindow(thisWidget)
                end
            end)

            local TerminatingFrame = Instance.new("Frame")
            TerminatingFrame.Name = "TerminatingFrame"
            TerminatingFrame.Size = UDim2.fromOffset(0, Axios._config.WindowPadding.Y + Axios._config.FramePadding.Y)
            TerminatingFrame.BackgroundTransparency = 1
            TerminatingFrame.BorderSizePixel = 0
            TerminatingFrame.LayoutOrder = 0x7FFFFFF0

            widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Axios._config.ItemSpacing.Y)).VerticalAlignment = Enum.VerticalAlignment.Top

            TerminatingFrame.Parent = ChildContainer

            local TitleBar = Instance.new("Frame")
            TitleBar.Name = "TitleBar"
            TitleBar.AutomaticSize = Enum.AutomaticSize.Y
            TitleBar.Size = UDim2.fromScale(1, 0)
            TitleBar.BorderSizePixel = 0
            TitleBar.ClipsDescendants = true

            TitleBar.Parent = Content

            widgets.UIPadding(TitleBar, Vector2.new(Axios._config.FramePadding.X))
            widgets.UIListLayout(TitleBar, Enum.FillDirection.Horizontal, UDim.new(0, Axios._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center
            widgets.applyInputBegan(TitleBar, function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    if not thisWidget.arguments.NoMove then
                        dragWindow = thisWidget
                        isDragging = true
                        local location = input.Position
                        moveDeltaCursorPosition = Vector2.new(location.X, location.Y) - thisWidget.state.position.value
                    end
                end
            end)

            local TitleButtonSize = Axios._config.TextSize + ((Axios._config.FramePadding.Y - 1) * 2)

            local CollapseButton = Instance.new("TextButton")
            CollapseButton.Name = "CollapseButton"
            CollapseButton.AutomaticSize = Enum.AutomaticSize.None
            CollapseButton.AnchorPoint = Vector2.new(0, 0.5)
            CollapseButton.Size = UDim2.fromOffset(TitleButtonSize, TitleButtonSize)
            CollapseButton.Position = UDim2.fromScale(0, 0.5)
            CollapseButton.BackgroundTransparency = 1
            CollapseButton.BorderSizePixel = 0
            CollapseButton.AutoButtonColor = false
            CollapseButton.Text = ""

            widgets.UICorner(CollapseButton)

            CollapseButton.Parent = TitleBar

            widgets.applyButtonClick(CollapseButton, function()
                thisWidget.state.isUncollapsed:set(not thisWidget.state.isUncollapsed.value)
            end)

            widgets.applyInteractionHighlights("Background", CollapseButton, CollapseButton, {
                Color = Axios._config.ButtonColor,
                Transparency = 1,
                HoveredColor = Axios._config.ButtonHoveredColor,
                HoveredTransparency = Axios._config.ButtonHoveredTransparency,
                ActiveColor = Axios._config.ButtonActiveColor,
                ActiveTransparency = Axios._config.ButtonActiveTransparency,
            })

            local CollapseArrow = Instance.new("ImageLabel")
            CollapseArrow.Name = "Arrow"
            CollapseArrow.AnchorPoint = Vector2.new(0.5, 0.5)
            CollapseArrow.Size = UDim2.fromOffset(math.floor(0.7 * TitleButtonSize), math.floor(0.7 * TitleButtonSize))
            CollapseArrow.Position = UDim2.fromScale(0.5, 0.5)
            CollapseArrow.BackgroundTransparency = 1
            CollapseArrow.BorderSizePixel = 0
            CollapseArrow.Image = widgets.ICONS.MULTIPLICATION_SIGN
            CollapseArrow.ImageColor3 = Axios._config.TextColor
            CollapseArrow.ImageTransparency = Axios._config.TextTransparency
            CollapseArrow.Parent = CollapseButton

            local CloseButton = Instance.new("TextButton")
            CloseButton.Name = "CloseButton"
            CloseButton.AutomaticSize = Enum.AutomaticSize.None
            CloseButton.AnchorPoint = Vector2.new(1, 0.5)
            CloseButton.Size = UDim2.fromOffset(TitleButtonSize, TitleButtonSize)
            CloseButton.Position = UDim2.fromScale(1, 0.5)
            CloseButton.BackgroundTransparency = 1
            CloseButton.BorderSizePixel = 0
            CloseButton.Text = ""
            CloseButton.AutoButtonColor = false
            CloseButton.LayoutOrder = 2

            widgets.UICorner(CloseButton)

            widgets.applyButtonClick(CloseButton, function()
                thisWidget.state.isOpened:set(false)
            end)

            widgets.applyInteractionHighlights("Background", CloseButton, CloseButton, {
                Color = Axios._config.ButtonColor,
                Transparency = 1,
                HoveredColor = Axios._config.ButtonHoveredColor,
                HoveredTransparency = Axios._config.ButtonHoveredTransparency,
                ActiveColor = Axios._config.ButtonActiveColor,
                ActiveTransparency = Axios._config.ButtonActiveTransparency,
            })

            CloseButton.Parent = TitleBar

            local CloseIcon = Instance.new("ImageLabel")
            CloseIcon.Name = "Icon"
            CloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            CloseIcon.Size = UDim2.fromOffset(math.floor(0.7 * TitleButtonSize), math.floor(0.7 * TitleButtonSize))
            CloseIcon.Position = UDim2.fromScale(0.5, 0.5)
            CloseIcon.BackgroundTransparency = 1
            CloseIcon.BorderSizePixel = 0
            CloseIcon.Image = widgets.ICONS.MULTIPLICATION_SIGN
            CloseIcon.ImageColor3 = Axios._config.TextColor
            CloseIcon.ImageTransparency = Axios._config.TextTransparency
            CloseIcon.Parent = CloseButton

            -- allowing fractional titlebar title location dosent seem useful, as opposed to Enum.LeftRight.

            local Title = Instance.new("TextLabel")
            Title.Name = "Title"
            Title.AutomaticSize = Enum.AutomaticSize.XY
            Title.BorderSizePixel = 0
            Title.BackgroundTransparency = 1
            Title.LayoutOrder = 1
            Title.ClipsDescendants = true
            
            widgets.UIPadding(Title, Vector2.new(0, Axios._config.FramePadding.Y))
            widgets.applyTextStyle(Title)
            Title.TextXAlignment = Enum.TextXAlignment[Axios._config.WindowTitleAlign.Name] :: Enum.TextXAlignment

            local TitleFlexItem = Instance.new("UIFlexItem")
            TitleFlexItem.FlexMode = Enum.UIFlexMode.Fill
            TitleFlexItem.ItemLineAlignment = Enum.ItemLineAlignment.Center

            TitleFlexItem.Parent = Title

            Title.Parent = TitleBar

            local ResizeButtonSize = Axios._config.TextSize + Axios._config.FramePadding.X

            local LeftResizeGrip = Instance.new("ImageButton")
            LeftResizeGrip.Name = "LeftResizeGrip"
            LeftResizeGrip.AnchorPoint = Vector2.yAxis
            LeftResizeGrip.Rotation = 180
            LeftResizeGrip.Position = UDim2.fromScale(0, 1)
            LeftResizeGrip.Size = UDim2.fromOffset(ResizeButtonSize, ResizeButtonSize)
            LeftResizeGrip.BackgroundTransparency = 1
            LeftResizeGrip.BorderSizePixel = 0
            LeftResizeGrip.Image = widgets.ICONS.BOTTOM_RIGHT_CORNER
            LeftResizeGrip.ImageColor3 = Axios._config.ResizeGripColor
            LeftResizeGrip.ImageTransparency = 1
            LeftResizeGrip.AutoButtonColor = false
            LeftResizeGrip.ZIndex = 3
            LeftResizeGrip.Parent = WindowButton

            widgets.applyInteractionHighlights("Image", LeftResizeGrip, LeftResizeGrip, {
                Color = Axios._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Axios._config.ResizeGripHoveredColor,
                HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
                ActiveColor = Axios._config.ResizeGripActiveColor,
                ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
            })

            widgets.applyButtonDown(LeftResizeGrip, function()
                if not anyFocusedWindow or not (focusedWindow == thisWidget) then
                    Axios.SetFocusedWindow(thisWidget)
                    -- mitigating wrong focus when clicking on buttons inside of a window without clicking the window itself
                end
                isResizing = true
                resizeFromTopBottom = Enum.TopBottom.Bottom
                resizeFromLeftRight = Enum.LeftRight.Left
                resizeWindow = thisWidget
            end)

            -- each border uses an image, allowing it to have a visible borde which is larger than the UI
            local RightResizeGrip = Instance.new("ImageButton")
            RightResizeGrip.Name = "RightResizeGrip"
            RightResizeGrip.AnchorPoint = Vector2.one
            RightResizeGrip.Rotation = 90
            RightResizeGrip.Position = UDim2.fromScale(1, 1)
            RightResizeGrip.Size = UDim2.fromOffset(ResizeButtonSize, ResizeButtonSize)
            RightResizeGrip.BackgroundTransparency = 1
            RightResizeGrip.BorderSizePixel = 0
            RightResizeGrip.Image = widgets.ICONS.BOTTOM_RIGHT_CORNER
            RightResizeGrip.ImageColor3 = Axios._config.ResizeGripColor
            RightResizeGrip.ImageTransparency = Axios._config.ResizeGripTransparency
            RightResizeGrip.AutoButtonColor = false
            RightResizeGrip.ZIndex = 3
            RightResizeGrip.Parent = WindowButton

            widgets.applyInteractionHighlights("Image", RightResizeGrip, RightResizeGrip, {
                Color = Axios._config.ResizeGripColor,
                Transparency = Axios._config.ResizeGripTransparency,
                HoveredColor = Axios._config.ResizeGripHoveredColor,
                HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
                ActiveColor = Axios._config.ResizeGripActiveColor,
                ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
            })

            widgets.applyButtonDown(RightResizeGrip, function()
                if not anyFocusedWindow or not (focusedWindow == thisWidget) then
                    Axios.SetFocusedWindow(thisWidget)
                    -- mitigating wrong focus when clicking on buttons inside of a window without clicking the window itself
                end
                isResizing = true
                resizeFromTopBottom = Enum.TopBottom.Bottom
                resizeFromLeftRight = Enum.LeftRight.Right
                resizeWindow = thisWidget
            end)

            local LeftResizeBorder = Instance.new("ImageButton")
            LeftResizeBorder.Name = "LeftResizeBorder"
            LeftResizeBorder.AnchorPoint = Vector2.new(1, .5)
            LeftResizeBorder.Position = UDim2.fromScale(0, .5)
            LeftResizeBorder.Size = UDim2.new(0, Axios._config.WindowResizePadding.X, 1, 2 * Axios._config.WindowBorderSize)
            LeftResizeBorder.Transparency = 1
            LeftResizeBorder.Image = widgets.ICONS.BORDER
            LeftResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            LeftResizeBorder.ScaleType = Enum.ScaleType.Slice
            LeftResizeBorder.SliceCenter = Rect.new(0, 0, 1, 1)
            LeftResizeBorder.ImageRectOffset = Vector2.new(2, 2)
            LeftResizeBorder.ImageRectSize = Vector2.new(2, 1)
            LeftResizeBorder.ImageTransparency = 1
            LeftResizeBorder.AutoButtonColor = false
            LeftResizeBorder.ZIndex = 4

            LeftResizeBorder.Parent = WindowButton

            local RightResizeBorder = Instance.new("ImageButton")
            RightResizeBorder.Name = "RightResizeBorder"
            RightResizeBorder.AnchorPoint = Vector2.new(0, .5)
            RightResizeBorder.Position = UDim2.fromScale(1, .5)
            RightResizeBorder.Size = UDim2.new(0, Axios._config.WindowResizePadding.X, 1, 2 * Axios._config.WindowBorderSize)
            RightResizeBorder.Transparency = 1
            RightResizeBorder.Image = widgets.ICONS.BORDER
            RightResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            RightResizeBorder.ScaleType = Enum.ScaleType.Slice
            RightResizeBorder.SliceCenter = Rect.new(1, 0, 2, 1)
            RightResizeBorder.ImageRectOffset = Vector2.new(1, 2)
            RightResizeBorder.ImageRectSize = Vector2.new(2, 1)
            RightResizeBorder.ImageTransparency = 1
            RightResizeBorder.AutoButtonColor = false
            RightResizeBorder.ZIndex = 4

            RightResizeBorder.Parent = WindowButton

            local TopResizeBorder = Instance.new("ImageButton")
            TopResizeBorder.Name = "TopResizeBorder"
            TopResizeBorder.AnchorPoint = Vector2.new(.5, 1)
            TopResizeBorder.Position = UDim2.fromScale(.5, 0)
            TopResizeBorder.Size = UDim2.new(1, 2 * Axios._config.WindowBorderSize, 0, Axios._config.WindowResizePadding.Y)
            TopResizeBorder.Transparency = 1
            TopResizeBorder.Image = widgets.ICONS.BORDER
            TopResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            TopResizeBorder.ScaleType = Enum.ScaleType.Slice
            TopResizeBorder.SliceCenter = Rect.new(0, 0, 1, 1)
            TopResizeBorder.ImageRectOffset = Vector2.new(2, 2)
            TopResizeBorder.ImageRectSize = Vector2.new(1, 2)
            TopResizeBorder.ImageTransparency = 1
            TopResizeBorder.AutoButtonColor = false
            TopResizeBorder.ZIndex = 4

            TopResizeBorder.Parent = WindowButton

            local BottomResizeBorder = Instance.new("ImageButton")
            BottomResizeBorder.Name = "BottomResizeBorder"
            BottomResizeBorder.AnchorPoint = Vector2.new(.5, 0)
            BottomResizeBorder.Position = UDim2.fromScale(.5, 1)
            BottomResizeBorder.Size = UDim2.new(1, 2 * Axios._config.WindowBorderSize, 0, Axios._config.WindowResizePadding.Y)
            BottomResizeBorder.Transparency = 1
            BottomResizeBorder.Image = widgets.ICONS.BORDER
            BottomResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            BottomResizeBorder.ScaleType = Enum.ScaleType.Slice
            BottomResizeBorder.SliceCenter = Rect.new(0, 1, 1, 2)
            BottomResizeBorder.ImageRectOffset = Vector2.new(2, 1)
            BottomResizeBorder.ImageRectSize = Vector2.new(1, 2)
            BottomResizeBorder.ImageTransparency = 1
            BottomResizeBorder.AutoButtonColor = false
            BottomResizeBorder.ZIndex = 4

            BottomResizeBorder.Parent = WindowButton

            widgets.applyInteractionHighlights("Image", LeftResizeBorder, LeftResizeBorder, {
                Color = Axios._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Axios._config.ResizeGripHoveredColor,
                HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
                ActiveColor = Axios._config.ResizeGripActiveColor,
                ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
            })

            widgets.applyInteractionHighlights("Image", RightResizeBorder, RightResizeBorder, {
                Color = Axios._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Axios._config.ResizeGripHoveredColor,
                HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
                ActiveColor = Axios._config.ResizeGripActiveColor,
                ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
            })

            widgets.applyInteractionHighlights("Image", TopResizeBorder, TopResizeBorder, {
                Color = Axios._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Axios._config.ResizeGripHoveredColor,
                HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
                ActiveColor = Axios._config.ResizeGripActiveColor,
                ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
            })

            widgets.applyInteractionHighlights("Image", BottomResizeBorder, BottomResizeBorder, {
                Color = Axios._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Axios._config.ResizeGripHoveredColor,
                HoveredTransparency = Axios._config.ResizeGripHoveredTransparency,
                ActiveColor = Axios._config.ResizeGripActiveColor,
                ActiveTransparency = Axios._config.ResizeGripActiveTransparency,
            })

            local ResizeBorder = Instance.new("Frame")
            ResizeBorder.Name = "ResizeBorder"
            ResizeBorder.Position = UDim2.fromOffset(-Axios._config.WindowResizePadding.X, -Axios._config.WindowResizePadding.Y)
            ResizeBorder.Size = UDim2.new(1, Axios._config.WindowResizePadding.X * 2, 1, Axios._config.WindowResizePadding.Y * 2)
            ResizeBorder.BackgroundTransparency = 1
            ResizeBorder.BorderSizePixel = 0
            ResizeBorder.Active = false
            ResizeBorder.Selectable = false
            ResizeBorder.ClipsDescendants = false
            ResizeBorder.Parent = WindowButton

            widgets.applyMouseEnter(ResizeBorder, function()
                if focusedWindow == thisWidget then
                    isInsideResize = true
                end
            end)
            widgets.applyMouseLeave(ResizeBorder, function()
                if focusedWindow == thisWidget then
                    isInsideResize = false
                end
            end)
            widgets.applyInputBegan(ResizeBorder, function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end
                if thisWidget.state.isUncollapsed.value then
                    Axios.SetFocusedWindow(thisWidget)
                end
            end)

            widgets.applyMouseEnter(WindowButton, function()
                if focusedWindow == thisWidget then
                    isInsideWindow = true
                end
            end)
            widgets.applyMouseLeave(WindowButton, function()
                if focusedWindow == thisWidget then
                    isInsideWindow = false
                end
            end)

            thisWidget.ChildContainer = ChildContainer
            return Window
        end,
        GenerateState = function(thisWidget: Types.Window)
            if thisWidget.state.size == nil then
                thisWidget.state.size = Axios._widgetState(thisWidget, "size", Vector2.new(400, 300))
            end
            if thisWidget.state.position == nil then
                thisWidget.state.position = Axios._widgetState(thisWidget, "position", if anyFocusedWindow and focusedWindow then focusedWindow.state.position.value + Vector2.new(15, 45) else Vector2.new(150, 250))
            end
            thisWidget.state.position.value = fitPositionToWindowBounds(thisWidget, thisWidget.state.position.value)
            thisWidget.state.size.value = fitSizeToWindowBounds(thisWidget, thisWidget.state.size.value)

            if thisWidget.state.isUncollapsed == nil then
                thisWidget.state.isUncollapsed = Axios._widgetState(thisWidget, "isUncollapsed", true)
            end
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Axios._widgetState(thisWidget, "isOpened", true)
            end
            if thisWidget.state.scrollDistance == nil then
                thisWidget.state.scrollDistance = Axios._widgetState(thisWidget, "scrollDistance", 0)
            end
        end,
        Update = function(thisWidget: Types.Window)
            local Window = thisWidget.Instance :: GuiObject
            local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame
            local WindowButton = Window.WindowButton :: TextButton
            local Content = WindowButton.Content :: Frame
            local TitleBar = Content.TitleBar :: Frame
            local Title: TextLabel = TitleBar.Title
            local MenuBar: Frame? = Content:FindFirstChild("Axios_MenuBar")
            local LeftResizeGrip: TextButton = WindowButton.LeftResizeGrip
            local RightResizeGrip: TextButton = WindowButton.RightResizeGrip
            local LeftResizeBorder: Frame = WindowButton.LeftResizeBorder
            local RightResizeBorder: Frame = WindowButton.RightResizeBorder
            local TopResizeBorder: Frame = WindowButton.TopResizeBorder
            local BottomResizeBorder: Frame = WindowButton.BottomResizeBorder

            if thisWidget.arguments.NoResize ~= true then
                LeftResizeGrip.Visible = true
                RightResizeGrip.Visible = true
                LeftResizeBorder.Visible = true
                RightResizeBorder.Visible = true
                TopResizeBorder.Visible = true
                BottomResizeBorder.Visible = true
            else
                LeftResizeGrip.Visible = false
                RightResizeGrip.Visible = false
                LeftResizeBorder.Visible = false
                RightResizeBorder.Visible = false
                TopResizeBorder.Visible = false
                BottomResizeBorder.Visible = false
            end
            if thisWidget.arguments.NoScrollbar then
                ChildContainer.ScrollBarThickness = 0
            else
                ChildContainer.ScrollBarThickness = Axios._config.ScrollbarSize
            end
            if thisWidget.arguments.NoTitleBar then
                TitleBar.Visible = false
            else
                TitleBar.Visible = true
            end
            if MenuBar then
                if thisWidget.arguments.NoMenu then
                    MenuBar.Visible = false
                else
                    MenuBar.Visible = true
                end
            end
            if thisWidget.arguments.NoBackground then
                ChildContainer.BackgroundTransparency = 1
            else
                ChildContainer.BackgroundTransparency = Axios._config.WindowBgTransparency
            end

            -- TitleBar buttons
            if thisWidget.arguments.NoCollapse then
                TitleBar.CollapseButton.Visible = false
            else
                TitleBar.CollapseButton.Visible = true
            end
            if thisWidget.arguments.NoClose then
                TitleBar.CloseButton.Visible = false
            else
                TitleBar.CloseButton.Visible = true
            end

            Title.Text = thisWidget.arguments.Title or ""
        end,
        UpdateState = function(thisWidget: Types.Window)
            local stateSize = thisWidget.state.size.value
            local statePosition = thisWidget.state.position.value
            local stateIsUncollapsed = thisWidget.state.isUncollapsed.value
            local stateIsOpened = thisWidget.state.isOpened.value
            local stateScrollDistance = thisWidget.state.scrollDistance.value

            local Window = thisWidget.Instance :: Frame
            local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame
            local WindowButton = Window.WindowButton :: TextButton
            local Content = WindowButton.Content :: Frame
            local TitleBar = Content.TitleBar :: Frame
            local MenuBar: Frame? = Content:FindFirstChild("Axios_MenuBar")
            local LeftResizeGrip: TextButton = WindowButton.LeftResizeGrip
            local RightResizeGrip: TextButton = WindowButton.RightResizeGrip
            local LeftResizeBorder: Frame = WindowButton.LeftResizeBorder
            local RightResizeBorder: Frame = WindowButton.RightResizeBorder
            local TopResizeBorder: Frame = WindowButton.TopResizeBorder
            local BottomResizeBorder: Frame = WindowButton.BottomResizeBorder

            WindowButton.Size = UDim2.fromOffset(stateSize.X, stateSize.Y)
            WindowButton.Position = UDim2.fromOffset(statePosition.X, statePosition.Y)

            if stateIsOpened then
                if thisWidget.usesScreenGuis then
                    Window.Enabled = true
                    WindowButton.Visible = true
                else
                    Window.Visible = true
                    WindowButton.Visible = true
                end
                thisWidget.lastOpenedTick = Axios._cycleTick + 1
            else
                if thisWidget.usesScreenGuis then
                    Window.Enabled = false
                    WindowButton.Visible = false
                else
                    Window.Visible = false
                    WindowButton.Visible = false
                end
                thisWidget.lastClosedTick = Axios._cycleTick + 1
            end

            if stateIsUncollapsed then
                TitleBar.CollapseButton.Arrow.Image = widgets.ICONS.DOWN_POINTING_TRIANGLE
                if MenuBar then
                    MenuBar.Visible = not thisWidget.arguments.NoMenu
                end
                ChildContainer.Visible = true
                if thisWidget.arguments.NoResize ~= true then
                    LeftResizeGrip.Visible = true
                    RightResizeGrip.Visible = true
                    LeftResizeBorder.Visible = true
                    RightResizeBorder.Visible = true
                    TopResizeBorder.Visible = true
                    BottomResizeBorder.Visible = true
                end
                WindowButton.AutomaticSize = Enum.AutomaticSize.None
                thisWidget.lastUncollapsedTick = Axios._cycleTick + 1
            else
                local collapsedHeight: number = TitleBar.AbsoluteSize.Y -- Axios._config.TextSize + Axios._config.FramePadding.Y * 2
                TitleBar.CollapseButton.Arrow.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE

                if MenuBar then
                    MenuBar.Visible = false
                end
                ChildContainer.Visible = false
                LeftResizeGrip.Visible = false
                RightResizeGrip.Visible = false
                LeftResizeBorder.Visible = false
                RightResizeBorder.Visible = false
                TopResizeBorder.Visible = false
                BottomResizeBorder.Visible = false
                WindowButton.Size = UDim2.fromOffset(stateSize.X, collapsedHeight)
                thisWidget.lastCollapsedTick = Axios._cycleTick + 1
            end

            if stateIsOpened and stateIsUncollapsed then
                Axios.SetFocusedWindow(thisWidget)
            else
                TitleBar.BackgroundColor3 = Axios._config.TitleBgCollapsedColor
                TitleBar.BackgroundTransparency = Axios._config.TitleBgCollapsedTransparency
                WindowButton.UIStroke.Color = Axios._config.BorderColor

                Axios.SetFocusedWindow(nil)
            end

            -- cant update canvasPosition in this cycle because scrollingframe isint ready to be changed
            if stateScrollDistance and stateScrollDistance ~= 0 then
                local callbackIndex = #Axios._postCycleCallbacks + 1
                local desiredCycleTick = Axios._cycleTick + 1
                Axios._postCycleCallbacks[callbackIndex] = function()
                    if Axios._cycleTick >= desiredCycleTick then
                        if thisWidget.lastCycleTick ~= -1 then
                            ChildContainer.CanvasPosition = Vector2.new(0, stateScrollDistance)
                        end
                        Axios._postCycleCallbacks[callbackIndex] = nil
                    end
                end
            end
        end,
        ChildAdded = function(thisWidget: Types.Window, thisChid: Types.Widget)
            local Window = thisWidget.Instance :: Frame
            local WindowButton = Window.WindowButton :: TextButton
            local Content = WindowButton.Content :: Frame
            if thisChid.type == "MenuBar" then
                local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame
                thisChid.Instance.ZIndex = ChildContainer.ZIndex + 1
                thisChid.Instance.LayoutOrder = ChildContainer.LayoutOrder - 1
                return Content
            end
            return thisWidget.ChildContainer
        end,
        Discard = function(thisWidget: Types.Window)
            if focusedWindow == thisWidget then
                focusedWindow = nil
                anyFocusedWindow = false
            end
            if dragWindow == thisWidget then
                dragWindow = nil
                isDragging = false
            end
            if resizeWindow == thisWidget then
                resizeWindow = nil
                isResizing = false
            end
            windowWidgets[thisWidget.ID] = nil
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end

end

local Axios = _require("Axios")

-- Patch Init to support Axios:Init()
local oldInit = Axios.Init
Axios.Init = function(first, ...)
    if first == Axios then
        return oldInit(...)
    else
        return oldInit(first, ...)
    end
end

if getgenv then
    getgenv().Axios = Axios
end
return Axios
