local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddDispelHighlight
Creates an inner border on the unit frame that lights up when the unit
has a dispellable debuff. Colors by debuff type (Magic, Curse, Disease,
Poison, Bleed, Enrage) using a secret-safe color curve approach.

The border renders INSIDE the frame (positive insets) so it never
conflicts with the outer selection-highlight border.

Detection:
  C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, colorCurve)
  is secret-safe and returns a color mapped from the aura's dispel type.
  The color curve has NO entry for DispelType.None (index 0), so
  non-dispellable auras return nil — giving us a clean signal.

Color pass-through:
  The returned color may contain secret values internally, so we NEVER
  read or compare the RGBA components. Instead we pass them directly
  to SetBackdropBorderColor (which calls SetVertexColor internally,
  a known secret-safe pass-through).

Registered as an oUF element for proper lifecycle management.

* frame - the oUF unit frame
* cfg   - the unit's modules.dispelHighlight config table
--]]

-- Enum name -> DispelType value
local TYPE_MAP = {
    Magic   = oUF.Enum.DispelType.Magic,
    Curse   = oUF.Enum.DispelType.Curse,
    Disease = oUF.Enum.DispelType.Disease,
    Poison  = oUF.Enum.DispelType.Poison,
    Bleed   = oUF.Enum.DispelType.Bleed,
    Enrage  = oUF.Enum.DispelType.Enrage,
}

-- Color curve built lazily from global dispelColors config.
-- Includes all configured types. DispelType.None (0) is intentionally
-- omitted so non-dispellable auras return nil from GetAuraDispelTypeColor.
local dispelColorCurve

local function EnsureDispelColorCurve()
    if dispelColorCurve then return end

    local globalDispel = addon.config.global.dispelColors or {}

    dispelColorCurve = C_CurveUtil.CreateColorCurve()
    dispelColorCurve:SetType(Enum.LuaCurveType.Step)

    for name, enumVal in pairs(TYPE_MAP) do
        local hex = globalDispel[name]
        if hex then
            local r, g, b, a = addon:HexToRGB(hex)
            dispelColorCurve:AddPoint(enumVal, CreateColor(r, g, b, a or 1))
        end
    end
end

---------------------------------------------------------------------------
-- Frame builder (called from UnitFrame.lua)
---------------------------------------------------------------------------
function addon:AddDispelHighlight(frame, cfg)
    local borderWidth = cfg.borderWidth or 2

    -- Create the inner border frame flush against the outer border,
    -- expanding inward via backdrop insets.
    local inner = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inner:SetAllPoints(frame)
    inner:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = borderWidth,
        insets = { left = borderWidth, right = borderWidth, top = borderWidth, bottom = borderWidth },
    })
    inner:SetFrameStrata("HIGH")
    inner:SetFrameLevel(frame:GetFrameLevel() + 20)
    inner:Hide()

    frame.DispelHighlight = inner
end

---------------------------------------------------------------------------
-- oUF element callbacks
---------------------------------------------------------------------------
local function Update(self, event, unit)
    if unit and self.unit ~= unit then return end

    local element = self.DispelHighlight
    if not element then return end

    unit = self.unit
    if not unit or not UnitExists(unit) then
        element:Hide()
        return
    end

    EnsureDispelColorCurve()

    local foundColor = nil

    -- Iterate harmful auras using secret-safe C_UnitAuras APIs
    local slots = { C_UnitAuras.GetAuraSlots(unit, "HARMFUL") }
    for i = 2, #slots do -- slot 1 is continuationToken
        local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
        if data and data.auraInstanceID then
            -- Skip auras Blizzard doesn't consider raid-relevant
            -- (e.g. Temporal Displacement / Sated / rez sickness).
            -- Returns true when the aura does NOT match the filter.
            if not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, data.auraInstanceID, "HARMFUL|RAID") then
                -- GetAuraDispelTypeColor maps the aura's dispel type through
                -- our curve. No curve entry for unlisted types, so pcall
                -- catches the nil/error for non-matching auras.
                local ok, color = pcall(
                    C_UnitAuras.GetAuraDispelTypeColor,
                    unit, data.auraInstanceID, dispelColorCurve
                )

                if ok and color then
                    foundColor = color
                    break -- show the first matching debuff's color
                end
            end
        end
    end

    if foundColor then
        -- Pass color directly to widget — secret-safe pass-through
        element:SetBackdropBorderColor(foundColor:GetRGBA())
        element:Show()
    else
        element:Hide()
    end
end

local function Enable(self)
    local element = self.DispelHighlight
    if not element then return end

    self:RegisterEvent("UNIT_AURA", Update)

    -- Initial check
    Update(self, "Enable")
    return true
end

local function Disable(self)
    local element = self.DispelHighlight
    if not element then return end

    element:Hide()
    self:UnregisterEvent("UNIT_AURA", Update)
end

oUF:AddElement("DispelHighlight", Update, Enable, Disable)
