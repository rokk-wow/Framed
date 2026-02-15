local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ GetFontPath
Resolves a font name to a full addon media path.
Accepts a font file name (e.g. "DorisPP") or nil.
If the name matches a global config key that isn't a string font name
(e.g. "normalFont" = 18), it falls back to the global default font.
* fontName  - font file name without extension, or nil
Returns     - full Interface path string
--]]
function addon:GetFontPath(fontName)
    local name = fontName

    -- If nil or maps to a number in global config (it's a size key, not a font name), use default
    if not name or type(self.config.global[name]) == "number" then
        name = self.config.global.font
    end

    return "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\" .. name .. ".ttf"
end

--[[ ResolveFontSize
Resolves a size value to a number.
Accepts a number directly, or a string key that maps to a named size
in global config (e.g. "normalFont" → 18, "smallFont" → 14).
* size      - number or string
Returns     - number (point size)
--]]
function addon:ResolveFontSize(size)
    if type(size) == "number" then
        return size
    end
    if type(size) == "string" then
        local resolved = self.config.global[size]
        if type(resolved) == "number" then
            return resolved
        end
    end
    return 14 -- fallback
end

--[[ AddText
Creates FontString elements on a unit frame from an array of text configs.
Each config entry creates one FontString, positions it, styles it, and
binds an oUF tag string for automatic updates.

* frame         - the oUF unit frame
* textConfigs   - array of text config tables

Each text config table supports:
  enabled       (boolean)  whether this text element is shown
  anchor        (string)   SetPoint anchor point (e.g. "LEFT", "RIGHT", "CENTER")
  relativeTo    (string)   global frame name to anchor to
  relativePoint  (string)   anchor point on the parent
  offsetX       (number)   horizontal offset, default 0
  offsetY       (number)   vertical offset, default 0
  font          (string)   font file name, default global font
  size          (number|string) point size or named size key
  outline       (string)   "OUTLINE", "THICKOUTLINE", or nil
  color         (string)   hex color (e.g. "FFFFFF"), default white
  justifyH      (string)   "LEFT"/"RIGHT"/"CENTER", auto-detected from anchor if omitted
  shadow        (boolean)  if true, adds a 1px drop shadow
  format        (string)   oUF tag string (e.g. "[name:medium]", "[perhp<$%]")
--]]
function addon:AddText(frame, textConfigs)
    if not textConfigs then return end

    -- Create a dedicated overlay frame for text so it renders above all child frames
    if not frame.TextOverlay then
        frame.TextOverlay = CreateFrame("Frame", nil, frame)
        frame.TextOverlay:SetAllPoints(frame)
        frame.TextOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    end

    frame.Texts = frame.Texts or {}

    for i, cfg in ipairs(textConfigs) do
        if cfg.enabled then
            -- Create FontString on the overlay frame
            local fs = frame.TextOverlay:CreateFontString(nil, "OVERLAY")

            -- Font
            local fontPath = self:GetFontPath(cfg.font)
            local fontSize = self:ResolveFontSize(cfg.size)
            fs:SetFont(fontPath, fontSize, cfg.outline or "OUTLINE")

            -- Position
            local parent = cfg.relativeTo and _G[cfg.relativeTo] or frame
            fs:SetPoint(cfg.anchor, parent, cfg.relativePoint, cfg.offsetX or 0, cfg.offsetY or 0)

            -- Horizontal justification (auto-detect from anchor if not explicit)
            local justify = cfg.justifyH
            if not justify then
                if cfg.anchor == "LEFT" or cfg.anchor == "TOPLEFT" or cfg.anchor == "BOTTOMLEFT" then
                    justify = "LEFT"
                elseif cfg.anchor == "RIGHT" or cfg.anchor == "TOPRIGHT" or cfg.anchor == "BOTTOMRIGHT" then
                    justify = "RIGHT"
                else
                    justify = "CENTER"
                end
            end
            fs:SetJustifyH(justify)

            -- Limit left/right-anchored text to 50% of parent width to prevent overlap
            if justify == "LEFT" or justify == "RIGHT" then
                local parentWidth = parent:GetWidth()
                if parentWidth and parentWidth > 0 then
                    fs:SetWidth(parentWidth * 0.5)
                    fs:SetWordWrap(false)
                end
            end

            -- Color
            if cfg.color then
                local r, g, b, a = self:HexToRGB(cfg.color)
                fs:SetTextColor(r, g, b, a or 1)
            end

            -- Shadow
            if cfg.shadow then
                fs:SetShadowOffset(1, -1)
                fs:SetShadowColor(0, 0, 0, 1)
            end

            -- Bind oUF tag string for automatic event-driven updates
            if cfg.format then
                frame:Tag(fs, cfg.format)
            end

            frame.Texts[i] = fs
        end
    end
end
