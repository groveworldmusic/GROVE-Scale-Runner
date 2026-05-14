-- Mock gfx.* globals for testing
-- No-op methods + mutable state fields. Defaults: w=720, h=500, all else 0/nil.

local gfx = {}

-- ================================================================
-- Mutable state fields
-- ================================================================
gfx.x = 0
gfx.y = 0
gfx.w = 720
gfx.h = 500
gfx.mouse_x = 0
gfx.mouse_y = 0
gfx.mouse_cap = 0
gfx.mouse_wheel = 0
gfx.hwnd = nil

-- ================================================================
-- No-op methods (17)
-- ================================================================

-- Initialization and teardown
function gfx.init(...) end
function gfx.quit(...) end
function gfx.update(...) end

-- Window state
function gfx.getchar(...) return 0 end
function gfx.dock(...) return 0 end

-- Font and color
function gfx.setfont(...) end
function gfx.setcolor(...) end
function gfx.getfont(...) end
function gfx.getfontname(...) return "" end

-- Drawing
function gfx.rect(...) end
function gfx.rectangle(...) end
function gfx.circle(...) end
function gfx.line(...) end
function gfx.triangle(...) end
function gfx.sector(...) end
function gfx.gradrect(...) end

-- Text
function gfx.drawstr(...) end
function gfx.measurestr(...) end
function gfx.setpixel(...) end

-- Blit / image
function gfx.blit(...) end
function gfx.dest(...) end

return gfx
