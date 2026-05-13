-- GROVE FL MIDI: Compact View — Barrel Module
-- Re-exports all sub-modules so consumers use compact.*
-- No inline state or function definitions — all logic is in sub-modules.
local compact_init = require("ui.compact-init")
local compact_panel = require("ui.compact-panel")
local compact_intercept = require("ui.compact-intercept")
local compact_menu = require("ui.compact-menu")

local compact = {}

-- ── From compact-init ──
compact.FindTransportWindow = compact_init.FindTransportWindow
compact.ResetAutoPosition   = compact_init.ResetAutoPosition
compact.SetManualPosition   = compact_init.SetManualPosition
compact.SwitchViewMode      = compact_init.SwitchViewMode
compact.IsPanelOpen         = compact_init.IsPanelOpen
compact.InitOverlay         = compact_init.InitOverlay
compact.HandlePanel         = compact_init.HandlePanel
compact.UpdateCompactView   = compact_init.UpdateCompactView
compact.Cleanup             = compact_init.Cleanup

-- ── From compact-intercept ──
compact.ProcessMouseInterception = compact_intercept.ProcessMouseInterception

-- ── From compact-menu ──
compact.ShowContextMenu     = compact_menu.ShowContextMenu

return compact
