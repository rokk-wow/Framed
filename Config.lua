local addonName = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

addon.config = {
    global = {
        font = "DorisPP",
        largeFont = 24,
        normalFont = 18,
        smallFont = 14,
        extraSmallFont = 11,
        borderWidth = 2,

        backgroundColor = "00000088",
        borderColor = "000000FF",

        manaColor = "2482ff",
        rageColor = "ff0000",
        focusColor = "ff8000",
        energyColor = "ffff00",
        runicPowerColor = "00d4ff",
        lunarPowerColor = "4d85e6",
        comboPointColor = "ffaa00",
        runesColor = "00d4ff",
        
        healthTexture = "smooth",
        powerTexture = "otravi",
        absorbTexture = "Diagonal",
        castBarTexture = "smooth",

        roleIcons = {
            TANK = "RaidFrame-Icon-MainTank",
            HEALER = "icons_64x64_heal",
            DAMAGER = "RaidFrame-Icon-MainAssist",
        },

        specAbbrevById = {
            -- Warrior
            [71] = "ARMS",
            [72] = "FURY",
            [73] = "PROT",
            -- Paladin
            [65] = "HOLY",
            [66] = "PROT",
            [70] = "RET",
            -- Hunter
            [253] = "BM",
            [254] = "MM",
            [255] = "SV",
            -- Rogue
            [259] = "ASSA",
            [260] = "OUTL",
            [261] = "SUB",
            -- Priest
            [256] = "DISC",
            [257] = "HOLY",
            [258] = "SPRIEST",
            -- Death Knight
            [250] = "BDK",
            [251] = "FDK",
            [252] = "UDK",
            -- Shaman
            [262] = "ELE",
            [263] = "ENH",
            [264] = "RESTO",
            -- Mage
            [62] = "ARC",
            [63] = "FIRE",
            [64] = "FROST",
            -- Warlock
            [265] = "AFF",
            [266] = "DEMO",
            [267] = "DESTRO",
            -- Monk
            [268] = "BREW",
            [269] = "WW",
            [270] = "MW",
            -- Druid
            [102] = "BAL",
            [103] = "FERAL",
            [104] = "GUARD",
            [105] = "RESTO",
            -- Demon Hunter
            [577] = "HAVOC",
            [581] = "VENG",
            -- Evoker
            [1467] = "DEV",
            [1468] = "PRES",
            [1473] = "AUG",
        },
    },
    player = {
        enabled = false,
        hideBlizzard = false,
        frameName = "frmdPlayerFrame",
        anchor = "TOPRIGHT",
        relativeTo = "MainActionBar",
        relativePoint = "TOPLEFT",
        offsetX = -10,
        offsetY = 0,
        width = 203,
        height = 41,

        modules = {
            health = {
                enabled = false,
                color = "class",
            },
            power = {
                enabled = false,
            },
            castbar = {
                enabled = false,
                anchor = "BOTTOM",
                relativeTo = "frmdPlayerFrame",
                relativePoint = "TOP",
                width = 203,
                height = 35,
                offsetX = 0,
                offsetY = 0,
            },            
            buffs = {
                enabled = false,
                anchor = "BOTTOM",
                relativeTo = "frmdPlayerFrame",
                relativePoint = "TOP",
                size = 26,
                spacingX = 3,
                spacingY = 3,
                max = 20,
            },
            debuffs = {
                enabled = false,
                anchor = "BOTTOM",
                relativeTo = "frmdPlayerFrame",
                relativePoint = "TOP",
                size = 30,
                spacingX = 4,
                spacingY = 4,
                max = 20,
            },
            absorbs = {
                enabled = false,
                opacity = .5,
                maxAbsorbOverflow = 1.0,
            },
            combatIndicator = {
                enabled = false,
                atlasTexture = "titleprestige-prestigeicon",
                anchor = "BOTTOM",
                relativeTo = "frmdPlayerFrame",
                relativePoint = "TOP",
                offsetX = 0,
                offsetY = 5,
            },
            restingIndicator = {
                enabled = false,
                atlasTexture = "plunderstorm-nameplates-icon-2",
                anchor = "BOTTOM",
                relativeTo = "frmdPlayerFrame",
                relativePoint = "TOP",
                offsetX = 0,
                offsetY = 5,
            },
        },
    },
    target = {
        enabled = false,
        hideBlizzard = false,
        frameName = "frmdTargetFrame",
        anchor = "TOPLEFT",
        relativeTo = "MainActionBar",
        relativePoint = "TOPRIGHT",
        offsetX = 10,
        offsetY = 0,
        width = 203,
        height = 41,
    },
    targetTarget = {
        enabled = false,
        frameName = "frmdTargetTargetFrame",
        anchor = "TOPLEFT",
        relativeTo = "MainActionBar",
        relativePoint = "TOPRIGHT",
        offsetX = 10,
        offsetY = 0,
        width = 93,
        height = 29,
    },
    focus = {
        enabled = false,
        hideBlizzard = false,
        frameName = "frmdFocusFrame",
        anchor = "TOPLEFT",
        relativeTo = "MainActionBar",
        relativePoint = "TOPRIGHT",
        offsetX = 10,
        offsetY = 0,
        width = 93,
        height = 29,
    },
    focusTarget = {
        enabled = false,
        hideBlizzard = false,
        frameName = "frmdFocusTargetFrame",
        anchor = "TOPLEFT",
        relativeTo = "FocusFrame",
        relativePoint = "TOPRIGHT",
        offsetX = 10,
        offsetY = 0,
        width = 93,
        height = 20,
    },
    pet = {
        enabled = false,
        hideBlizzard = false,
        frameName = "frmdPetFrame",
        anchor = "TOPLEFT",
        relativeTo = "PlayerFrame",
        relativePoint = "TOPRIGHT",
        offsetX = 10,
        offsetY = 0,
        width = 93,
        height = 29,
    },
    party = {
        enabled = false,
        hideBlizzard = false,
        frameContainerName = "frmdParty", -- Name of the container frame for party member frames, child frames will be named as frameContainerName..i (e.g. frmdParty1, frmdParty2, etc.)
        anchor = "TOPRIGHT",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        offsetX = -200,
        offsetY = -130,
        width = 100, -- Width of each party member frame
        height = 30, -- Height of each party member frame
        frameSpacing = 0, -- Spacing between party member frames
    },
    arena = {
        enabled = false,
        hideBlizzard = false,
        frameContainerName = "frmdArena", -- Name of the container frame for arena opponent frames, child frames will be named as frameContainerName..i (e.g. frmdArena1, frmdArena2, etc.)
        anchor = "TOPLEFT",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        offsetX = 200,
        offsetY = -130,
        width = 100, -- Width of each arena opponent frame
        height = 30, -- Height of each arena opponent frame
        frameSpacing = 0, -- Spacing between arena opponent frames
    },
}
