--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

local mod = addon:NewModule('TidyBags', 'AceEvent-3.0')

local containers = {}

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	self:RegisterMessage('AdiBags_PreContentUpdate')
	for container in pairs(containers) do
		container[self].button:Show()
		self:UpdateButton(container)
	end
end

function mod:OnDisable()
	for container in pairs(containers) do
		container[self]:Hide()
	end
end

local function TidyButton_OnClick(button)
	mod:Start(button.container)
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()

	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.container = container
	button:SetText("T")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", TidyButton_OnClick)	
	container:AddHeaderWidget(button, 0)
	
	container[self] = {
		button = button
	}
end

local bor = bit.bor
local band = bit.band
local GetItemFamily = GetItemFamily
local GetContainerFreeSlots = GetContainerFreeSlots

local freeSlots = {}
local function FindFreeSlot(container, family)
	for bag, slots in pairs(container.content) do
		if slots.size > 0 and slots.family ~= 0 and band(family, slots.family) ~= 0 then
			GetContainerFreeSlots(bag, freeSlots)
			local slot = freeSlots[1]
			wipe(freeSlots)
			if slot then
				return bag, slot
			end
		end
	end
end

local incompleteStacks = {}
local function FindNextMove(container)
	wipe(incompleteStacks)

	local availableFamilies = 0
	for bag, slots in pairs(container.content) do
		if slots.size > 0 and slots.family then
			availableFamilies = bor(availableFamilies, slots.family)
		end
	end

	for bag, slots in pairs(container.content) do
		if slots.size > 0 then
			local bagFamily = slots.family
			for slot, slotData in ipairs(slots) do
		
				if slotData and slotData.link then
					local itemFamily = GetItemFamily(slotData.itemId)
				
					if band(itemFamily, availableFamilies) ~= 0 and band(itemFamily, bagFamily) == 0 then
						-- Not in the right bag, look for a better one
						local toBag, toSlot = FindFreeSlot(container, itemFamily)
						mod:Debug('Item not in the right bag', slotData.link, bag, slot, '=>', toBag, toSlot)
						if toBag then
							return toBag, toSlot
						end
					
					elseif slotData.count < slotData.maxStack then
						-- Incomplete stack
				
						local existingStack = incompleteStacks[slotData.itemId]
						if existingStack then
							mod:Debug('Another incomplete stack', slotData.link, bag, slot, slotData.count, slotData.maxStack, '=>', existingStack.bag, existingStack.slot)
							-- Anoter incomplete stack exist for this item, try to merge both
							return bag, slot, existingStack.bag, existingStack.slot
						else
							mod:Debug('First incomplete stack', slotData.link, bag, slot, slotData.count, slotData.maxStack)
							-- First incomplete stack of this item
							incompleteStacks[slotData.itemId] = slotData
						end
					end
				
				end
			
			end
		end
	end
end

function mod:GetNextMove(container)
	local data = container[self]
	if not data.cached then
		data.cached, data[1], data[2], data[3], data[4] = true, FindNextMove(container)
	end
	return unpack(data, 1, 4)
end

local PickupItem = PickupContainerItem -- Might require something more sophisticated for bank

function mod:Process(container)
	if not GetCursorInfo() then
		local fromBag, fromSlot, toBag, toSlot = self:GetNextMove(container)
		if fromBag then
			PickupItem(fromBag, fromSlot)
			if GetCursorInfo() == "item" then
				PickupItem(toBag, toSlot)
				if not GetCursorInfo() then
					return
				end
			end
		end
	end
	container[self].running = nil
	self:UpdateButton(container)
end

function mod:UpdateButton(container)
	local data = container[self]
	if not data.running and self:GetNextMove(container) then
		data.button:Enable()
	else
		data.button:Disable()
	end
end

function mod:Start(container)
	container[self].running = true
	self:UpdateButton(container)
	self:Process(container)
end

function mod:AdiBags_PreContentUpdate(event, container)
	container[self].cached = nil
	if container[self].running then
		self:Process(container)
	else
		self:UpdateButton(container)
	end
end

