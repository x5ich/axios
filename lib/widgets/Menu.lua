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
