--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

-- Various utility functions

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local band = _G.bit.band
local floor = _G.floor
local GameTooltip = _G.GameTooltip
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local geterrorhandler = _G.geterrorhandler
local GetItemFamily = _G.GetItemFamily
local GetItemInfo = _G.GetItemInfo
local ITEM_QUALITY_POOR = _G.LE_ITEM_QUALITY_POOR
local ITEM_QUALITY_UNCOMMON = _G.LE_ITEM_QUALITY_UNCOMMON
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local setmetatable = _G.setmetatable
local strjoin = _G.strjoin
local strmatch = _G.strmatch
local strsplit = _G.strsplit
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
--GLOBALS>

local FAMILY_TAGS = addon.FAMILY_TAGS
local FAMILY_ICONS = addon.FAMILY_ICONS

--------------------------------------------------------------------------------
-- (bag,slot) <=> slotId conversion
--------------------------------------------------------------------------------

function addon.GetSlotId(bag, slot)
	if bag and slot then
		return bag * 100 + slot
	end
end

function addon.GetBagSlotFromId(slotId)
	if slotId then
		return floor(slotId / 100), slotId % 100
	end
end

--------------------------------------------------------------------------------
-- Safe call
--------------------------------------------------------------------------------

local function safecall_return(success, ...)
	if success then
		return ...
	else
		geterrorhandler()((...))
	end
end

function addon.safecall(funcOrSelf, argOrMethod, ...)
	local func, arg
	if type(funcOrSelf) == "table" and type(argOrMethod) == "string" then
		func, arg = funcOrSelf[argOrMethod], funcOrSelf
	else
		func, arg = funcOrSelf, argOrMethod
	end
	if type(func) == "function" then
		return safecall_return(pcall(func, arg, ...))
	end
end

--------------------------------------------------------------------------------
-- Attaching tooltip to widgets
--------------------------------------------------------------------------------

local function WidgetTooltip_OnEnter(self)
	GameTooltip:SetOwner(self, self.tooltipAnchor, self.tootlipAnchorXOffset, self.tootlipAnchorYOffset)
	self:UpdateTooltip()
end

local function WidgetTooltip_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local function WidgetTooltip_Update(self)
	GameTooltip:ClearLines()
	addon.safecall(self, "tooltipCallback", GameTooltip)
	GameTooltip:Show()
end

function addon.SetupTooltip(widget, content, anchor, xOffset, yOffset)
	if type(content) == "string" then
		widget.tooltipCallback = function(self, tooltip)
			tooltip:AddLine(content)
		end
	elseif type(content) == "table" then
		widget.tooltipCallback = function(self, tooltip)
			tooltip:AddLine(tostring(content[1]), 1, 1, 1)
			for i = 2, #content do
				tooltip:AddLine(tostring(content[i]))
			end
		end
	elseif type(content) == "function" then
		widget.tooltipCallback = content
	else
		return
	end
	widget.tooltipAnchor = anchor or "ANCHOR_TOPLEFT"
	widget.tootlipAnchorXOffset = xOffset or 0
	widget.tootlipAnchorYOffset = yOffset or 0
	widget.UpdateTooltip = WidgetTooltip_Update
	if widget:GetScript('OnEnter') then
		widget:HookScript('OnEnter', WidgetTooltip_OnEnter)
	else
		widget:SetScript('OnEnter', WidgetTooltip_OnEnter)
	end
	if widget:GetScript('OnLeave') then
		widget:HookScript('OnLeave', WidgetTooltip_OnLeave)
	else
		widget:SetScript('OnLeave', WidgetTooltip_OnLeave)
	end
end

--------------------------------------------------------------------------------
-- Item link checking
--------------------------------------------------------------------------------

function addon.IsValidItemLink(link)
	if type(link) == "string" and (strmatch(link, "battlepet:") or (strmatch(link, 'item:[-:%d]+') and not strmatch(link, 'item:%d+:0:0:0:0:0:0:0:0:0'))) then
		return true
	end
end

--------------------------------------------------------------------------------
-- Basic junk test
--------------------------------------------------------------------------------

local JUNK = addon.BI['Junk']
function addon:IsJunk(itemId)
	local _, _, quality, _, _, class, subclass = GetItemInfo(itemId)
	return quality == ITEM_QUALITY_POOR or (quality and quality < ITEM_QUALITY_UNCOMMON and (class == JUNK or subclass == JUNK))
end

--------------------------------------------------------------------------------
-- Convert (name, category) pair to section key and conversely
--------------------------------------------------------------------------------

local function BuildSectionKey(name, category)
	if name ~= nil then
		return strjoin('#', tostring(category or name), tostring(name))
	end
end
addon.BuildSectionKey = BuildSectionKey

local function SplitSectionKey(key)
	if key ~= nil then
		local category, name = strsplit('#', tostring(key))
		return name or category, category
	end
end
addon.SplitSectionKey = SplitSectionKey

function addon.CompareSectionKeys(a, b)
	if a and b then
		local nameA, catA = SplitSectionKey(a)
		local nameB, catB = SplitSectionKey(b)
		local orderA = addon:GetCategoryOrder(catA)
		local orderB = addon:GetCategoryOrder(catB)
		if orderA == orderB then
			if catA == catB then
				return nameA < nameB
			else
				return catA < catB
			end
		else
			return orderA > orderB
		end
	end
end

--------------------------------------------------------------------------------
-- Item and container family
--------------------------------------------------------------------------------

function addon.GetItemFamily(item)
	if (type(item) == "string" and strmatch(item, "battlepet:")) or select(9, GetItemInfo(item)) == "INVTYPE_BAG" then
		return 0
	else
		return GetItemFamily(item)
	end
end

function addon:GetFamilyTag(family)
	if family and family ~= 0 then
		for mask, tag in pairs(FAMILY_TAGS) do
			if band(family, mask) ~= 0 then
				return tag, FAMILY_ICONS[mask]
			end
		end
	end
end
