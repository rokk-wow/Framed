local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddHealth
Creates and configures an oUF Health element on the given frame.
* frame     - the oUF unit frame
* cfg       - the unit's modules.health config table
--]]
function addon:AddHealth(frame, cfg)
    local Health = CreateFrame("StatusBar", cfg.frameName, frame)

    if cfg.anchor then
        Health:SetPoint(cfg.anchor, cfg.relativeTo and _G[cfg.relativeTo] or frame, cfg.relativePoint, cfg.offsetX or 0, cfg.offsetY or 0)
    else
        -- Anchor top + sides so SetHeight can control the bottom edge.
        -- Using SetAllPoints would lock all 4 corners, preventing height adjustments
        -- (e.g. adjustHealthbarHeight from the Power module).
        Health:SetPoint("TOPLEFT", frame, "TOPLEFT")
        Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    end

    Health:SetHeight(cfg.height or frame:GetHeight())
    Health:SetWidth(cfg.width or frame:GetWidth())

    -- Texture
    if cfg.texture then
        local texturePath = addon.config.global.textures[cfg.texture:lower()]
        if texturePath then
            Health:SetStatusBarTexture(texturePath)
        end
    end

    -- Color
    if cfg.color == "class" then
        Health.colorClass = true
        Health.colorReaction = true
    else
        local r, g, b, a = addon:HexToRGB(cfg.color)
        Health:SetStatusBarColor(r, g, b, a)
    end

    frame.Health = Health
    addon:AddBackground(Health, cfg)
    addon:AddBorder(Health, cfg)
end
