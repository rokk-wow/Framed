local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

-- Collected highlight update functions, fired from a single PLAYER_TARGET_CHANGED handler
local highlightUpdaters = {}

--[[ SpawnUnitFrame
Registers an oUF style and spawns a single unit frame.
The style applies size, position, background, and border from config.
* unit      - oUF unit token (e.g. "player", "target", "focus")
* configKey - key into addon.config (e.g. "player", "targetTarget")
--]]
function addon:SpawnUnitFrame(unit, configKey)
    local styleName = "Framed_" .. configKey

    oUF:RegisterStyle(styleName, function(frame)
        local cfg = addon.config[configKey]

        frame:SetSize(cfg.width, cfg.height)
        frame:RegisterForClicks("AnyUp")
        frame:SetPoint(cfg.anchor, _G[cfg.relativeTo], cfg.relativePoint, cfg.offsetX, cfg.offsetY)

        addon:AddBackground(frame, cfg)

        -- Hide Blizzard buff/debuff frames if configured at the unit level
        if cfg.hideBlizzardBuffs and BuffFrame then
            BuffFrame:UnregisterAllEvents()
            BuffFrame:Hide()
        end
        if cfg.hideBlizzardDebuffs and DebuffFrame then
            DebuffFrame:UnregisterAllEvents()
            DebuffFrame:Hide()
        end

        -- Modules
        if cfg.modules then
            if cfg.modules.health and cfg.modules.health.enabled then
                addon:AddHealth(frame, cfg.modules.health)
            end

            if cfg.modules.absorbs and cfg.modules.absorbs.enabled then
                addon:AddAbsorbs(frame, cfg.modules.absorbs)
            end

            if cfg.modules.power and cfg.modules.power.enabled then
                addon:AddPower(frame, cfg.modules.power)
            end

            if cfg.modules.text then
                addon:AddText(frame, cfg.modules.text)
            end

            if cfg.modules.castbar and cfg.modules.castbar.enabled then
                addon:AddCastbar(frame, cfg.modules.castbar)
            end

            if cfg.modules.restingIndicator and cfg.modules.restingIndicator.enabled then
                addon:AddRestingIndicator(frame, cfg.modules.restingIndicator)
            end

            if cfg.modules.combatIndicator and cfg.modules.combatIndicator.enabled then
                addon:AddCombatIndicator(frame, cfg.modules.combatIndicator)
            end

            if cfg.modules.roleIcon and cfg.modules.roleIcon.enabled then
                addon:AddRoleIcon(frame, cfg.modules.roleIcon)
            end

            if cfg.modules.auraFilters then
                for _, filterCfg in ipairs(cfg.modules.auraFilters) do
                    if filterCfg.enabled then
                        addon:AddAuraFilter(frame, filterCfg)
                    end
                end
            end

            if cfg.modules.trinket and cfg.modules.trinket.enabled then
                addon:AddTrinket(frame, cfg.modules.trinket)
            end

            if cfg.modules.targetedBy and cfg.modules.targetedBy.enabled then
                addon:AddTargetedBy(frame, cfg.modules.targetedBy)
            end
        end

        -- Frame border (on top of modules)
        addon:AddBorder(frame, cfg)

        -- Dispel highlight (inner border, after outer border so it layers correctly)
        if cfg.modules and cfg.modules.dispelHighlight and cfg.modules.dispelHighlight.enabled then
            addon:AddDispelHighlight(frame, cfg.modules.dispelHighlight)
        end

        -- Highlight border when this unit is the player's current target
        if cfg.highlightSelected and frame.Border then
            local dr, dg, db, da = addon:HexToRGB(cfg.borderColor)
            local hr, hg, hb = addon:HexToRGB(addon.config.global.highlightColor)
            local baseBorderLevel = frame.Border:GetFrameLevel()

            local function UpdateHighlight()
                if UnitExists(frame.unit) and UnitIsUnit(frame.unit, "target") then
                    frame.Border:SetBackdropBorderColor(hr, hg, hb, da)
                    frame.Border:SetFrameLevel(baseBorderLevel + 20)
                else
                    frame.Border:SetBackdropBorderColor(dr, dg, db, da)
                    frame.Border:SetFrameLevel(baseBorderLevel)
                end
            end

            table.insert(highlightUpdaters, UpdateHighlight)
            hooksecurefunc(frame, "UpdateAllElements", function() UpdateHighlight() end)
        end
    end)

    oUF:SetActiveStyle(styleName)
    self.unitFrames[unit] = oUF:Spawn(unit, self.config[configKey].frameName)

    -- Force oUF to re-query all element data after a brief delay
    -- to handle asynchronous loading of unit info (power, etc.)
    local frame = self.unitFrames[unit]
    if frame then
        C_Timer.After(addon.config.global.refreshDelay, function()
            if frame then
                frame:UpdateAllElements("RefreshUnit")
            end
        end)
    end
end

--[[ SpawnGroupFrames
Creates a container frame and spawns multiple oUF unit frames inside it
in a grid layout. Used for party, arena, raid, and battleground frames.

The container handles positioning, background, and border.
Each child unit frame inherits module settings from the shared config
and is positioned within the container grid.

* configKey - key into addon.config (e.g. "party", "arena")
* units     - ordered array of unit tokens (e.g. {"player", "party1", ...})
--]]
function addon:SpawnGroupFrames(configKey, units)
    local cfg = self.config[configKey]

    -- Grid layout settings
    local maxUnits = math.min(cfg.maxUnits or #units, #units)
    local perRow = cfg.perRow or maxUnits
    local spacingX = cfg.spacingX or 0
    local spacingY = cfg.spacingY or 0
    local growthX = cfg.growthX or "RIGHT"
    local growthY = cfg.growthY or "DOWN"
    local unitW = cfg.unitWidth
    local unitH = cfg.unitHeight
    local unitBorderW = cfg.unitBorderWidth or 0

    -- Calculate container size (accounts for unit border extending outside each frame)
    local cols = math.min(perRow, maxUnits)
    local rows = math.ceil(maxUnits / cols)
    local cellW = unitW + 2 * unitBorderW
    local cellH = unitH + 2 * unitBorderW
    local containerW = cols * cellW + math.max(0, cols - 1) * spacingX + 2 * spacingX
    local containerH = rows * cellH + math.max(0, rows - 1) * spacingY + 2 * spacingY

    -- Create container frame
    local container = CreateFrame("Frame", cfg.frameName, UIParent)
    container:SetSize(containerW, containerH)
    container:SetPoint(
        cfg.anchor or "CENTER",
        _G[cfg.relativeTo] or UIParent,
        cfg.relativePoint or "CENTER",
        cfg.offsetX or 0,
        cfg.offsetY or 0)

    -- Container background
    if cfg.containerBackgroundColor then
        self:AddBackground(container, { backgroundColor = cfg.containerBackgroundColor })
    end

    -- Container border
    if cfg.containerBorderWidth and cfg.containerBorderColor then
        self:AddBorder(container, {
            borderWidth = cfg.containerBorderWidth,
            borderColor = cfg.containerBorderColor,
        })
    end

    -- Growth direction multipliers
    local xMult = (growthX == "LEFT") and -1 or 1
    local yMult = (growthY == "UP") and 1 or -1

    -- Derive initial anchor from growth direction
    local vertAnchor = (growthY == "DOWN") and "TOP" or "BOTTOM"
    local horizAnchor = (growthX == "LEFT") and "RIGHT" or "LEFT"
    local initialAnchor = vertAnchor .. horizAnchor

    -- Register a shared style for all child frames in this group
    local styleName = "Framed_" .. configKey

    oUF:RegisterStyle(styleName, function(frame)
        frame:SetSize(unitW, unitH)
        frame:RegisterForClicks("AnyUp")

        -- Unit-level background
        self:AddBackground(frame, { backgroundColor = cfg.unitBackgroundColor })

        -- Modules
        if cfg.modules then
            if cfg.modules.health and cfg.modules.health.enabled then
                self:AddHealth(frame, cfg.modules.health)
            end

            if cfg.modules.absorbs and cfg.modules.absorbs.enabled then
                self:AddAbsorbs(frame, cfg.modules.absorbs)
            end

            if cfg.modules.power and cfg.modules.power.enabled then
                self:AddPower(frame, cfg.modules.power)
            end

            if cfg.modules.text then
                self:AddText(frame, cfg.modules.text)
            end

            if cfg.modules.castbar and cfg.modules.castbar.enabled then
                self:AddCastbar(frame, cfg.modules.castbar)
            end

            if cfg.modules.restingIndicator and cfg.modules.restingIndicator.enabled then
                self:AddRestingIndicator(frame, cfg.modules.restingIndicator)
            end

            if cfg.modules.combatIndicator and cfg.modules.combatIndicator.enabled then
                self:AddCombatIndicator(frame, cfg.modules.combatIndicator)
            end

            if cfg.modules.roleIcon and cfg.modules.roleIcon.enabled then
                self:AddRoleIcon(frame, cfg.modules.roleIcon)
            end

            if cfg.modules.auraFilters then
                for _, filterCfg in ipairs(cfg.modules.auraFilters) do
                    if filterCfg.enabled then
                        self:AddAuraFilter(frame, filterCfg)
                    end
                end
            end

            if cfg.modules.trinket and cfg.modules.trinket.enabled then
                self:AddTrinket(frame, cfg.modules.trinket)
            end

            if cfg.modules.targetedBy and cfg.modules.targetedBy.enabled then
                self:AddTargetedBy(frame, cfg.modules.targetedBy)
            end
        end

        -- Unit-level border
        self:AddBorder(frame, {
            borderWidth = cfg.unitBorderWidth,
            borderColor = cfg.unitBorderColor,
        })

        -- Dispel highlight (inner border, after outer border so it layers correctly)
        if cfg.modules and cfg.modules.dispelHighlight and cfg.modules.dispelHighlight.enabled then
            self:AddDispelHighlight(frame, cfg.modules.dispelHighlight)
        end

        -- Highlight border when this unit is the player's current target
        if cfg.highlightSelected and frame.Border then
            local dr, dg, db, da = self:HexToRGB(cfg.unitBorderColor)
            local hr, hg, hb = self:HexToRGB(self.config.global.highlightColor)
            local baseBorderLevel = frame.Border:GetFrameLevel()

            local function UpdateHighlight()
                if UnitExists(frame.unit) and UnitIsUnit(frame.unit, "target") then
                    frame.Border:SetBackdropBorderColor(hr, hg, hb, da)
                    frame.Border:SetFrameLevel(baseBorderLevel + 20)
                else
                    frame.Border:SetBackdropBorderColor(dr, dg, db, da)
                    frame.Border:SetFrameLevel(baseBorderLevel)
                end
            end

            table.insert(highlightUpdaters, UpdateHighlight)
            hooksecurefunc(frame, "UpdateAllElements", function() UpdateHighlight() end)
        end
    end)

    oUF:SetActiveStyle(styleName)

    -- Spawn each unit frame and position it in the grid
    container.frames = {}
    for i = 1, maxUnits do
        local unit = units[i]
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)

        local childName = (cfg.frameName or "frmdGroup") .. "_" .. i
        local child = oUF:Spawn(unit, childName)

        -- Reparent from PetBattleFrameHider to our container so the
        -- container's state driver controls group-level visibility.
        -- RegisterUnitWatch (set by oUF) stays active to handle
        -- per-unit existence (show only when the unit has data).
        child:SetParent(container)

        child:SetPoint(initialAnchor, container, initialAnchor,
            (col * (cellW + spacingX) + spacingX + unitBorderW) * xMult,
            (row * (cellH + spacingY) + spacingY + unitBorderW) * yMult)

        container.frames[i] = child
    end

    -- Deferred refresh for all child frames
    C_Timer.After(self.config.global.refreshDelay, function()
        for _, child in ipairs(container.frames) do
            if child then
                child:UpdateAllElements("RefreshUnit")
            end
        end
    end)

    -- Hide/show container based on group membership for party frames
    if configKey == "party" then
        RegisterStateDriver(container, "visibility", "[group] show; hide")
    end

    -- Store container reference
    self.groupContainers = self.groupContainers or {}
    self.groupContainers[configKey] = container

    return container
end

--[[ AddBackground
Creates a solid color background texture on the given frame.
* frame - the frame to add a background to
* cfg   - config table containing backgroundColor
--]]
function addon:AddBackground(frame, cfg)
    if not cfg.backgroundColor then return end
    local r, g, b, a = self:HexToRGB(cfg.backgroundColor)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(r, g, b, a)
    frame.Background = bg
end

--[[ AddBorder
Creates a border frame using BackdropTemplate on the given frame.
* frame - the frame to add a border to
* cfg   - config table containing borderColor and borderWidth
--]]
function addon:AddBorder(frame, cfg)
    if not cfg.borderColor or not cfg.borderWidth then return end
    local r, g, b, a = self:HexToRGB(cfg.borderColor)
    local offset = cfg.borderWidth
    frame.Border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    frame.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    frame.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = cfg.borderWidth,
    })
    frame.Border:SetBackdropBorderColor(r, g, b, a)
end

--[[ RegisterHighlightEvent
Registers a single PLAYER_TARGET_CHANGED handler that fires all
collected highlight updaters. Call once after all frames are spawned.
--]]
function addon:RegisterHighlightEvent()
    if #highlightUpdaters == 0 then return end

    self:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        for _, fn in ipairs(highlightUpdaters) do
            fn()
        end
    end)
end
