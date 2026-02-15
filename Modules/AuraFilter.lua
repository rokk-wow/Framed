local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

--------------------------------------------------------------------------------
-- AuraFilter Engine
--
-- A standalone, event-driven frame that monitors one or more units for auras
-- matching Blizzard's filter system (e.g. HELPFUL|EXTERNAL_DEFENSIVE).
--
-- Displays matching auras up to maxIcons, sorted by Blizzard's priority
-- system (priority auras first, then original order). When maxIcons = 1,
-- the highest-priority aura is shown (or the first match if none have priority).
--
-- Works for both unit-specific monitoring (e.g. player externals) and
-- group-wide monitoring (e.g. party crowd control).
--
-- Unit source:
--   units – array of unit tokens, e.g. {"player"}, {"target", "focus"}
--     Special expandable tokens (resolved dynamically at runtime):
--       "party" – raid1‥N in raid, player+party1‥4 in party, player when solo
--       "raid"  – raid1‥N
--       "arena" – arena1‥5
--     Can be mixed: {"party", "focus"} monitors all party members + focus
--
-- Filter behavior:
--   baseFilter selects aura polarity (HELPFUL or HARMFUL).
--   subFilters narrows results to specific Blizzard categories.
--   Multiple subFilters use OR logic (aura matches if ANY sub-filter passes).
--   Omit subFilters entirely to show all auras of the base type.
--
--   Examples:
--     baseFilter = "HELPFUL"                                → all buffs
--     baseFilter = "HARMFUL", subFilters = {"CROWD_CONTROL"} → CC debuffs only
--     subFilters = {"BIG_DEFENSIVE", "EXTERNAL_DEFENSIVE"}   → either matches
--
-- Available sub-filters (from AuraUtil.AuraFilters):
--   RAID, INCLUDE_NAME_PLATE_ONLY, PLAYER, CANCELABLE, NOT_CANCELABLE,
--   MAW, EXTERNAL_DEFENSIVE, CROWD_CONTROL, RAID_IN_COMBAT,
--   RAID_PLAYER_DISPELLABLE, BIG_DEFENSIVE, IMPORTANT
--------------------------------------------------------------------------------

local AuraFilterMixin = {}

-- Expanders for special unit tokens in the units array.
-- These resolve dynamic group compositions at runtime.
local UNIT_EXPANDERS = {
    party = function()
        local units = {}
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                units[#units + 1] = "raid" .. i
            end
        elseif IsInGroup() then
            units[#units + 1] = "player"
            for i = 1, 4 do
                units[#units + 1] = "party" .. i
            end
        else
            units[#units + 1] = "player"
        end
        return units
    end,
    raid = function()
        local units = {}
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
        return units
    end,
    arena = function()
        local units = {}
        for i = 1, 5 do
            units[#units + 1] = "arena" .. i
        end
        return units
    end,
}

-- Events to register when monitoring specific unit tokens,
-- to catch unit identity changes (e.g. player switches target).
local UNIT_CHANGE_EVENTS = {
    target = "PLAYER_TARGET_CHANGED",
    focus = "PLAYER_FOCUS_CHANGED",
}

--[[ Init
Initializes the AuraFilter engine on this frame.
Called automatically by addon:CreateAuraFilter().
* cfg - configuration table (see CreateAuraFilter for full documentation)
--]]
function AuraFilterMixin:Init(cfg)
    self.baseFilter = cfg.baseFilter or "HELPFUL"
    self.units = cfg.units or {}
    self.isHelpful = (self.baseFilter == "HELPFUL")

    -- Check if any unit tokens require dynamic expansion (party/raid/arena)
    self.hasDynamicUnits = false
    for _, token in ipairs(self.units) do
        if UNIT_EXPANDERS[token] then
            self.hasDynamicUnits = true
            break
        end
    end

    -- Display settings
    self.iconSize = cfg.iconSize or 30
    self.iconBorderWidth = cfg.iconBorderWidth or 1
    self.spacingX = cfg.spacingX or 2
    self.spacingY = cfg.spacingY or 2
    self.maxIcons = cfg.maxIcons or 10
    self.perRow = cfg.perRow or self.maxIcons
    self.growthX = cfg.growthX or "RIGHT"
    self.growthY = cfg.growthY or "DOWN"

    -- Placeholder settings
    local ph = cfg.placeholderIcon
    if ph and ph ~= "" then
        -- Accept short icon names (e.g. "spell_nature_polymorph"),
        -- full paths, or numeric fileData IDs
        if tonumber(ph) then
            self.placeholderIcon = tonumber(ph)
        elseif not ph:find("[/\\]") then
            self.placeholderIcon = "Interface\\Icons\\" .. ph
        else
            self.placeholderIcon = ph
        end
    end
    self.placeholderDesaturate = cfg.placeholderDesaturate or false
    if cfg.placeholderColor then
        local r, g, b, a = addon:HexToRGB(cfg.placeholderColor)
        self.placeholderColor = { r, g, b, a }
    end

    -- Build test filter strings: baseFilter .. "|" .. each subFilter
    -- OR logic: aura passes if it matches ANY test filter
    local subFilters = cfg.subFilters or {}
    self.testFilters = {}
    for _, sub in ipairs(subFilters) do
        self.testFilters[#self.testFilters + 1] = self.baseFilter .. "|" .. sub
    end
    if #self.testFilters == 0 then
        self.useBaseOnly = true
    end

    -- Build exclude filter strings: auras matching ANY exclude filter are rejected
    -- Useful for filters broken server-side (e.g. NOT_CANCELABLE → exclude CANCELABLE)
    local excludeSubFilters = cfg.excludeSubFilters or {}
    self.excludeFilters = {}
    for _, sub in ipairs(excludeSubFilters) do
        self.excludeFilters[#self.excludeFilters + 1] = self.baseFilter .. "|" .. sub
    end

    -- Priority filter: used to identify important/priority auras via the C-side
    -- IsAuraFilteredOutByInstanceID (AllowedWhenTainted), avoiding secret spellId
    self.priorityFilter = self.baseFilter .. "|IMPORTANT"

    -- Container sizing (includes padding = spacing between icons and container edge)
    -- Each icon's visual footprint = iconSize + 2 * iconBorderWidth (borders extend outside)
    local cols = math.min(self.perRow, self.maxIcons)
    local rows = math.ceil(self.maxIcons / cols)
    local cellW = self.iconSize + 2 * self.iconBorderWidth
    local cellH = self.iconSize + 2 * self.iconBorderWidth
    self:SetSize(
        cols * cellW + math.max(0, cols - 1) * self.spacingX + 2 * self.spacingX,
        rows * cellH + math.max(0, rows - 1) * self.spacingY + 2 * self.spacingY
    )

    -- Create aura icons
    self.icons = {}
    self:CreateIcons(cfg)

    -- Track monitored units
    self.currentUnits = {}
    self.unitLookup = {}

    -- Events
    self:SetScript("OnEvent", self.OnEvent)
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    if self.hasDynamicUnits then
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
    end

    -- Register change events for static units (target/focus switches)
    for _, unit in ipairs(self.units) do
        local changeEvent = UNIT_CHANGE_EVENTS[unit]
        if changeEvent then
            self:RegisterEvent(changeEvent)
        end
    end

    -- Deferred initial registration to allow frames and units to exist
    C_Timer.After(0.5, function()
        if self then
            self:UpdateUnits()
        end
    end)

    -- Re-register and refresh when the frame becomes visible again
    -- (e.g. after party container state driver shows it on group join)
    self:SetScript("OnShow", function(s)
        s:UpdateUnits()
    end)
end

--[[ CreateIcons
Pre-creates all aura icon frames for the maximum icon count.
Icons are positioned in a grid according to growth direction and
styled using the shared StyleAuraButton helper.
* cfg - the configuration table passed to Init
--]]
function AuraFilterMixin:CreateIcons(cfg)
    local isHelpful = self.isHelpful
    local baseFilter = self.baseFilter
    local tooltipAnchor = cfg.tooltipAnchor or "ANCHOR_TOP"
    local disableMouse = cfg.disableMouse or false

    -- Derive initial anchor from growth direction
    local vertAnchor = (self.growthY == "DOWN") and "TOP" or "BOTTOM"
    local horizAnchor = (self.growthX == "LEFT") and "RIGHT" or "LEFT"
    local initialAnchor = vertAnchor .. horizAnchor

    local xMult = (self.growthX == "LEFT") and -1 or 1
    local yMult = (self.growthY == "UP") and 1 or -1

    for i = 1, self.maxIcons do
        local icon = CreateFrame("Button", (self:GetName() or "") .. "_" .. i, self)
        icon:SetSize(self.iconSize, self.iconSize)

        local col = (i - 1) % self.perRow
        local row = math.floor((i - 1) / self.perRow)
        local cellW = self.iconSize + 2 * self.iconBorderWidth
        local cellH = self.iconSize + 2 * self.iconBorderWidth
        icon:SetPoint(initialAnchor, self, initialAnchor,
            (col * (cellW + self.spacingX) + self.spacingX + self.iconBorderWidth) * xMult,
            (row * (cellH + self.spacingY) + self.spacingY + self.iconBorderWidth) * yMult)

        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetAllPoints()

        -- Placeholder texture (separate BACKGROUND layer, sits behind Icon)
        if self.placeholderIcon then
            icon.Placeholder = icon:CreateTexture(nil, "BACKGROUND")
            icon.Placeholder:SetAllPoints()
            icon.Placeholder:SetTexture(self.placeholderIcon)
            icon.Placeholder:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon.Placeholder:SetDesaturated(self.placeholderDesaturate)
            if self.placeholderColor then
                icon.Placeholder:SetVertexColor(unpack(self.placeholderColor))
            end
        end

        icon.Cooldown = CreateFrame("Cooldown", "$parentCD", icon, "CooldownFrameTemplate")
        icon.Cooldown:SetAllPoints()

        icon.Count = icon:CreateFontString(nil, "OVERLAY")

        -- Tooltip (uses Button frame type for mouse interaction)
        icon:EnableMouse(not disableMouse)
        icon:SetScript("OnEnter", function(self)
            if self.auraInstanceID and self.auraUnit then
                GameTooltip:SetOwner(self, tooltipAnchor)
                if isHelpful then
                    GameTooltip:SetUnitBuffByAuraInstanceID(
                        self.auraUnit, self.auraInstanceID, baseFilter)
                else
                    GameTooltip:SetUnitDebuffByAuraInstanceID(
                        self.auraUnit, self.auraInstanceID, baseFilter)
                end
                GameTooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Right-click to cancel buffs (player/vehicle only)
        if isHelpful and not disableMouse then
            icon:RegisterForClicks("RightButtonUp")
            icon:SetScript("OnClick", function(self, mouseButton)
                if mouseButton == "RightButton" and self.auraInstanceID and self.auraUnit then
                    local unit = self.auraUnit
                    if unit == "player" or unit == "vehicle" then
                        addon:SecureCall(function()
                            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, self.auraInstanceID)
                            if data and data.name then
                                CancelSpellByName(data.name)
                            end
                        end)
                    end
                end
            end)
        end

        -- Shared aura icon styling (border, cooldown, count font, glow)
        addon:StyleAuraButton(icon,
            cfg.iconBorderWidth or 1,
            cfg.iconBorderColor or "000000FF",
            {
                showSwipe = cfg.showSwipe,
                showCooldownNumbers = cfg.showCooldownNumbers,
                showGlow = cfg.showGlow,
                glowColor = cfg.glowColor,
            })

        icon:Hide()
        self.icons[i] = icon
    end
end

--[[ GetMonitoredUnits
Returns the current list of unit tokens to monitor.
Expands special tokens (party, raid, arena) into concrete unit IDs.
Static tokens (player, target, focus, pet, etc.) pass through as-is.
--]]
function AuraFilterMixin:GetMonitoredUnits()
    local resolved = {}
    for _, token in ipairs(self.units) do
        local expander = UNIT_EXPANDERS[token]
        if expander then
            for _, unit in ipairs(expander()) do
                resolved[#resolved + 1] = unit
            end
        else
            resolved[#resolved + 1] = token
        end
    end
    return resolved
end

--[[ UpdateUnits
Refreshes the monitored unit list and re-registers UNIT_AURA events.
Called on GROUP_ROSTER_UPDATE for group modes, PLAYER_TARGET_CHANGED for
target-based units, and during initialization.
--]]
function AuraFilterMixin:UpdateUnits()
    self:UnregisterEvent("UNIT_AURA")

    self.currentUnits = self:GetMonitoredUnits()

    -- Build lookup for fast unit checking in event handler
    self.unitLookup = {}
    local existingUnits = {}
    for _, unit in ipairs(self.currentUnits) do
        if UnitExists(unit) then
            self.unitLookup[unit] = true
            existingUnits[#existingUnits + 1] = unit
        end
    end

    -- Register UNIT_AURA efficiently based on unit count.
    -- RegisterUnitEvent supports up to 2 units for pre-filtering;
    -- for >2 units we use generic registration with a lookup filter.
    if #existingUnits == 1 then
        self:RegisterUnitEvent("UNIT_AURA", existingUnits[1])
    elseif #existingUnits == 2 then
        self:RegisterUnitEvent("UNIT_AURA", existingUnits[1], existingUnits[2])
    elseif #existingUnits > 2 then
        self:RegisterEvent("UNIT_AURA")
    end

    self:Refresh()
end

--[[ OnEvent
Central event handler. Routes to UpdateUnits for roster/target changes,
and Refresh for aura/combat events.
Filters UNIT_AURA by monitored unit set when using generic registration.
--]]
function AuraFilterMixin:OnEvent(event, unit)
    if event == "GROUP_ROSTER_UPDATE"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_FOCUS_CHANGED" then
        self:UpdateUnits()
        return
    end

    if event == "UNIT_AURA" then
        -- For generic registration (>2 units), filter by our monitored set
        if not self.unitLookup[unit] then
            return
        end
    end

    self:Refresh()
end

--[[ MatchesFilter
Tests whether an aura passes the configured include/exclude filters.
Inclusion: aura passes if it matches at least one sub-filter (OR logic),
           or always passes if no sub-filters are configured.
Exclusion: aura is rejected if it matches ANY exclude filter.
* unit           - the unit token
* auraInstanceID - the aura's instance ID
--]]
function AuraFilterMixin:MatchesFilter(unit, auraInstanceID)
    -- Check exclude filters first (reject if ANY match)
    for _, excludeFilter in ipairs(self.excludeFilters) do
        local filtered = addon:SecureCall(
            C_UnitAuras.IsAuraFilteredOutByInstanceID,
            unit, auraInstanceID, excludeFilter)
        if filtered == false then
            return false
        end
    end

    -- Check include filters (pass if ANY match, or if none configured)
    if self.useBaseOnly then
        return true
    end
    for _, testFilter in ipairs(self.testFilters) do
        local filtered = addon:SecureCall(
            C_UnitAuras.IsAuraFilteredOutByInstanceID,
            unit, auraInstanceID, testFilter)
        if filtered == false then
            return true
        end
    end
    return false
end

--[[ Refresh
Queries all monitored units for matching auras and updates icon display.
Collects all matches, sorts by Blizzard priority (priority auras first,
original order preserved otherwise), then displays the top maxIcons.
Priority is determined via C_UnitAuras.IsAuraFilteredOutByInstanceID with the
IMPORTANT filter. This C-side function (AllowedWhenTainted) accepts auraInstanceID
(non-secret) and handles spellId lookup internally, avoiding the secret-value
errors that plague AuraUtil.IsPriorityDebuff and C_Spell.IsPriorityAura.
--]]
function AuraFilterMixin:Refresh()
    local matched = {}

    for _, unit in ipairs(self.currentUnits or {}) do
        if UnitExists(unit) then
            local slots = { C_UnitAuras.GetAuraSlots(unit, self.baseFilter) }
            for i = 2, #slots do
                local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
                if data and self:MatchesFilter(unit, data.auraInstanceID) then
                    local idx = #matched + 1
                    -- IsAuraFilteredOutByInstanceID returns false when the aura
                    -- PASSES the filter (is not filtered out)
                    local filtered = addon:SecureCall(
                        C_UnitAuras.IsAuraFilteredOutByInstanceID,
                        unit, data.auraInstanceID, self.priorityFilter)
                    matched[idx] = {
                        unit = unit,
                        aura = data,
                        order = idx,
                        isPriority = (filtered == false),
                    }
                end
            end
        end
    end

    -- Sort by priority first, then preserve original order
    table.sort(matched, function(a, b)
        if a.isPriority ~= b.isPriority then
            return a.isPriority
        end
        return a.order < b.order
    end)

    -- Update icon display
    for i = 1, self.maxIcons do
        local icon = self.icons[i]
        local match = matched[i]
        if match then
            local aura = match.aura
            icon.auraInstanceID = aura.auraInstanceID
            icon.auraUnit = match.unit

            -- Icon texture (may be a secret value in PvP)
            local iconSet = addon:SecureCall(function()
                icon.Icon:SetTexture(aura.icon)
                return true
            end)
            if not iconSet then
                icon.Icon:SetTexture(nil)
            end
            icon.Icon:SetDesaturated(false)
            icon.Icon:SetVertexColor(1, 1, 1, 1)
            if icon.Placeholder then
                icon.Placeholder:Hide()
            end

            icon.Count:Hide()

            -- Cooldown (expirationTime/duration may be secret)
            icon.Cooldown:Show()
            addon:SecureCall(function()
                icon.Cooldown:SetCooldownFromExpirationTime(
                    aura.expirationTime, aura.duration)
                return true
            end)

            -- Proc glow
            if icon.ProcGlow then
                icon.ProcGlow:Show()
                icon.ProcGlow.ProcLoop:Play()
            end

            icon:Show()
        else
            icon.auraInstanceID = nil
            icon.auraUnit = nil
            icon.Icon:SetTexture(nil)
            icon.Cooldown:Clear()
            icon.Cooldown:Hide()
            if icon.ProcGlow then
                icon.ProcGlow.ProcLoop:Stop()
                icon.ProcGlow:Hide()
            end
            if icon.Placeholder then
                icon.Placeholder:Show()
                icon:Show()
            else
                icon:Hide()
            end
        end
    end
end

--[[ Destroy
Cleans up the AuraFilter, unregistering all events and hiding all icons.
--]]
function AuraFilterMixin:Destroy()
    self:UnregisterAllEvents()
    self:SetScript("OnEvent", nil)
    for _, icon in ipairs(self.icons) do
        icon:Hide()
    end
    self:Hide()
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--[[ CreateAuraFilter
Factory function that creates a standalone AuraFilter frame.
Returns the configured frame.

Configuration options:
  Required:
    baseFilter    - "HELPFUL" or "HARMFUL"
    subFilters    - array of sub-filter strings, include via OR logic
                    e.g. {"EXTERNAL_DEFENSIVE"} or {"BIG_DEFENSIVE", "EXTERNAL_DEFENSIVE"}
                    omit for no sub-filtering (shows all auras of the base type)
    excludeSubFilters - array of sub-filter strings to exclude (aura rejected if ANY match)
                    useful for broken Blizzard filters (e.g. NOT_CANCELABLE doesn't work,
                    so use excludeSubFilters = {"CANCELABLE"} instead)

  Units:
    units         - array of unit tokens, e.g. {"player"} or {"target", "focus"}
                    special tokens "party", "raid", "arena" expand dynamically
                    when nested under a unit frame's modules.auraFilters,
                    defaults to the parent frame's unit (can be overridden)
                    required for top-level (standalone) aura filters

  Display:
    maxIcons      - max icons to display (default: 10; use 1 for single-aura display)
                    results are sorted by Blizzard priority (priority auras first,
                    then original order); with maxIcons = 1, the highest-priority
                    aura is shown (or the first match if none have priority)
    iconSize      - pixel size of each icon (default: 30)
    spacingX      - horizontal gap between icons (default: 2)
    spacingY      - vertical gap between rows (default: 2)
    perRow        - icons per row before wrapping (default: maxIcons)
    growthX       - "LEFT" or "RIGHT" (default: "RIGHT")
    growthY       - "UP" or "DOWN" (default: "DOWN")

  Styling:
    containerBackgroundColor - container background hex color (default: none/transparent)
    containerBorderWidth  - container border width (default: none)
    containerBorderColor  - container border hex color (default: none)
    iconBorderWidth       - aura icon border width (default: 1)
    iconBorderColor       - aura icon border hex color (default: "000000FF")
    showSwipe             - show cooldown swipe animation (default: true)
    showCooldownNumbers   - show countdown numbers (default: true)
    placeholderIcon       - icon texture for empty slots (default: none)
                            e.g. "spell_nature_polymorph"
    placeholderDesaturate - desaturate placeholder icons (default: false)
    placeholderColor      - vertex color hex for placeholder icons (default: none)
    tooltipAnchor         - tooltip anchor point (default: "ANCHOR_TOP")
    disableMouse          - when true, icons ignore mouse input (no tooltips, no clicks)
                            useful for priority indicators that should not block combat input
                            (default: false)

  Anchoring:
    frameName     - global frame name (optional)
    anchor        - anchor point (default: "CENTER")
    relativeTo    - relative frame name string (default: parent)
    relativePoint - relative anchor point (default: "CENTER")
    offsetX       - horizontal offset (default: 0)
    offsetY       - vertical offset (default: 0)

Examples:
  -- Player external defensives
  addon:CreateAuraFilter({
      frameName = "frmdPlayerExternals",
      units = {"player"},
      baseFilter = "HELPFUL",
      subFilters = {"EXTERNAL_DEFENSIVE"},
      iconSize = 30,
      maxIcons = 5,
      anchor = "BOTTOMLEFT",
      relativeTo = "frmdPlayerFrame",
      relativePoint = "TOPLEFT",
  })

  -- All defensives on player (BIG_DEFENSIVE OR EXTERNAL_DEFENSIVE)
  addon:CreateAuraFilter({
      frameName = "frmdPlayerAllDef",
      units = {"player"},
      baseFilter = "HELPFUL",
      subFilters = {"BIG_DEFENSIVE", "EXTERNAL_DEFENSIVE"},
  })

  -- Group crowd control (party-wide, single icon)
  addon:CreateAuraFilter({
      frameName = "frmdGroupCC",
      units = {"party"},
      baseFilter = "HARMFUL",
      subFilters = {"CROWD_CONTROL"},
      maxIcons = 1,
      iconSize = 40,
  })
--]]
function addon:CreateAuraFilter(cfg)
    local parent = cfg.parent or UIParent
    local anchorFrame = cfg.anchorFrame or _G[cfg.relativeTo] or parent
    local frame = CreateFrame("Frame", cfg.frameName, parent)
    frame:SetPoint(
        cfg.anchor or "CENTER",
        anchorFrame,
        cfg.relativePoint or "CENTER",
        cfg.offsetX or 0,
        cfg.offsetY or 0)

    -- Container background
    if cfg.containerBackgroundColor then
        self:AddBackground(frame, { backgroundColor = cfg.containerBackgroundColor })
    end

    -- Container border
    if cfg.containerBorderWidth and cfg.containerBorderColor then
        self:AddBorder(frame, {
            borderWidth = cfg.containerBorderWidth,
            borderColor = cfg.containerBorderColor,
        })
    end

    Mixin(frame, AuraFilterMixin)
    frame:Init(cfg)

    return frame
end

--[[ AddAuraFilter
Module-style wrapper for adding an AuraFilter to an oUF unit frame.
Called from UnitFrame.lua when iterating the auraFilters array in a
unit's modules config.

Defaults units to the parent frame's unit token if not specified.
Units can still be explicitly overridden (e.g. units = {"target"} on
a player frame module).

* frame - the oUF unit frame
* cfg   - aura filter configuration (see CreateAuraFilter)
--]]
function addon:AddAuraFilter(frame, cfg)
    -- Shallow copy so group frames don't share mutable state
    local localCfg = {}
    for k, v in pairs(cfg) do
        localCfg[k] = v
    end
    if not localCfg.units then
        localCfg.units = { frame.unit }
    end
    localCfg.parent = localCfg.parent or frame

    -- Resolve relativeToModule to an actual frame child.
    -- Accepts a single string or an ordered array of strings (fallback chain).
    -- Falls back to the unit frame itself if no referenced module is present.
    if localCfg.relativeToModule then
        local ref = localCfg.relativeToModule
        if type(ref) == "table" then
            for _, key in ipairs(ref) do
                if frame[key] then
                    localCfg.anchorFrame = frame[key]
                    break
                end
            end
            localCfg.anchorFrame = localCfg.anchorFrame or frame
        else
            localCfg.anchorFrame = frame[ref] or frame
        end
    end

    local filter = self:CreateAuraFilter(localCfg)

    -- Store on the parent frame by name so other filters can reference it
    if localCfg.name then
        frame[localCfg.name] = filter
    end

    return filter
end
