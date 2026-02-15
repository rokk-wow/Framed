local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddRestingIndicator
Creates and configures an oUF RestingIndicator element on the given frame.
Uses a Frame wrapper at HIGH strata so it renders above other elements.
oUF calls PostUpdate with the resting state; we also hide when in combat
so the CombatIndicator can take over the same anchor point.
Only works on the player unit.
* frame - the oUF unit frame
* cfg   - the unit's modules.restingIndicator config table
--]]
function addon:AddRestingIndicator(frame, cfg)
    local size = cfg.size or 24

    local RestingFrame = CreateFrame("Frame", nil, frame)
    RestingFrame:SetFrameStrata(cfg.strata or "HIGH")
    RestingFrame:SetSize(size, size)
    RestingFrame:SetPoint(
        cfg.anchor or "CENTER",
        _G[cfg.relativeTo] or frame,
        cfg.relativePoint or "CENTER",
        cfg.offsetX or 0,
        cfg.offsetY or 0
    )

    local texture = RestingFrame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(RestingFrame)
    if cfg.atlasTexture then
        texture:SetAtlas(cfg.atlasTexture, false)
    end

    -- Only show when resting AND not in combat
    RestingFrame.PostUpdate = function(element, isResting)
        if isResting and not UnitAffectingCombat("player") then
            element:Show()
        else
            element:Hide()
        end
    end

    frame.RestingIndicator = RestingFrame
end
