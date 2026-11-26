-- The medallions' bezel (2026-11-26, the user's pick, "5 · Glint" of
-- /workspace/bezel-mock-sheet.png; art/window/gen_bezel.py): one slim ring
-- for every medallion, a dark keyline, a gold line, a dark inner line, and
-- a glint caught at its upper left.
--
-- ns.Bezel(owner, size, layer, sub) returns the ring, a texture at rest in
-- the dark gold: tint it as any rim (SetVertexColor, the light gold lit);
-- its keylines stay dark. Its glint is rim.glint, over it in ADD, shown and
-- faded with it (its alpha and its tint's). rim:Fit(size) sizes it and picks the art for the size (a
-- texture scales its line with it, so each size class has its own).
local _, ns = ...

local GLINT = 0.55                  -- the glint's strength

local function Class(size)
    return size <= 24 and "s" or size <= 40 and "m" or "l"
end

function ns.Bezel(owner, size, layer, sub)
    layer, sub = layer or "ARTWORK", sub or 0
    local rim = owner:CreateTexture(nil, layer, nil, sub)
    local glint = owner:CreateTexture(nil, layer, nil, math.min(7, sub + 1))
    glint:SetAllPoints(rim)
    glint:SetBlendMode("ADD")
    rim.glint = glint
    local dark, light = ns.gold.dark, ns.gold.light
    rim:SetVertexColor(dark[1], dark[2], dark[3], 1)
    glint:SetVertexColor(light[1], light[2], light[3], GLINT)
    -- the glint goes with its ring
    local show, hide, shown, alpha = rim.Show, rim.Hide, rim.SetShown, rim.SetAlpha
    local vertex = rim.SetVertexColor
    function rim:SetVertexColor(r, g, b, a)
        vertex(self, r, g, b, a)
        glint:SetVertexColor(light[1], light[2], light[3], GLINT * (a or 1))
    end
    function rim:Show() show(self); glint:Show() end
    function rim:Hide() hide(self); glint:Hide() end
    function rim:SetShown(on) shown(self, on); glint:SetShown(on) end
    function rim:SetAlpha(a) alpha(self, a); glint:SetAlpha(a) end
    function rim:Fit(s)
        local c = Class(s)
        if c ~= self.class then
            self.class = c
            self:SetTexture(ns.media .. "window\\bezel-" .. c)
            glint:SetTexture(ns.media .. "window\\bezel-glint-" .. c)
        end
        self:SetSize(s, s)
    end
    rim:Fit(size)
    return rim
end
