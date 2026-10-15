local P = ...

-- Formspec building blocks shared by the launcher menu, the teacher picker
-- and the editor. The look comes from pixel-art backgrounds drawn by
-- tools/make_ui.py (same style as the serverguide books); P.LAYOUT tells
-- where their panels are. Text is dark mono hypertext, readable on the
-- parchment.

local esc = core.formspec_escape

local UI = {
    ink = "#302c2e",
    soft = "#6e4a2a",       -- brown, secondary text
    good = "#2f7a2f",
    warn = "#a35f00",
    bad = "#a33a2a",
    light = "#f9f3df",      -- text on buttons and plaques
}
P.UI = UI

-- Buttons: kind -> texture set (green = main action, red = leave/stop,
-- blue = teacher, wood = the rest).
local BUTTON_KINDS = { green = true, red = true, blue = true, wood = true }

local function button_style(name, kind)
    local base = "skyss_minigames_btn_" .. (BUTTON_KINDS[kind] and kind or "wood")
    return ("style[%s;bgimg=%s.png;bgimg_hovered=%s_hover.png;bgimg_pressed=%s_pressed.png;bgimg_middle=4;"
        .. "border=false;textcolor=%s;font=bold;font_size=*1.15]"):format(name, base, base, base, UI.light)
end

-- Text for hypertext: escape markup, then the formspec.
local function htext(text)
    return esc((tostring(text):gsub("\\", "\\\\"):gsub("<", "\\<")))
end

local Form = {}
Form.__index = Form

-- A form drawn on the background of a layout ("game", "staff", ...).
function P.ui_form(layout_name)
    local lay = P.LAYOUT[layout_name]
    local w, h = lay.size[1], lay.size[2]
    local self = setmetatable({ lay = lay, parts = {}, n = 0, w = w, h = h }, Form)
    self:add(table.concat({
        "formspec_version[6]",
        ("size[%g,%g]"):format(w, h),
        "position[0.5,0.48]",
        "no_prepend[]",
        "bgcolor[#00000080;true]",
        ("background[0,0;%g,%g;skyss_minigames_ui_%s.png]"):format(w, h, layout_name),
        ("style_type[label,checkbox;textcolor=%s;font=mono]"):format(UI.ink),
        ("style_type[field;textcolor=%s;border=false;font=mono]"):format(UI.ink),
        (button_style("__default__", "wood"):gsub("style%[__default__", "style_type[button,button_exit", 1)),
    }))
    return self
end

function Form:add(s)
    table.insert(self.parts, s)
    return self
end

-- opts: size, color, bold, halign ("left"|"center"|"right"), valign.
function Form:text(x, y, w, h, text, opts)
    opts = opts or {}
    self.n = self.n + 1
    local body = htext(text)
    if opts.bold then body = "<b>" .. body .. "</b>" end
    return self:add(("hypertext[%g,%g;%g,%g;t%d;<global size=%d font=mono color=%s halign=%s valign=%s>%s]"):format(
        x, y, w, h, self.n, opts.size or 15, opts.color or UI.ink, opts.halign or "left", opts.valign or "middle", body))
end

function Form:image(x, y, w, h, texture)
    return self:add(("image[%g,%g;%g,%g;%s]"):format(x, y, w, h, esc(texture)))
end

-- A light slot behind a field.
function Form:slot(x, y, w, h)
    return self:add(("image[%g,%g;%g,%g;skyss_minigames_ui_slot.png;3]"):format(x, y, w, h))
end

function Form:button(x, y, w, h, name, label, kind, exit)
    self:add(button_style(name, kind))
    return self:add(("%s[%g,%g;%g,%g;%s;%s]"):format(exit and "button_exit" or "button", x, y, w, h, name, esc(label)))
end

-- Buttons spread along the bottom row; the first one is the widest.
function Form:button_row(buttons, x0, x1)
    x0, x1 = x0 or 0.85, x1 or (self.w - 0.85)
    local y = self.lay.buttons_y
    local n = #buttons
    if n == 0 then return self end
    local gap = 0.2
    local first = n == 1 and math.min(5, x1 - x0) or math.min(4.6, (x1 - x0 - gap * (n - 1)) * 0.4)
    local other = n > 1 and (x1 - x0 - first - gap * (n - 1)) / (n - 1) or 0
    other = math.min(other, 3.6)
    local x = x0
    for i, b in ipairs(buttons) do
        local w = i == 1 and first or other
        self:button(x, y, w, 0.85, b[1], b[2], b[3], b[4])
        x = x + w + gap
    end
    return self
end

-- Icon, title on the plaque, subtitle under it, close button.
function Form:title(icon, title, subtitle, subtitle_color)
    local t = self.lay.title
    local ix, iy, is = t.icon[1], t.icon[2], t.icon[3]
    self:image(ix + 0.2, iy + 0.2, is - 0.4, is - 0.4, icon)
    local px, py, pw, ph = t.plaque[1], t.plaque[2], t.plaque[3], t.plaque[4]
    self:text(px + 0.2, py, pw - 0.4, ph, title, { size = 22, bold = true, halign = "center" })
    if subtitle and subtitle ~= "" then
        self:text(px, py + ph + 0.02, pw, 0.5, subtitle, { size = 14, bold = true, halign = "center", color = subtitle_color or UI.soft })
    end
    if t.close then
        local cx, cy, cs = t.close[1], t.close[2], t.close[3]
        self:add(("image_button_exit[%g,%g;%g,%g;skyss_minigames_close.png;ui_close;;true;false;skyss_minigames_close_pressed.png]")
            :format(cx, cy, cs, cs))
    end
    return self
end

-- Text on one of the small wooden tabs above a panel.
function Form:tab(key, text, icon)
    local r = self.lay.tabs[key]
    if icon then
        self:image(r[1] + 0.12, r[2] + 0.06, 0.4, 0.4, icon)
        return self:text(r[1] + 0.55, r[2], r[3] - 0.6, r[4], text, { size = 13, bold = true, color = UI.light })
    end
    return self:text(r[1] + 0.1, r[2], r[3] - 0.2, r[4], text, { size = 13, bold = true, color = UI.light, halign = "center" })
end

function Form:panel(key)
    return self.lay.panels[key]
end

function Form:render()
    return table.concat(self.parts)
end

-- Cuts plain (untranslated) text to n characters.
function P.ui_cut(text, n)
    if #text <= n then return text end
    return text:sub(1, n - 1) .. "\xE2\x80\xA6"
end

-- Leaderboard in the "board" panel of the form (game and board layouts).
function Form:board(game_name)
    local S = P.S
    local mode = P.ranking_of(game_name)
    local board = P.get_board(game_name, mode)
    local p = self:panel("board")
    local rows = self.lay.rows.board
    local top, step, count = rows[1], rows[2], rows[3]
    self:tab("board", S("Leaderboard"), "skyss_minigames_ui_trophy.png")
    local tab = self.lay.tabs.board
    self:text(tab[1] + tab[3] + 0.1, tab[2], p[1] + p[3] - tab[1] - tab[3] - 0.25, tab[4],
        mode == "time" and S("best times") or S("best scores"), { size = 12, color = UI.soft, halign = "right" })
    if #board == 0 then
        self:text(p[1] + 0.3, top, p[3] - 0.6, 1.0, S("Nobody yet: be the first!"), { color = UI.soft, halign = "center" })
    end
    local medals = { "gold", "silver", "bronze" }
    local name_chars = math.floor((p[3] - 2.4) * 5.2)
    for rank = 1, math.min(count, #board) do
        local entry = board[rank]
        local y = top + (rank - 1) * step
        if medals[rank] then
            self:image(p[1] + 0.2, y + 0.04, 0.42, 0.42, "skyss_minigames_medal_" .. medals[rank] .. ".png")
        else
            self:text(p[1] + 0.1, y, 0.6, step, rank .. ".", { size = 13, bold = true, color = UI.soft, halign = "center" })
        end
        self:text(p[1] + 0.75, y, p[3] - 2.4, step, P.ui_cut(table.concat(entry.names, ", "), name_chars),
            { size = 14, bold = rank <= 3 })
        self:text(p[1] + p[3] - 1.75, y, 1.6, step, P.format_value(mode, entry.value),
            { size = 14, bold = true, halign = "right", color = rank <= 3 and UI.ink or UI.soft })
    end
    return self
end
