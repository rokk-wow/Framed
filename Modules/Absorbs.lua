local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddAbsorbs
Creates and configures an oUF HealthPrediction element for absorb shields.
Uses oUF's built-in HealthPrediction element which handles
UNIT_ABSORB_AMOUNT_CHANGED events automatically.
Must be called after AddHealth so that frame.Health exists.
* frame - the oUF unit frame
* cfg   - the unit's modules.absorbs config table
--]]
function addon:AddAbsorbs(frame, cfg)
    if not frame.Health then return end

    local Health = frame.Health

    -- Resolve the absorb bar texture from config or fall back to a default
    local texturePath
    if cfg.texture then
        texturePath = addon.config.global.textures[cfg.texture:lower()]
    end

    -- damageAbsorb: a StatusBar overlaying the health bar to show shield amount
    local damageAbsorb = CreateFrame("StatusBar", nil, Health)
    damageAbsorb:SetPoint("TOP")
    damageAbsorb:SetPoint("BOTTOM")
    damageAbsorb:SetPoint("LEFT", Health:GetStatusBarTexture(), "RIGHT")
    damageAbsorb:SetWidth(Health:GetWidth())
    if texturePath then
        damageAbsorb:SetStatusBarTexture(texturePath)
    end
    damageAbsorb:SetStatusBarColor(1, 1, 1, cfg.opacity or 0.5)

    -- overDamageAbsorbIndicator: glow texture when absorb exceeds max health
    local overDamageAbsorbIndicator = Health:CreateTexture(nil, "OVERLAY")
    overDamageAbsorbIndicator:SetPoint("TOP")
    overDamageAbsorbIndicator:SetPoint("BOTTOM")
    overDamageAbsorbIndicator:SetPoint("LEFT", Health, "RIGHT")
    overDamageAbsorbIndicator:SetWidth(10)

    -- Register as oUF's HealthPrediction element
    frame.HealthPrediction = {
        damageAbsorb = damageAbsorb,
        overDamageAbsorbIndicator = overDamageAbsorbIndicator,
        incomingHealOverflow = cfg.maxAbsorbOverflow or 1.0,
    }
end
