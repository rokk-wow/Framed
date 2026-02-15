local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

--[[ AddTrinket
Creates and configures a trinket tracking icon on the given unit frame.
Uses C_PvP.GetArenaCrowdControlInfo / C_PvP.RequestCrowdControlSpell
to detect the opponent's PvP trinket (Gladiator's Medallion or equivalent)
and display its cooldown state.

Visual states:
  Available  – full color, full opacity
  On cooldown – desaturated, reduced opacity, cooldown swipe + timer

Events monitored:
  ARENA_COOLDOWNS_UPDATE          – fires when trinket cooldown changes
  ARENA_CROWD_CONTROL_SPELL_UPDATE – fires with the detected spell ID
  PLAYER_ENTERING_WORLD           – refresh on zone transitions
  GROUP_ROSTER_UPDATE             – group membership changes

* frame - the oUF unit frame
* cfg   - the unit's modules.trinket config table
--]]

-- Default Gladiator's Medallion spell ID (used for initial icon texture)
local DEFAULT_SPELL_ID = 336126

local function IsInArena()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "arena")
end

function addon:AddTrinket(frame, cfg)
    local size = cfg.iconSize or 36
    local borderWidth = cfg.iconBorderWidth or 1

    -- Main container frame (acts as the icon button)
    local trinket = CreateFrame("Frame", nil, frame)
    trinket:SetSize(size, size)

    -- Resolve anchor target: relativeToModule → frame child → frame
    local anchorFrame = frame
    if cfg.relativeToModule then
        local ref = cfg.relativeToModule
        if type(ref) == "table" then
            for _, key in ipairs(ref) do
                if frame[key] then
                    anchorFrame = frame[key]
                    break
                end
            end
        else
            anchorFrame = frame[ref] or frame
        end
    end

    trinket:SetPoint(
        cfg.anchor or "TOPLEFT",
        anchorFrame,
        cfg.relativePoint or "TOPRIGHT",
        cfg.offsetX or 0,
        cfg.offsetY or 0
    )

    -- Icon texture
    local icon = trinket:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(trinket)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    trinket.Icon = icon

    -- Set initial texture from default spell
    local defaultTexture = C_Spell.GetSpellTexture(DEFAULT_SPELL_ID)
    if defaultTexture then
        icon:SetTexture(defaultTexture)
    end

    -- Pixel border (using addon's shared border utility)
    addon:AddTextureBorder(trinket, borderWidth, cfg.iconBorderColor or "000000FF")

    -- Cooldown frame
    local cooldown = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
    cooldown:SetAllPoints(trinket)
    cooldown:SetDrawEdge(false)
    cooldown:SetReverse(true)
    cooldown:SetDrawSwipe(cfg.showSwipe ~= false)
    cooldown.noCooldownCount = not (cfg.showCooldownNumbers ~= false)
    cooldown:SetHideCountdownNumbers(not (cfg.showCooldownNumbers ~= false))
    trinket.Cooldown = cooldown

    -- Config-driven cooldown appearance
    local cooldownDesaturate = cfg.cooldownDesaturate ~= false
    local cooldownAlpha = cfg.cooldownAlpha or 0.5
    local healerReduction = cfg.healerReduction or 30

    -- State tracking
    trinket.spellID = nil
    trinket.unit = nil

    ---------------------------------------------------------------------------
    -- Core update logic
    ---------------------------------------------------------------------------

    local function IsUnitHealer(unit)
        if not unit then return false end
        local role = UnitGroupRolesAssigned(unit)
        return role == "HEALER"
    end

    local function SetSpellTexture(spellID)
        if spellID and spellID > 0 then
            trinket.spellID = spellID
            local tex = C_Spell.GetSpellTexture(spellID)
            if tex then
                icon:SetTexture(tex)
            end
        end
    end

    local function UpdateCooldown()
        local unit = trinket.unit
        if not unit then return end

        local spellID, startTimeMs, durationMs = C_PvP.GetArenaCrowdControlInfo(unit)

        -- Update icon if spell changed
        if spellID and spellID > 0 then
            SetSpellTexture(spellID)
        end

        local startTime = startTimeMs and (startTimeMs / 1000) or 0
        local duration = durationMs and (durationMs / 1000) or 0

        -- Healers have a shorter trinket cooldown (typically 90s vs 120s)
        if duration > 0 and IsUnitHealer(unit) then
            duration = math.max(0, duration - healerReduction)
        end

        if duration > 0 then
            -- Trinket is on cooldown
            cooldown:SetCooldown(startTime, duration)
            if cooldownDesaturate then
                icon:SetDesaturated(true)
            end
            icon:SetAlpha(cooldownAlpha)
        else
            -- Trinket is available
            cooldown:Clear()
            icon:SetDesaturated(false)
            icon:SetAlpha(1)
        end
    end

    local function UpdateVisibility()
        if IsInArena() then
            trinket:Show()
        else
            trinket:Hide()
        end
    end

    local function RequestAndUpdate()
        if not IsInArena() then return end
        local unit = trinket.unit
        if not unit or not UnitExists(unit) then return end
        C_PvP.RequestCrowdControlSpell(unit)
        UpdateCooldown()
    end

    local function ResetState()
        trinket.spellID = nil
        if defaultTexture then
            icon:SetTexture(defaultTexture)
        end
        icon:SetDesaturated(false)
        icon:SetAlpha(1)
        cooldown:Clear()
    end

    ---------------------------------------------------------------------------
    -- Event handling
    ---------------------------------------------------------------------------

    trinket:SetScript("OnEvent", function(self, event, ...)
        if event == "ARENA_COOLDOWNS_UPDATE" then
            local unitTarget = ...
            if unitTarget and unitTarget == trinket.unit then
                UpdateCooldown()
            end
        elseif event == "ARENA_CROWD_CONTROL_SPELL_UPDATE" then
            local unitToken, spellID = ...
            if unitToken and unitToken == trinket.unit then
                SetSpellTexture(spellID)
                UpdateCooldown()
            end
        elseif event == "PVP_MATCH_STATE_CHANGED" then
            local matchState = C_PvP.GetActiveMatchState()
            if matchState == Enum.PvPMatchState.StartUp then
                -- New round: clear cooldown state
                ResetState()
            end
            -- Re-request trinket info for the new round
            RequestAndUpdate()
        elseif event == "PLAYER_ENTERING_WORLD" then
            ResetState()
            UpdateVisibility()
            C_Timer.After(1, RequestAndUpdate)
        elseif event == "GROUP_ROSTER_UPDATE" then
            UpdateVisibility()
            RequestAndUpdate()
        end
    end)

    trinket:RegisterEvent("ARENA_COOLDOWNS_UPDATE")
    trinket:RegisterEvent("ARENA_CROWD_CONTROL_SPELL_UPDATE")
    trinket:RegisterEvent("PVP_MATCH_STATE_CHANGED")
    trinket:RegisterEvent("PLAYER_ENTERING_WORLD")
    trinket:RegisterEvent("GROUP_ROSTER_UPDATE")

    ---------------------------------------------------------------------------
    -- Unit assignment (called by oUF style when unit changes)
    ---------------------------------------------------------------------------

    -- Hook into UpdateAllElements so the trinket updates when oUF refreshes
    hooksecurefunc(frame, "UpdateAllElements", function()
        trinket.unit = frame.unit
        RequestAndUpdate()
    end)

    -- Initial unit assignment
    trinket.unit = frame.unit

    -- Store on the parent frame so other modules can reference it
    frame.Trinket = trinket

    -- Start hidden; will show when entering arena
    trinket:Hide()

    -- Deferred initial check
    C_Timer.After(1, function()
        UpdateVisibility()
        RequestAndUpdate()
    end)
end
