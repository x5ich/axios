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
