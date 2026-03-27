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
