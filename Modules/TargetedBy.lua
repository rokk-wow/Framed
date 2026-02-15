local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

--[[ AddTargetedBy
Creates a small indicator showing how many hostile units are targeting
the frame's unit. "Hostile" is relative to the unit being monitored:

  Friendly unit (party):  counts enemy nameplates targeting this unit
  Enemy unit (arena):     counts friendly group members targeting this unit

Uses timer-based polling with UnitDetailedThreatSituation to determine
which mobs are targeting (have aggro on) the monitored unit. The
"nameplateXtarget" unit tokens are inaccessible in PvE, so we check
the isTanking return from the threat API instead.

* frame - the oUF unit frame
* cfg   - the unit's modules.targetedBy config table
--]]

local SCAN_INTERVAL = 0.5

function addon:AddTargetedBy(frame, cfg)
    local size = cfg.size or 36
    local borderWidth = cfg.borderWidth or 1

    -- Main container
    local container = CreateFrame("Frame", nil, frame)
    container:SetSize(size, size)

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

    container:SetPoint(
        cfg.anchor or "TOPLEFT",
        anchorFrame,
        cfg.relativePoint or "TOPRIGHT",
        cfg.offsetX or 0,
        cfg.offsetY or 0
    )

    -- Background
    if cfg.backgroundColor then
        local r, g, b, a = addon:HexToRGB(cfg.backgroundColor)
        local bg = container:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(container)
        bg:SetColorTexture(r, g, b, a)
    end

    -- Border
    addon:AddTextureBorder(container, borderWidth, cfg.borderColor or "000000FF")

    -- Count text
    local fontPath = addon:GetFontPath()
    local textSize = cfg.textSize or 14
    local text = container:CreateFontString(nil, "OVERLAY")
    text:SetFont(fontPath, textSize, "OUTLINE")
    text:SetPoint("CENTER", container, "CENTER", 0, 0)

    -- Active color (when count > 0)
    local ar, ag, ab, aa = 1, 1, 1, 1
    if cfg.textColor then
        ar, ag, ab, aa = addon:HexToRGB(cfg.textColor)
    end

    -- Inactive color (when count == 0)
    local ir, ig, ib, ia = 0.47, 0.47, 0.47, 0.67
    if cfg.inactiveTextColor then
        ir, ig, ib, ia = addon:HexToRGB(cfg.inactiveTextColor)
    end

    text:SetTextColor(ar, ag, ab, aa)
    container.Text = text

    -- State
    container.unit = nil
    container.count = 0
    container.scanTimer = nil

    ---------------------------------------------------------------------------
    -- Core logic (pcall + UnitGUID pattern from WhosTargeted)
    ---------------------------------------------------------------------------

    local function CountEnemiesTargeting(unit)
        local count = 0
        for i = 1, 40 do
            local enemyUnit = "nameplate" .. i
            if UnitExists(enemyUnit) and UnitCanAttack("player", enemyUnit) then
                local isTanking = UnitDetailedThreatSituation(unit, enemyUnit)
                if isTanking then
                    count = count + 1
                end
            end
        end
        return count
    end

    local function CountFriendliesTargeting(unit)
        local count = 0

        -- Check player's target
        if UnitExists("target") and UnitIsUnit("target", unit) then
            count = count + 1
        end

        -- Check party/raid members' targets
        local prefix, maxMembers
        if IsInRaid() then
            prefix = "raid"
            maxMembers = GetNumGroupMembers()
        elseif IsInGroup() then
            prefix = "party"
            maxMembers = 4
        end

        if prefix then
            for i = 1, maxMembers do
                local groupUnit = prefix .. i
                if UnitExists(groupUnit) and not UnitIsUnit(groupUnit, "player") then
                    local groupTarget = groupUnit .. "target"
                    if UnitExists(groupTarget) and UnitIsUnit(groupTarget, unit) then
                        count = count + 1
                    end
                end
            end
        end

        return count
    end

    local function UpdateCount()
        local unit = container.unit
        if not unit or not UnitExists(unit) then
            text:SetText("")
            return
        end

        local count
        local unitIsFriendly = UnitIsFriend("player", unit)
        if unitIsFriendly then
            count = CountEnemiesTargeting(unit)
        else
            count = CountFriendliesTargeting(unit)
        end

        container.count = count
        if count > 0 then
            text:SetText(count)
            text:SetTextColor(ar, ag, ab, aa)
        else
            text:SetText("0")
            text:SetTextColor(ir, ig, ib, ia)
        end
    end

    ---------------------------------------------------------------------------
    -- Timer-based polling (matches WhosTargeted's proven approach)
    ---------------------------------------------------------------------------

    local function StartScan()
        if container.scanTimer then return end
        container.scanTimer = C_Timer.NewTicker(SCAN_INTERVAL, UpdateCount)
    end

    local function StopScan()
        if container.scanTimer then
            container.scanTimer:Cancel()
            container.scanTimer = nil
        end
        text:SetText("")
    end

    -- Start/stop scanning based on visibility
    container:SetScript("OnShow", function()
        StartScan()
    end)

    container:SetScript("OnHide", function()
        StopScan()
    end)

    -- Hook into UpdateAllElements so unit stays current
    hooksecurefunc(frame, "UpdateAllElements", function()
        container.unit = frame.unit
    end)

    -- Initial state
    container.unit = frame.unit

    -- Start scanning immediately
    StartScan()

    -- Store on the parent frame so other modules can reference it
    frame.TargetedBy = container
end
