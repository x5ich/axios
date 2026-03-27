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
