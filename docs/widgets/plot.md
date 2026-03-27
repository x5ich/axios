# Data Visualization (Plots and Graphs)

Axios provides specialized widgets for telemetry and status tracking, including progress bars, dynamic line graphs, and histograms.

---

## ProgressBar Widget

A standard horizontal progress bar that fills based on a normalized state value between 0.0 and 1.0.

```lua
local downloadProgress = Axios.State(0.45)

-- A bar displaying 45% completion with a custom label
Axios.ProgressBar({"Downloading Data Assets..."}, {progress = downloadProgress})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string?` | The descriptive message displayed beside the bar. |
| 2 | `Format` | `string?` | A custom text overlay (e.g., `"2.4GB / 5.0GB"`). |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `progress` | `State<number>` | The current fill value, constrained between 0 and 1. |

---

## PlotLines Widget (Line Graph)

Renders a sequence of numeric data points as a continuous line graph. This widget supports interactive hovering and can automatically scale the its Y-axis based on the data provided.

```lua
local frameTimeHistory = Axios.State({16, 17, 16, 18, 22, 16, 15})

-- Visual tracking for frame time metrics
Axios.PlotLines({"Frame Time History (ms)"}, {values = frameTimeHistory})
```

### Positional Arguments

| # | Argument | Type | Description |
|---|---|---|---|
| 1 | `Text` | `string?` | The plot's label or title. |
| 2 | `Height` | `number?` | The vertical pixel-height of the plot area (defaults to auto). |
| 3 | `Min` | `number?` | The lower bound Y-axis value (defaults to auto-scaling). |
| 4 | `Max` | `number?` | The upper bound Y-axis value (defaults to auto-scaling). |
| 5 | `TextOverlay` | `string?` | An additional text string displayed at the top of the plot. |

### Two-Way Binding (States)

| Key | Type | Description |
|---|---|---|
| `values` | `State<{number}>` | The array of numeric values to be plotted. |
| `hovered` | `State<{number}>?` | Tracks the index or value currently under the mouse cursor. |

---

## PlotHistogram Widget (Bar Chart)

Similar to the [PlotLines Widget](#plotlines-widget), the `PlotHistogram` renders discrete data points as a series of vertical bars instead of a continuous line.

```lua
local networkUsage = Axios.State({120, 45, 88, 210, 305})

-- A bar chart visualization for network throughput
Axios.PlotHistogram({"Network Throughput"}, {values = networkUsage})
```

### Positional Arguments

The `PlotHistogram` supports all the standard parameters from the [PlotLines Widget](#plotlines-widget) documentation.

### Additional Histogram Parameters

| # | Argument | Type | Description |
|---|---|---|---|
| 6 | `BaseLine` | `number?` | The Y-axis value where the base of the bars begins. |
