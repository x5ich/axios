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
