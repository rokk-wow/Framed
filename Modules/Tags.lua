local addonName, ns = ...
local oUF = ns.oUF
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

-- Safely retrieve unit name, returning nil instead of a secret value
local function SafeUnitName(unit)
    return addon:SecureCall(UnitName, unit)
end

--[[ Custom Tags for Framed
Registers custom oUF tag functions used by the Text module.

Tag naming convention:
  - name:XXX      name variants (short, medium, long, abbrev)
  - health:XXX    health display variants
  - power:XXX     power display variants

Built-in oUF tags are always available and do NOT need to be redefined:
  [name]                Full unit name
  [curhp]               Current HP (raw number)
  [maxhp]               Max HP (raw number)
  [perhp]               Health percent (integer, e.g. 85)
  [missinghp]           Missing HP (hidden when 0)
  [curpp]               Current power (raw number)
  [maxpp]               Max power (raw number)
  [perpp]               Power percent (integer)
  [level]               Unit level
  [smartlevel]          Level with elite/boss indicator
  [class]               Class name
  [smartclass]          Class for players, creature type for NPCs
  [dead]                "Dead" or "Ghost"
  [offline]             "Offline" if disconnected
  [status]              Dead / Ghost / Offline / zzz
  [resting]             "zzz" if player is resting
  [pvp]                 "PvP" if flagged
  [threat]              ++ / -- / Aggro
  [raidcolor]           Class color hex markup
  [powercolor]          Power type color hex markup
  [threatcolor]         Threat level color hex markup
  [classification]      Rare / Rare Elite / Elite / Boss / Affix
  [shortclassification] R / R+ / + / B / -
  [creature]            Creature family or type
  [group]               Raid group number
  [leader]              "L" if group leader
  [sex]                 Male / Female
  [faction]             Faction name
  [race]                Race name

Format string syntax:
  Tags are enclosed in square brackets and can be combined with literal text.
    "[name]"                                → Thrall
    "[perhp]%"                              → 85%
    "[curhp:short] / [maxhp:short]"         → 245K / 300K
    "[raidcolor][name:medium]|r"            → class-colored name

  Optional prefix/suffix (only shown if tag returns a value):
    "[==$>name<$==]"                        → ==Thrall==
    "[perhp<$%]"                            → 85%

  Tag arguments:
    "[name:trunc(12)]"                      → name truncated to 12 chars
--]]

---------------------------------------------------------------------------
-- Name tags
---------------------------------------------------------------------------

oUF.Tags.Methods['name:short'] = function(unit, realUnit)
    local name = SafeUnitName(realUnit or unit)
    if name then return name:sub(1, 10) end
end
oUF.Tags.Events['name:short'] = 'UNIT_NAME_UPDATE'

oUF.Tags.Methods['name:medium'] = function(unit, realUnit)
    local name = SafeUnitName(realUnit or unit)
    if name then return name:sub(1, 15) end
end
oUF.Tags.Events['name:medium'] = 'UNIT_NAME_UPDATE'

oUF.Tags.Methods['name:long'] = function(unit, realUnit)
    local name = SafeUnitName(realUnit or unit)
    if name then return name:sub(1, 20) end
end
oUF.Tags.Events['name:long'] = 'UNIT_NAME_UPDATE'

oUF.Tags.Methods['name:abbrev'] = function(unit, realUnit)
    local name = SafeUnitName(realUnit or unit)
    if name then
        return name:gsub('(%S+)', function(w) return w:sub(1, 1) end)
    end
end
oUF.Tags.Events['name:abbrev'] = 'UNIT_NAME_UPDATE'

-- Truncate name to arbitrary length via argument: [name:trunc(12)]
oUF.Tags.Methods['name:trunc'] = function(unit, realUnit, ...)
    local name = SafeUnitName(realUnit or unit)
    if not name then return end
    local len = tonumber(...)
    if len then
        return name:sub(1, len)
    end
    return name
end
oUF.Tags.Events['name:trunc'] = 'UNIT_NAME_UPDATE'

---------------------------------------------------------------------------
-- Health tags
---------------------------------------------------------------------------

oUF.Tags.Methods['curhp:short'] = function(unit)
    return AbbreviateNumbers(UnitHealth(unit))
end
oUF.Tags.Events['curhp:short'] = 'UNIT_HEALTH UNIT_MAXHEALTH'

oUF.Tags.Methods['maxhp:short'] = function(unit)
    return AbbreviateNumbers(UnitHealthMax(unit))
end
oUF.Tags.Events['maxhp:short'] = 'UNIT_MAXHEALTH'

oUF.Tags.Methods['hp:percent'] = function(unit)
    return string.format('%d%%', UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
end
oUF.Tags.Events['hp:percent'] = 'UNIT_HEALTH UNIT_MAXHEALTH'

oUF.Tags.Methods['hp:cur-percent'] = function(unit)
    local cur = AbbreviateNumbers(UnitHealth(unit))
    local pct = string.format('%d', UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    return cur .. ' - ' .. pct .. '%'
end
oUF.Tags.Events['hp:cur-percent'] = 'UNIT_HEALTH UNIT_MAXHEALTH'

oUF.Tags.Methods['hp:cur-max'] = function(unit)
    local cur = AbbreviateNumbers(UnitHealth(unit))
    local max = AbbreviateNumbers(UnitHealthMax(unit))
    return cur .. ' / ' .. max
end
oUF.Tags.Events['hp:cur-max'] = 'UNIT_HEALTH UNIT_MAXHEALTH'

oUF.Tags.Methods['hp:deficit'] = function(unit)
    local deficit = UnitHealthMissing(unit)
    if deficit and deficit > 0 then
        return '-' .. AbbreviateNumbers(deficit)
    end
end
oUF.Tags.Events['hp:deficit'] = 'UNIT_HEALTH UNIT_MAXHEALTH'

---------------------------------------------------------------------------
-- Power tags
---------------------------------------------------------------------------

oUF.Tags.Methods['curpp:short'] = function(unit)
    local cur = UnitPower(unit)
    if cur and cur > 0 then
        return AbbreviateNumbers(cur)
    end
end
oUF.Tags.Events['curpp:short'] = 'UNIT_POWER_UPDATE UNIT_MAXPOWER'

oUF.Tags.Methods['maxpp:short'] = function(unit)
    return AbbreviateNumbers(UnitPowerMax(unit))
end
oUF.Tags.Events['maxpp:short'] = 'UNIT_MAXPOWER'

oUF.Tags.Methods['pp:percent'] = function(unit)
    return string.format('%d%%', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))
end
oUF.Tags.Events['pp:percent'] = 'UNIT_POWER_UPDATE UNIT_MAXPOWER'

oUF.Tags.Methods['pp:cur-percent'] = function(unit)
    local cur = AbbreviateNumbers(UnitPower(unit))
    local pct = string.format('%d', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))
    return cur .. ' - ' .. pct .. '%'
end
oUF.Tags.Events['pp:cur-percent'] = 'UNIT_POWER_UPDATE UNIT_MAXPOWER'

oUF.Tags.Methods['pp:cur-max'] = function(unit)
    local cur = AbbreviateNumbers(UnitPower(unit))
    local max = AbbreviateNumbers(UnitPowerMax(unit))
    return cur .. ' / ' .. max
end
oUF.Tags.Events['pp:cur-max'] = 'UNIT_POWER_UPDATE UNIT_MAXPOWER'

---------------------------------------------------------------------------
-- Spec tags
---------------------------------------------------------------------------

-- Returns the spec abbreviation for the unit from global.specAbbrevById.
-- For the player: uses C_SpecializationInfo.GetSpecialization + GetSpecializationInfo.
-- For other units: uses GetInspectSpecialization (requires prior inspect or
-- group info cache — Blizzard caches party/raid specs automatically).
oUF.Tags.Methods['spec'] = function(unit)
    local specId

    if UnitIsUnit(unit, 'player') then
        local specIndex = C_SpecializationInfo.GetSpecialization()
        if specIndex then
            specId = C_SpecializationInfo.GetSpecializationInfo(specIndex)
        end
    else
        if GetInspectSpecialization then
            specId = GetInspectSpecialization(unit)
        end
    end

    if specId and specId > 0 then
        local abbrev = addon.config.global.specAbbrevById[specId]
        if abbrev then return abbrev end
    end
    return ''
end
oUF.Tags.Events['spec'] = 'GROUP_ROSTER_UPDATE PLAYER_SPECIALIZATION_CHANGED INSPECT_READY'


