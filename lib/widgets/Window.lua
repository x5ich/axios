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
