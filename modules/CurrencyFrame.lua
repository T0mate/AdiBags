--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local BreakUpLargeNumbers = _G.BreakUpLargeNumbers
local CreateFont = _G.CreateFont
local CreateFrame = _G.CreateFrame
local ExpandCurrencyList = _G.ExpandCurrencyList
local format = _G.format
local GetCurrencyListInfo = _G.GetCurrencyListInfo
local GetCurrencyListSize = _G.GetCurrencyListSize
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local IsAddOnLoaded = _G.IsAddOnLoaded
local tconcat = _G.table.concat
local tinsert = _G.tinsert
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local UpdateTable = addon.UpdateTable

local mod = addon:NewModule('CurrencyFrame', 'AceEvent-3.0')
mod.uiName = L['Currency']
mod.uiDesc = L['Display character currency at bottom left of the backpack.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(
		self.moduleName,
		{
			profile = {
				shown = { ['*'] = true },
				hideZeroes = true,
				text = addon:GetFontDefaults(NumberFontNormalLarge)
			}
		}
	)
	self.font = addon:CreateFont(
		self.name..'Font',
		NumberFontNormalLarge,
		function() return self.db.profile.text end
	)
	self.font.SettingHook = function() return self:Update() end
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.widget then
		self.widget:Show()
	end
	self:RegisterEvent('KNOWN_CURRENCY_TYPES_UPDATE', "Update")
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', "Update")
	self:RegisterEvent('HONOR_CURRENCY_UPDATE', "Update")
	if not self.hooked then
		if IsAddOnLoaded('Blizzard_TokenUI') then
			self:ADDON_LOADED('OnEnable', 'Blizzard_TokenUI')
		else
			self:RegisterEvent('ADDON_LOADED')
		end
	end
	self.font:ApplySettings()
	self:Update()
end

function mod:ADDON_LOADED(_, name)
	if name ~= 'Blizzard_TokenUI' then return end
	self:UnregisterEvent('ADDON_LOADED')
	hooksecurefunc('TokenFrame_Update', function() self:Update() end)
	self.hooked = true
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()

	local widget =CreateFrame("Button", addonName.."CurrencyFrame", frame)
	self.widget = widget
	widget:SetHeight(16)
	widget:RegisterForClicks("RightButtonUp")
	widget:SetScript('OnClick', function() self:OpenOptions() end)
	addon.SetupTooltip(widget, { L['Currency'], L['Right-click to configure.'] }, "ANCHOR_BOTTOMLEFT")

	local fs = widget:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(self.font)
	fs:SetPoint("BOTTOMLEFT", 0, 1)
	self.fontstring = fs

	self:Update()
	frame:AddBottomWidget(widget, "LEFT", 50)
end

local IterateCurrencies
do
	local function iterator(collapse, index)
		if not index then return end
		repeat
			index = index + 1
			local name, isHeader, isExpanded, isUnused, isWatched, count, icon = GetCurrencyListInfo(index)
			if name then
				if isHeader then
					if not isExpanded then
						tinsert(collapse, 1, index)
						ExpandCurrencyList(index, 1)
					end
				else
					return index, name, isHeader, isExpanded, isUnused, isWatched, count, icon
				end
			end
		until index > GetCurrencyListSize()
		for i, index in ipairs(collapse) do
			ExpandCurrencyList(index, 0)
		end
	end

	local collapse = {}
	function IterateCurrencies()
		wipe(collapse)
		return iterator, collapse, 0
	end
end

local ICON_STRING = "\124T%s:0:0:0:0:64:64:5:59:5:59\124t "

local values = {}
local updating
function mod:Update()
	if not self.widget or updating then return end
	updating = true

	local shown, hideZeroes = self.db.profile.shown, self.db.profile.hideZeroes
	for i, name, _, _, _, _, count, icon in IterateCurrencies() do
		if shown[name] and (count > 0 or not hideZeroes) then
			tinsert(values, BreakUpLargeNumbers(count))
			tinsert(values, format(ICON_STRING, icon))
		end
	end

	local widget, fs = self.widget, self.fontstring
	if #values > 0 then
		fs:SetText(tconcat(values, ""))
		widget:Show()
		widget:SetSize(
			fs:GetStringWidth() + 4 * #values,
			ceil(fs:GetStringHeight()) + 3
		)
		wipe(values)
	else
		widget:Hide()
	end

	updating = false
end

function mod:GetOptions()
	local values = {}
	return {
		shown = {
			name = L['Currencies to show'],
			type = 'multiselect',
			order = 10,
			values = function()
				wipe(values)
				for i, name, _, _, _, _, _, icon in IterateCurrencies() do
					values[name] = format(ICON_STRING, icon)..name
				end
				return values
			end,
			width = 'double',
		},
		hideZeroes = {
			name = L['Hide zeroes'],
			desc = L['Ignore currencies with null amounts.'],
			type = 'toggle',
			order = 20,
		},
		text = addon:CreateFontOptions(self.font, nil, 30)
	}, addon:GetOptionHandler(self, false, function() return self:Update() end)
end

