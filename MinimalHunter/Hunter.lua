local _, ns = ...

-- Base spell IDs; GetSpellInfo gives the localized names every rank shares.
local ASPECT_IDS = {
	13165, -- Hawk
	61846, -- Dragonhawk
	13163, -- Monkey
	5118, -- Cheetah
	13159, -- Pack
	20043, -- Wild
	13161, -- Beast
	34074, -- Viper
}
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local SIZE = 36

local aspectNames, cheetah, pack, viper = {}, nil, nil, nil

local function CreateIcon(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(SIZE, SIZE)
	b.border = ns.CreateBorder(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.text = ns.FontString(b, 11, "CENTER")
	b.text:SetPoint("BOTTOM", 0, 2)
	b:EnableMouse(true)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

-- Pulse a border between black and the given color.
local function Pulse(b, r, g, bl)
	b.pulse = r and { r, g, bl } or nil
	if not r then b.border:SetBackdropBorderColor(unpack(ns.colors.border)) end
end

local function PulseUpdate(b)
	if not b.pulse then return end
	local a = 0.55 + 0.45 * math.sin(GetTime() * 6)
	b.border:SetBackdropBorderColor(b.pulse[1], b.pulse[2], b.pulse[3], a)
end

ns.AddModule("Hunter", function()
	if ns.class ~= "HUNTER" then return end

	for _, id in ipairs(ASPECT_IDS) do
		local name = GetSpellInfo(id)
		if name then aspectNames[name] = true end
	end
	cheetah, pack, viper = GetSpellInfo(5118), GetSpellInfo(13159), GetSpellInfo(34074)

	local holder = CreateFrame("Frame", "MinimalHunterHunter", UIParent)
	holder:SetSize(SIZE * 2 + 4, SIZE)
	ns.RegisterMover(holder, "hunter", "Ammo / Aspect")

	-- Aspect watch -----------------------------------------------------------
	local aspect = CreateIcon(holder)
	aspect:SetPoint("RIGHT")
	aspect:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		if self.buffIndex then
			GameTooltip:SetUnitBuff("player", self.buffIndex)
		else
			GameTooltip:SetText("No aspect active")
		end
		GameTooltip:Show()
	end)

	local function KnowsAnyAspect()
		for name in pairs(aspectNames) do
			if GetSpellInfo(name) then return true end
		end
	end

	local function UpdateAspect()
		if not KnowsAnyAspect() then
			aspect:Hide()
			return
		end
		aspect:Show()
		aspect.buffIndex, aspect.name = nil, nil
		for i = 1, 40 do
			local name, _, icon = UnitBuff("player", i)
			if not name then break end
			if aspectNames[name] then
				aspect.buffIndex, aspect.name = i, name
				aspect.icon:SetTexture(icon)
				aspect.icon:SetDesaturated(false)
				break
			end
		end

		local inCombat = UnitAffectingCombat("player")
		if not aspect.name then
			aspect.icon:SetTexture(QUESTION)
			aspect.icon:SetDesaturated(true)
			if inCombat then Pulse(aspect, unpack(ns.colors.warn)) else Pulse(aspect) end
		elseif inCombat and (aspect.name == cheetah or aspect.name == pack) then
			-- Getting hit dazes you in Cheetah/Pack.
			Pulse(aspect, unpack(ns.colors.warn))
		elseif aspect.name == viper and UnitPowerMax("player", 0) > 0
			and UnitPower("player", 0) / UnitPowerMax("player", 0) >= 0.9 then
			-- Mana is full again: time to swap back to a damage aspect.
			Pulse(aspect, unpack(ns.colors.caution))
		else
			Pulse(aspect)
		end
	end

	-- Ammo count -------------------------------------------------------------
	local ammo = CreateIcon(holder)
	ammo:SetPoint("LEFT")
	ammo:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		if GetInventoryItemTexture("player", 0) then
			GameTooltip:SetInventoryItem("player", 0)
		else
			GameTooltip:SetText("No ammo equipped")
		end
		GameTooltip:Show()
	end)

	local function UpdateAmmo()
		local ranged = GetInventoryItemLink("player", 18)
		local equipLoc = ranged and select(9, GetItemInfo(ranged))
		if not ranged or equipLoc == "INVTYPE_THROWN" then
			-- No bow/gun/crossbow, or a thrown weapon: nothing to track.
			ammo:Hide()
			return
		end
		ammo:Show()
		local texture = GetInventoryItemTexture("player", 0)
		local count = texture and GetInventoryItemCount("player", 0) or 0
		ammo.icon:SetTexture(texture or QUESTION)
		ammo.icon:SetDesaturated(not texture)
		ammo.text:SetText(count)
		if count < 100 then
			ammo.text:SetTextColor(unpack(ns.colors.warn))
			Pulse(ammo, unpack(ns.colors.warn))
		elseif count < 400 then
			ammo.text:SetTextColor(unpack(ns.colors.caution))
			Pulse(ammo)
		else
			ammo.text:SetTextColor(unpack(ns.colors.text))
			Pulse(ammo)
		end
	end

	-- Events -----------------------------------------------------------------
	local pendingAmmo = 0
	holder:RegisterEvent("PLAYER_ENTERING_WORLD")
	holder:RegisterEvent("UNIT_AURA")
	holder:RegisterEvent("PLAYER_REGEN_DISABLED")
	holder:RegisterEvent("PLAYER_REGEN_ENABLED")
	holder:RegisterEvent("UNIT_MANA")
	holder:RegisterEvent("SPELLS_CHANGED")
	holder:RegisterEvent("BAG_UPDATE")
	holder:RegisterEvent("UNIT_INVENTORY_CHANGED")
	holder:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	holder:SetScript("OnEvent", function(_, event, unit)
		if event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
			if event ~= "UNIT_INVENTORY_CHANGED" or unit == "player" then
				pendingAmmo = 0.2 -- BAG_UPDATE comes in bursts
			end
			return
		end
		if unit and unit ~= "player" then return end
		if event == "PLAYER_ENTERING_WORLD" then UpdateAmmo() end
		UpdateAspect()
	end)
	holder:SetScript("OnUpdate", function(_, elapsed)
		if pendingAmmo > 0 then
			pendingAmmo = pendingAmmo - elapsed
			if pendingAmmo <= 0 then UpdateAmmo() end
		end
		PulseUpdate(aspect)
		PulseUpdate(ammo)
	end)

	UpdateAspect()
	UpdateAmmo()
end)
