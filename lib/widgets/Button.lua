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
