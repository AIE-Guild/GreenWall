--[[ -----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2019 Mark Rogaski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]] -----------------------------------------------------------------------


--[[ -----------------------------------------------------------------------

UI Handlers

--]] -----------------------------------------------------------------------

function GreenWallInterfaceFrame_LoadOptions(self, mode)
    gw.Debug(GW_LOG_INFO, 'Loading interface settings (mode=%s)', tostring(mode))

    -- Populate interface panel.
    if not mode then
        mode = gw.settings:mode()
    end
    getglobal(self:GetName() .. "OptionMode"):SetChecked(mode == GW_MODE_ACCOUNT)
    getglobal(self:GetName() .. "OptionTag"):SetChecked(gw.settings:get('tag', mode))
    getglobal(self:GetName() .. "OptionAchievements"):SetChecked(gw.settings:get('achievements', mode))
    getglobal(self:GetName() .. "OptionRoster"):SetChecked(gw.settings:get('roster', mode))
    getglobal(self:GetName() .. "OptionRank"):SetChecked(gw.settings:get('rank', mode))
    getglobal(self:GetName() .. "OptionJoinDelay"):SetValue(gw.settings:get('joindelay', mode))
    if (gw.IsOfficer()) then
        getglobal(self:GetName() .. "OptionOfficerChat"):SetChecked(gw.settings:get('ochat', mode))
        getglobal(self:GetName() .. "OptionOfficerChatText"):SetTextColor(unpack(GW_UI_COLOR_ACTIVE))
        getglobal(self:GetName() .. "OptionOfficerChat"):Enable()
    else
        getglobal(self:GetName() .. "OptionOfficerChat"):SetChecked(false)
        getglobal(self:GetName() .. "OptionOfficerChatText"):SetTextColor(unpack(GW_UI_COLOR_INACTIVE))
        getglobal(self:GetName() .. "OptionOfficerChat"):Disable()
    end
end

function GreenWallInterfaceFrame_OnShow(self)
    if (not gw.addon_loaded) then
        -- Configuration not loaded.
        self:Hide()
        return
    end
    gw.Debug(GW_LOG_INFO, 'Displaying interface options')

    -- Initialize widgets
    getglobal(self:GetName() .. "OptionJoinDelay"):SetMinMaxValues(gw.settings:getattr('joindelay', 'min'),
        gw.settings:getattr('joindelay', 'max'))
    getglobal(self:GetName() .. "OptionJoinDelay"):SetValueStep(gw.settings:getattr('joindelay', 'step'))

    -- Display configured values
    GreenWallInterfaceFrame_LoadOptions(self)
end

function GreenWallInterfaceFrame_SaveUpdates(self)
    gw.Debug(GW_LOG_INFO, 'Saving interface settings')
    local mode = getglobal(self:GetName() .. "OptionMode"):GetChecked() and GW_MODE_ACCOUNT or GW_MODE_CHARACTER
    gw.settings:set('mode', mode)
    gw.settings:set('tag', getglobal(self:GetName() .. "OptionTag"):GetChecked() and true or false, mode)
    gw.settings:set('achievements',
        getglobal(self:GetName() .. "OptionAchievements"):GetChecked() and true or false, mode)
    gw.settings:set('roster', getglobal(self:GetName() .. "OptionRoster"):GetChecked() and true or false, mode)
    gw.settings:set('rank', getglobal(self:GetName() .. "OptionRank"):GetChecked() and true or false, mode)
    gw.settings:set('joindelay', getglobal(self:GetName() .. "OptionJoinDelay"):GetValue(), mode)
    if (gw.IsOfficer()) then
        gw.settings:set('ochat', getglobal(self:GetName() .. "OptionOfficerChat"):GetChecked() and true or false, mode)
    end
end

function GreenWallInterfaceFrame_SetDefaults(self)
    gw.Debug(GW_LOG_INFO, 'Resetting interface settings')
    gw.settings:reset()
end

function GreenWallInterfaceFrameOptionMode_OnClick(self)
    local mode = self:GetChecked() and GW_MODE_ACCOUNT or GW_MODE_CHARACTER
    gw.Debug(GW_LOG_DEBUG, 'Mode toggled: %s', mode)
    GreenWallInterfaceFrame_LoadOptions(self:GetParent(), mode)
end

function GreenWallInterfaceFrameOptionJoinDelay_OnValueChanged(self, value)
    -- Fix for 5.4.0, see http://www.wowwiki.com/Patch_5.4.0/API_changes
    gw.Debug(GW_LOG_DEBUG, 'Join delay setting updated')
    if not self._onsetting then
        self._onsetting = true
        self:SetValue(self:GetValue())
        value = self:GetValue()
        self._onsetting = false
    else return
    end
    getglobal(self:GetName() .. "Text"):SetText(value)
end
