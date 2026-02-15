local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

addon.sadCore.savedVarsGlobalName = "Framed_Settings_Global"
addon.sadCore.savedVarsPerCharName = "Framed_Settings_Char"
addon.sadCore.compartmentFuncName = "Framed_Compartment_Func"

-- Map oUF unit tokens to config keys
local unitConfigMap = {
    player = "player",
    target = "target",
    targettarget = "targetTarget",
    targettargettarget = "targetTargetTarget",
    focus = "focus",
    focustarget = "focusTarget",
    pet = "pet",
}

-- Group frame definitions: config key → ordered unit list
local groupConfigMap = {
    party = { "player", "party1", "party2", "party3", "party4" },
}

function addon:Initialize()
    self.author = "Rôkk-Wyrmrest Accord"

    self:SetupGlobalSettingsPanel()
    self:SetupPlayerSettingsPanel()
    self:SetupTargetSettingsPanel()
    self:SetupTargetTargetSettingsPanel()
    self:SetupTargetTargetTargetSettingsPanel()
    self:SetupFocusSettingsPanel()
    self:SetupFocusTargetSettingsPanel()
    self:SetupPetSettingsPanel()
    self:SetupPartySettingsPanel()
    self:SetupArenaSettingsPanel()

    self.config = self:GetConfig()
    self.unitFrames = {}

    self:OverridePowerColors()
    self:OverrideReactionColors()
    self:HookDisableBlizzard()

    self:SpawnFrames()
    self:SpawnAuraFilters()
end

--[[ OverridePowerColors
Replaces oUF's default power colors with our global config values.
Must be called before any oUF:Spawn() calls.
--]]
function addon:OverridePowerColors()
    local cfg = self.config.global
    local colors = oUF.colors.power

    local powerMap = {
        { token = "MANA",        enum = Enum.PowerType.Mana,       hex = cfg.manaColor },
        { token = "RAGE",        enum = Enum.PowerType.Rage,       hex = cfg.rageColor },
        { token = "FOCUS",       enum = Enum.PowerType.Focus,      hex = cfg.focusColor },
        { token = "ENERGY",      enum = Enum.PowerType.Energy,     hex = cfg.energyColor },
        { token = "RUNIC_POWER", enum = Enum.PowerType.RunicPower, hex = cfg.runicPowerColor },
        { token = "LUNAR_POWER", enum = Enum.PowerType.LunarPower, hex = cfg.lunarPowerColor },
    }

    for _, entry in ipairs(powerMap) do
        local r, g, b = self:HexToRGB(entry.hex)
        local color = oUF:CreateColor(r, g, b)
        colors[entry.token] = color
        colors[entry.enum] = color
    end
end

--[[ OverrideReactionColors
Replaces oUF's default reaction colors with our global config values.
Must be called before any oUF:Spawn() calls.
--]]
function addon:OverrideReactionColors()
    local cfg = self.config.global
    local colors = oUF.colors.reaction

    -- Reactions 1-3 are hostile, 4 is neutral, 5-8 are friendly
    for i = 1, 3 do
        local r, g, b = self:HexToRGB(cfg.hostileColor)
        colors[i] = oUF:CreateColor(r, g, b)
    end

    do
        local r, g, b = self:HexToRGB(cfg.neutralColor)
        colors[4] = oUF:CreateColor(r, g, b)
    end

    for i = 5, 8 do
        local r, g, b = self:HexToRGB(cfg.friendlyColor)
        colors[i] = oUF:CreateColor(r, g, b)
    end
end

--[[ HookDisableBlizzard
Overrides oUF.DisableBlizzard so that Blizzard frames are only hidden
when the corresponding unit config has hideBlizzard = true.
Must be called before any oUF:Spawn() calls.
--]]
function addon:HookDisableBlizzard()
    local originalDisableBlizzard = oUF.DisableBlizzard

    oUF.DisableBlizzard = function(oufSelf, unit)
        -- Check single unit frames
        local configKey = unitConfigMap[unit]
        if configKey then
            local unitCfg = addon.config[configKey]
            if unitCfg and not unitCfg.hideBlizzard then
                return
            end
        end

        -- Check group frames (e.g. "party1" → "party", "arena2" → "arena")
        local groupKey = unit:match("^(%a+)%d*$")
        if groupKey and groupConfigMap[groupKey] then
            local groupCfg = addon.config[groupKey]
            if groupCfg and not groupCfg.hideBlizzard then
                return
            end
        end

        originalDisableBlizzard(oufSelf, unit)
    end
end

--[[ AddTextureBorder
Creates a pixel border around a frame using overlay textures.
Reused by aura buttons (buffs, debuffs) and other small frames.
* frame       - the frame to add a border to
* borderWidth - border thickness in pixels (default 1)
* hexColor    - border color as hex string (default "000000FF")
--]]
function addon:AddTextureBorder(frame, borderWidth, hexColor)
    borderWidth = borderWidth or 1
    local r, g, b, a = self:HexToRGB(hexColor or "000000FF")

    frame.borderTop = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borderTop:SetColorTexture(r, g, b, a)
    frame.borderTop:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    frame.borderTop:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.borderTop:SetHeight(borderWidth)

    frame.borderBottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borderBottom:SetColorTexture(r, g, b, a)
    frame.borderBottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.borderBottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.borderBottom:SetHeight(borderWidth)

    frame.borderLeft = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borderLeft:SetColorTexture(r, g, b, a)
    frame.borderLeft:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    frame.borderLeft:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    frame.borderLeft:SetWidth(borderWidth)

    frame.borderRight = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borderRight:SetColorTexture(r, g, b, a)
    frame.borderRight:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    frame.borderRight:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
    frame.borderRight:SetWidth(borderWidth)
end

--[[ StyleAuraButton
Applies consistent styling to an oUF aura button (buff or debuff).
Crops icon edges, removes default overlay, adds a pixel border,
styles the stack count font, and configures cooldown appearance.
* button      - the aura button created by oUF
* borderWidth - border thickness in pixels (default 1)
* borderColor - border color as hex string (default "000000FF")
* options     - optional table with additional styling:
*   showSwipe           - show cooldown swipe animation (default true)
*   showCooldownNumbers - show countdown numbers on cooldown (default true)
--]]
function addon:StyleAuraButton(button, borderWidth, borderColor, options)
    options = options or {}

    -- Crop icon edges
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Remove default overlay texture (present on oUF aura buttons, not on plain buttons)
    if button.Overlay then
        button.Overlay:SetTexture(nil)
    end

    -- Add pixel border
    self:AddTextureBorder(button, borderWidth, borderColor)

    -- Style stack count
    local fontPath = self:GetFontPath()
    button.Count:ClearAllPoints()
    button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, 0)
    button.Count:SetFont(fontPath, 10, "OUTLINE")
    button.Count:SetDrawLayer("OVERLAY", 7)

    -- Cooldown styling
    if button.Cooldown then
        button.Cooldown:SetDrawEdge(false)
        button.Cooldown:SetReverse(true)

        local showSwipe = options.showSwipe ~= false
        button.Cooldown:SetDrawSwipe(showSwipe)

        local showNumbers = options.showCooldownNumbers ~= false
        button.Cooldown.noCooldownCount = not showNumbers
        button.Cooldown:SetHideCountdownNumbers(not showNumbers)
    end

    -- Proc glow (animated flipbook border)
    if options.showGlow then
        local procGlow = CreateFrame("Frame", nil, button)
        procGlow:SetSize(button:GetWidth() * 1.4, button:GetHeight() * 1.4)
        procGlow:SetPoint("CENTER")

        local procLoop = procGlow:CreateTexture(nil, "ARTWORK")
        procLoop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
        procLoop:SetAllPoints(procGlow)
        procLoop:SetAlpha(0)

        if options.glowColor then
            local gr, gg, gb = self:HexToRGB(options.glowColor)
            procLoop:SetDesaturated(true)
            procLoop:SetVertexColor(gr, gg, gb)
        end

        procGlow.ProcLoopFlipbook = procLoop

        local procLoopAnim = procGlow:CreateAnimationGroup()
        procLoopAnim:SetLooping("REPEAT")

        local alpha = procLoopAnim:CreateAnimation("Alpha")
        alpha:SetChildKey("ProcLoopFlipbook")
        alpha:SetDuration(0.001)
        alpha:SetOrder(0)
        alpha:SetFromAlpha(1)
        alpha:SetToAlpha(1)

        local flip = procLoopAnim:CreateAnimation("FlipBook")
        flip:SetChildKey("ProcLoopFlipbook")
        flip:SetDuration(1)
        flip:SetOrder(0)
        flip:SetFlipBookRows(6)
        flip:SetFlipBookColumns(5)
        flip:SetFlipBookFrames(30)

        procGlow.ProcLoop = procLoopAnim
        procGlow:Hide()
        button.ProcGlow = procGlow
    end
end

--[[ SpawnFrames
Uses oUF:Factory to queue frame creation at PLAYER_LOGIN.
Iterates unitConfigMap for single frames and groupConfigMap for group frames.
--]]
function addon:SpawnFrames()
    oUF:Factory(function()
        -- Single unit frames
        for unit, configKey in pairs(unitConfigMap) do
            if addon.config[configKey].enabled then
                addon:SpawnUnitFrame(unit, configKey)
            end
        end

        -- Group frames (party, arena, raid, etc.)
        for configKey, units in pairs(groupConfigMap) do
            if addon.config[configKey] and addon.config[configKey].enabled then
                if addon.config[configKey].hideBlizzard then
                    oUF:DisableBlizzard(configKey)
                end
                addon:SpawnGroupFrames(configKey, units)
            end
        end

        -- Register highlight event once after all frames are spawned
        addon:RegisterHighlightEvent()
    end)
end

--[[ SpawnAuraFilters
Creates standalone AuraFilter frames defined at the top level of config.
These are not attached to any unit frame and require units to be specified.
--]]
function addon:SpawnAuraFilters()
    local filters = self.config.auraFilters
    if not filters then return end

    for _, cfg in ipairs(filters) do
        if cfg.enabled then
            self:CreateAuraFilter(cfg)
        end
    end
end

-- --------------------------------------------------------------------------------
-- -- POC: All Filter Frames — HELPFUL (left) and HARMFUL (right)
-- -- One row of icons per filter, stacked vertically on each side of the screen.
-- -- Updates on UNIT_AURA for party1.
-- --------------------------------------------------------------------------------
-- do
--     local ICON_SIZE = 30
--     local SPACING = 2
--     local MAX_ICONS = 10
--     local COLS = 10
--     local UNITS = { "party1" }
--     local ROW_HEIGHT = ICON_SIZE + 16 -- icon + gap between rows
--     local POC_FONT = "Fonts\\FRIZQT__.TTF"

--     local FILTERS = {
--         "PLAYER",
--         "CANCELABLE",
--         "NOT_CANCELABLE",
--         "RAID",
--         "INCLUDE_NAME_PLATE_ONLY",
--         "EXTERNAL_DEFENSIVE",
--         "CROWD_CONTROL",
--         "RAID_IN_COMBAT",
--         "RAID_PLAYER_DISPELLABLE",
--         "BIG_DEFENSIVE",
--         "IMPORTANT",
--         "MAW",
--     }

--     local allRefreshFuncs = {}

--     local function FormatDuration(timeLeft)
--         if timeLeft <= 0 then return "" end
--         if timeLeft < 60 then
--             return string.format("%d", timeLeft)
--         elseif timeLeft < 3600 then
--             return string.format("%dm", math.floor(timeLeft / 60))
--         else
--             return string.format("%dh", math.floor(timeLeft / 3600))
--         end
--     end

--     -- Factory: creates one filter row
--     -- baseFilter  - "HELPFUL" or "HARMFUL"
--     -- filterName  - e.g. "CANCELABLE"
--     -- anchor      - "TOPLEFT" or "TOPRIGHT"
--     -- rowIndex    - 0-based row number for vertical stacking
--     local function CreateFilterRow(baseFilter, filterName, anchor, rowIndex)
--         local frameName = "frmdPOC_" .. baseFilter .. "_" .. filterName
--         local testFilter = baseFilter .. "|" .. filterName
--         local isHelpful = baseFilter == "HELPFUL"

--         local container = CreateFrame("Frame", frameName, UIParent)
--         container:SetSize(
--             COLS * ICON_SIZE + (COLS - 1) * SPACING + 4,
--             ICON_SIZE + 4
--         )

--         local xOff = anchor == "TOPLEFT" and 10 or -10
--         local yOff = -(10 + rowIndex * ROW_HEIGHT)
--         container:SetPoint(anchor, UIParent, anchor, xOff, yOff)

--         local bg = container:CreateTexture(nil, "BACKGROUND")
--         bg:SetAllPoints()
--         bg:SetColorTexture(0, 0, 0, 0.4)

--         -- Title label on top
--         local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
--         title:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 1)
--         title:SetText(filterName)
--         title:SetTextColor(isHelpful and 0.4 or 1, isHelpful and 1 or 0.4, 0.4)

--         -- Count label showing how many matched
--         local countLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
--         countLabel:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, 1)
--         countLabel:SetTextColor(0.7, 0.7, 0.7)

--         local buttons = {}

--         for i = 1, MAX_ICONS do
--             local btn = CreateFrame("Button", frameName .. "_" .. i, container)
--             btn:SetSize(ICON_SIZE, ICON_SIZE)

--             local col = (i - 1) % COLS
--             btn:SetPoint("TOPLEFT", container, "TOPLEFT",
--                 2 + col * (ICON_SIZE + SPACING), -2)

--             btn.Icon = btn:CreateTexture(nil, "ARTWORK")
--             btn.Icon:SetAllPoints()
--             btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

--             btn.Cooldown = CreateFrame("Cooldown", "$parentCD", btn, "CooldownFrameTemplate")
--             btn.Cooldown:SetAllPoints()
--             btn.Cooldown:SetDrawEdge(false)
--             btn.Cooldown:SetReverse(true)
--             btn.Cooldown:SetDrawSwipe(true)
--             btn.Cooldown:SetHideCountdownNumbers(false)

--             btn.Count = btn:CreateFontString(nil, "OVERLAY")
--             btn.Count:SetFont(POC_FONT, 9, "OUTLINE")
--             btn.Count:SetPoint("BOTTOMRIGHT", 2, 0)

--             -- Tooltip
--             btn:EnableMouse(true)
--             btn:SetScript("OnEnter", function(self)
--                 if self.auraInstanceID and self.auraUnit then
--                     GameTooltip:SetOwner(self, "ANCHOR_TOP")
--                     if isHelpful then
--                         GameTooltip:SetUnitBuffByAuraInstanceID(self.auraUnit, self.auraInstanceID, baseFilter)
--                     else
--                         GameTooltip:SetUnitDebuffByAuraInstanceID(self.auraUnit, self.auraInstanceID, baseFilter)
--                     end
--                     GameTooltip:Show()
--                 end
--             end)
--             btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

--             btn:Hide()
--             buttons[i] = btn
--         end

--         local function Refresh()
--             local matched = {}
--             for _, unit in ipairs(UNITS) do
--                 if UnitExists(unit) then
--                     local slots = { C_UnitAuras.GetAuraSlots(unit, baseFilter) }
--                     for i = 2, #slots do
--                         local data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
--                         if data then
--                             local filtered = addon:SecureCall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, data.auraInstanceID, testFilter)
--                             if filtered == false then
--                                 matched[#matched + 1] = { unit = unit, aura = data }
--                             end
--                         end
--                     end
--                 end
--             end

--             countLabel:SetText(#matched)

--             for i = 1, MAX_ICONS do
--                 local btn = buttons[i]
--                 local match = matched[i]
--                 local aura = match and match.aura
--                 if aura then
--                     btn.auraInstanceID = aura.auraInstanceID
--                     btn.auraUnit = match.unit

--                     local usedPassThrough = addon:SecureCall(function()
--                         btn.Icon:SetTexture(aura.icon)
--                         return true
--                     end)
--                     if not usedPassThrough then
--                         btn.Icon:SetTexture(nil)
--                     end
--                     btn.Count:Hide()

--                     -- SetCooldownFromExpirationTime is AllowedWhenTainted —
--                     -- it accepts secret values directly, no reading/comparing needed.
--                     -- If duration is 0 (permanent), the C-side handles it.
--                     addon:SecureCall(function()
--                         btn.Cooldown:SetCooldownFromExpirationTime(aura.expirationTime, aura.duration)
--                         return true
--                     end)

--                     btn:Show()
--                 else
--                     btn.auraInstanceID = nil
--                     btn.auraUnit = nil
--                     btn:Hide()
--                 end
--             end
--         end

--         allRefreshFuncs[#allRefreshFuncs + 1] = Refresh
--     end

--     -- Create all HELPFUL rows on the left
--     for i, filterName in ipairs(FILTERS) do
--         CreateFilterRow("HELPFUL", filterName, "TOPLEFT", i - 1)
--     end

--     -- Create all HARMFUL rows on the right
--     for i, filterName in ipairs(FILTERS) do
--         CreateFilterRow("HARMFUL", filterName, "TOPRIGHT", i - 1)
--     end

--     -- Shared event frame for UNIT_AURA + GROUP_ROSTER_UPDATE + PLAYER_REGEN_ENABLED
--     local eventFrame = CreateFrame("Frame")
--     eventFrame:SetScript("OnEvent", function(self, event)
--         if event == "GROUP_ROSTER_UPDATE" then
--             self:UnregisterEvent("UNIT_AURA")
--             for _, unit in ipairs(UNITS) do
--                 if UnitExists(unit) then
--                     self:RegisterUnitEvent("UNIT_AURA", unit)
--                 end
--             end
--         end
--         -- Refresh all rows on any event
--         for _, fn in ipairs(allRefreshFuncs) do
--             fn()
--         end
--     end)
--     eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
--     eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

--     C_Timer.After(2, function()
--         local any = false
--         for _, unit in ipairs(UNITS) do
--             if UnitExists(unit) then
--                 eventFrame:RegisterUnitEvent("UNIT_AURA", unit)
--                 any = true
--             end
--         end
--         if any then
--             for _, fn in ipairs(allRefreshFuncs) do
--                 fn()
--             end
--         end
--     end)
-- end

