local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddRoleIcon
Creates a desaturated, vertex-colored role icon (TANK/HEALER/DAMAGER)
as a real Texture widget on the given frame.
Updates on GROUP_ROSTER_UPDATE and PLAYER_ROLES_ASSIGNED via oUF events.
* frame - the oUF unit frame
* cfg   - the unit's modules.roleIcon config table
--]]
function addon:AddRoleIcon(frame, cfg)
    local size = cfg.size or 12

    -- Create a container frame above modules so the icon isn't hidden
    -- behind the Health StatusBar (a child frame that covers parent textures).
    local container = CreateFrame("Frame", nil, frame)
    container:SetAllPoints(frame)
    container:SetFrameLevel(frame:GetFrameLevel() + 10)

    local icon = container:CreateTexture(nil, "OVERLAY")
    icon:SetSize(size, size)
    icon:SetPoint(
        cfg.anchor or "LEFT",
        cfg.relativeTo and _G[cfg.relativeTo] or frame,
        cfg.relativePoint or "LEFT",
        cfg.offsetX or 0,
        cfg.offsetY or 0
    )

    -- Apply desaturation
    if cfg.desaturate then
        icon:SetDesaturated(true)
    end

    -- Apply vertex color (tints the texture)
    if cfg.color then
        local r, g, b = addon:HexToRGB(cfg.color)
        icon:SetVertexColor(r, g, b)
    end

    -- oUF's default GroupRoleIndicator Update calls SetTexCoord for the
    -- old Blizzard spritesheet, which conflicts with our atlas approach.
    -- Override the entire update to use atlas textures instead.
    icon.Override = function(self)
        local role = UnitGroupRolesAssigned(self.unit)
        if role and role ~= "NONE" then
            local atlas = addon.config.global.roleIcons[role]
            if atlas then
                icon:SetAtlas(atlas, false)
                icon:SetAlpha(1)
                icon:Show()
                return
            end
        end
        -- No role assigned — show default icon at reduced opacity
        if cfg.defaultIcon then
            icon:SetAtlas(cfg.defaultIcon, false)
            icon:SetAlpha(cfg.defaultAlpha or 0.5)
            icon:Show()
        else
            icon:Hide()
        end
    end

    frame.GroupRoleIndicator = icon
end
