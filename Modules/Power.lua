local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddPower
Creates and configures an oUF Power element on the given frame.
The power bar is overlaid on the frame at the position specified in config.
Width defaults to the parent frame width if not provided.
* frame     - the oUF unit frame
* cfg       - the unit's modules.power config table
--]]
function addon:AddPower(frame, cfg)
    local Power = CreateFrame("StatusBar", cfg.frameName, frame)
    Power:SetFrameLevel(frame:GetFrameLevel() + 5)
    Power:SetPoint(cfg.anchor, cfg.relativeTo and _G[cfg.relativeTo] or frame, cfg.relativePoint, cfg.offsetX or 0, cfg.offsetY or 0)
    Power:SetHeight(cfg.height)
    Power:SetWidth(cfg.width or frame:GetWidth())

    -- Texture
    if cfg.texture then
        local texturePath = addon.config.global.textures[cfg.texture:lower()]
        if texturePath then
            Power:SetStatusBarTexture(texturePath)
        end
    end

    -- Let oUF color by power type (mana, rage, energy, etc.)
    Power.colorPower = true
    Power.frequentUpdates = true

    -- Capture the original health height so we can adjust it dynamically
    local adjustHealth = cfg.adjustHealthbarHeight and frame.Health
    local healthOriginalHeight = adjustHealth and frame.Health:GetHeight()
    local powerHeight = cfg.height

    -- Hide the power bar when the unit has no primary power type
    -- or when onlyHealer is set and the unit's role is not HEALER.
    -- Adjust the health bar height accordingly.
    -- oUF passes max with the correct displayType already resolved.
    -- If max is a secret value, the unit genuinely has power (Blizzard
    -- wouldn't hide 0). We use SecureCall on tostring to safely test it.
    local onlyHealer = cfg.onlyHealer

    Power.PostUpdate = function(self, unit, cur, min, max)
        local safeMax = addon:SecureCall(tostring, max)
        local hasPower = safeMax == nil or safeMax == false or tonumber(safeMax) ~= 0

        -- Filter by healer role if configured
        if hasPower and onlyHealer then
            local role = UnitGroupRolesAssigned(unit)
            if role ~= "HEALER" then
                hasPower = false
            end
        end

        if hasPower then
            self:Show()
            if adjustHealth then
                frame.Health:SetHeight(healthOriginalHeight - powerHeight)
            end
        else
            self:Hide()
            if adjustHealth then
                frame.Health:SetHeight(healthOriginalHeight)
            end
        end
    end

    -- Re-evaluate power visibility when roles change (e.g. onlyHealer)
    if onlyHealer then
        frame:RegisterEvent("GROUP_ROSTER_UPDATE", function(self)
            if self.Power and self.Power.PostUpdate then
                self.Power:PostUpdate(self.unit, 0, 0, UnitPowerMax(self.unit))
            end
        end, true)
    end

    frame.Power = Power
    addon:AddBackground(Power, cfg)
    addon:AddBorder(Power, cfg)
end
