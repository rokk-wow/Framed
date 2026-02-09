local addonName = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

function addon:SetupTargetSettingsPanel()
    self:AddSettingsPanel("target", {
        title = "targetTitle",
        controls = {
            {
                type = "checkbox",
                name = "enabled",
                default = false,
                onValueChange = function()
                    self.config = self:GetConfig()
                end
            }
        }
    })
end
