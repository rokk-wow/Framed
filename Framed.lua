local addonName, ns = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)
local oUF = ns.oUF

addon.sadCore.savedVarsGlobalName = "Framed_Settings_Global"
addon.sadCore.savedVarsPerCharName = "Framed_Settings_Char"
addon.sadCore.compartmentFuncName = "Framed_Compartment_Func"

function addon:Initialize()
    self.author = "Rôkk-Wyrmrest Accord"

end
