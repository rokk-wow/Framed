local addonName = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

function addon:SetupTargetTargetSettingsPanel()
    self:AddSettingsPanel("targetTarget", {
        title = "targetTargetTitle",
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
