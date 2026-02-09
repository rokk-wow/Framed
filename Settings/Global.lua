local addonName = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

function addon:SetupGlobalSettingsPanel()
    self:AddSettingsPanel("global", {
        title = "globalTitle",
        controls = {
            {
                type = "header",
                name = "globalHeader"
            }
        }
    })
end
