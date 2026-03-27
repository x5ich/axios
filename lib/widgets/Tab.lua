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
