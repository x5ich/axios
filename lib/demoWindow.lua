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
