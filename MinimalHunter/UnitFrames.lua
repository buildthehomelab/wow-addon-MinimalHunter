local _, ns = ...

ns.frames = {}

local POWER_EVENTS = {
	"UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER",
	"UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER",
	"UNIT_DISPLAYPOWER",
}

local CLASSIFICATION = { elite = "+", rareelite = "R+", rare = "R", worldboss = "B" }

local DROPDOWNS = {
	player = "PlayerFrameDropDown",
	target = "TargetFrameDropDown",
	pet = "PetFrameDropDown",
	focus = "FocusFrameDropDown",
}

local HAPPINESS = {
	[1] = { 0.9, 0.25, 0.2 },
	[2] = { 0.95, 0.75, 0.2 },
	[3] = { 0.45, 0.85, 0.35 },
}

local function HealthColor(unit)
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		return 0.4, 0.4, 0.4
	end
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local c = class and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		return 0.55, 0.55, 0.55
	end
	if unit == "pet" then
		local a = ns.colors.accent
		return a[1], a[2], a[3]
	end
	local reaction = UnitReaction(unit, "player")
	local c = reaction and FACTION_BAR_COLORS[reaction]
	if c then return c.r, c.g, c.b end
	return 0.5, 0.5, 0.5
end

------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------

local function UpdateHealth(f)
	local u = f.unit
	if not UnitExists(u) then return end
	local cur, max = UnitHealth(u), UnitHealthMax(u)
	f.health:SetMinMaxValues(0, max > 0 and max or 1)
	f.health:SetValue(cur)
	f.health:SetStatusBarColor(HealthColor(u))

	if not f.healthText then return end
	if not UnitIsConnected(u) then
		f.healthText:SetText("Offline")
	elseif UnitIsGhost(u) then
		f.healthText:SetText("Ghost")
	elseif UnitIsDead(u) then
		f.healthText:SetText("Dead")
	elseif f.percent and max > 0 and cur < max then
		f.healthText:SetFormattedText("%s  |cffaaaaaa%d%%|r", ns.Short(cur), cur / max * 100 + 0.5)
	else
		f.healthText:SetText(ns.Short(cur))
	end
end

local function UpdatePower(f)
	if not f.power then return end
	local u = f.unit
	if not UnitExists(u) then return end
	local cur, max = UnitPower(u), UnitPowerMax(u)
	local ptype, token = UnitPowerType(u)
	local c = PowerBarColor[token] or PowerBarColor[ptype] or PowerBarColor.MANA
	f.power:SetStatusBarColor(c.r, c.g, c.b)
	f.power:SetMinMaxValues(0, max > 0 and max or 1)
	f.power:SetValue(cur)
	if f.powerText then
		if max > 0 and ptype == 0 then
			f.powerText:SetFormattedText("%d%%", cur / max * 100 + 0.5)
		elseif max > 0 then
			f.powerText:SetText(cur)
		else
			f.powerText:SetText("")
		end
	end
end

local function UpdateName(f)
	local u = f.unit
	if not UnitExists(u) then return end
	local name = UnitName(u) or ""
	if f.showLevel then
		local level = UnitLevel(u)
		local c = (GetQuestDifficultyColor or GetDifficultyColor)(level > 0 and level or 99)
		local cls = CLASSIFICATION[UnitClassification(u)] or ""
		f.nameText:SetFormattedText("|cff%02x%02x%02x%s%s|r %s",
			c.r * 255, c.g * 255, c.b * 255, level > 0 and level or "??", cls, name)
	else
		f.nameText:SetText(name)
	end
end

local function UpdateRaidIcon(f)
	if not f.raidIcon then return end
	local index = UnitExists(f.unit) and GetRaidTargetIndex(f.unit)
	if index then
		SetRaidTargetIconTexture(f.raidIcon, index)
		f.raidIcon:Show()
	else
		f.raidIcon:Hide()
	end
end

local function UpdateHappiness(f)
	if not f.happiness then return end
	local happiness = GetPetHappiness()
	local c = happiness and HAPPINESS[happiness]
	if c then
		f.happiness:SetVertexColor(c[1], c[2], c[3])
		f.happiness:Show()
		f.happiness.border:Show()
	else
		f.happiness:Hide()
		f.happiness.border:Hide()
	end
end

------------------------------------------------------------------------
-- Auras (target: your debuffs + buffs Tranquilizing Shot can remove)
------------------------------------------------------------------------

local function CreateAuraIcon(parent, size)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(size, size)
	b.border = ns.CreateBorder(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.cd = CreateFrame("Cooldown", nil, b)
	b.cd:SetAllPoints()
	b.cd:SetReverse(true)
	b.count = ns.FontString(b, 10, "RIGHT")
	b.count:SetPoint("BOTTOMRIGHT", 1, 0)
	b:EnableMouse(true)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetUnitAura(self.unit, self.index, self.filter)
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	b:Hide()
	return b
end

local function SetAura(b, unit, index, filter, icon, count, duration, expires)
	b.unit, b.index, b.filter = unit, index, filter
	b.icon:SetTexture(icon)
	b.count:SetText(count and count > 1 and count or "")
	if duration and duration > 0 then
		b.cd:SetCooldown(expires - duration, duration)
		b.cd:Show()
	else
		b.cd:Hide()
	end
	b:Show()
end

local function UpdateAuras(f)
	if not f.debuffs then return end
	local u = f.unit
	local n = 0
	if UnitExists(u) then
		for i = 1, 40 do
			local name, _, icon, count, _, duration, expires = UnitAura(u, i, "HARMFUL|PLAYER")
			if not name then break end
			n = n + 1
			if n > #f.debuffs then break end
			SetAura(f.debuffs[n], u, i, "HARMFUL|PLAYER", icon, count, duration, expires)
		end
	end
	for i = n + 1, #f.debuffs do f.debuffs[i]:Hide() end

	n = 0
	if UnitExists(u) and UnitCanAttack("player", u) then
		for i = 1, 40 do
			local name, _, icon, count, dtype, duration, expires = UnitAura(u, i, "HELPFUL")
			if not name then break end
			if dtype == "Magic" or dtype == "" then
				n = n + 1
				if n > #f.buffs then break end
				SetAura(f.buffs[n], u, i, "HELPFUL", icon, count, duration, expires)
			end
		end
	end
	for i = n + 1, #f.buffs do f.buffs[i]:Hide() end
end

------------------------------------------------------------------------
-- Frame factory
------------------------------------------------------------------------

local function FullUpdate(f)
	if not UnitExists(f.unit) then return end
	UpdateHealth(f)
	UpdatePower(f)
	UpdateName(f)
	UpdateRaidIcon(f)
	UpdateHappiness(f)
	UpdateAuras(f)
end
ns.UpdateUnitFrame = FullUpdate

local function OnEvent(f, event, unit)
	if unit and unit ~= f.unit then return end
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
		UpdateHealth(f)
	elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
		UpdateName(f)
	elseif event == "UNIT_AURA" then
		UpdateAuras(f)
	elseif event == "UNIT_HAPPINESS" then
		UpdateHappiness(f)
		UpdatePower(f)
	elseif event == "RAID_TARGET_UPDATE" then
		UpdateRaidIcon(f)
	elseif event == "PLAYER_REGEN_DISABLED" then
		f.mhBorder:SetBackdropBorderColor(0.6, 0.15, 0.12, 1)
	elseif event == "PLAYER_REGEN_ENABLED" then
		f.mhBorder:SetBackdropBorderColor(unpack(ns.colors.border))
	elseif event:find("^UNIT_") then
		UpdatePower(f)
	else
		FullUpdate(f)
	end
end

local function CreateUnitFrame(unit, key, label, w, opts)
	local healthH = opts.healthH or 22
	local powerH = opts.powerH or 0
	local h = healthH + (powerH > 0 and powerH + 1 or 0)

	local f = CreateFrame("Button", "MinimalHunter_" .. key, UIParent, "SecureUnitButtonTemplate")
	f.unit = unit
	f:SetSize(w, h)
	f:SetAttribute("unit", unit)
	f:SetAttribute("*type1", "target")
	f:RegisterForClicks("AnyUp")
	if DROPDOWNS[unit] then
		f:SetAttribute("*type2", "menu")
		f.menu = function()
			ToggleDropDownMenu(1, nil, _G[DROPDOWNS[unit]], "cursor")
		end
	end
	f:SetScript("OnEnter", UnitFrame_OnEnter)
	f:SetScript("OnLeave", UnitFrame_OnLeave)
	ns.CreateBorder(f)

	f.health = ns.StatusBar(f)
	f.health:SetPoint("TOPLEFT")
	f.health:SetPoint("TOPRIGHT")
	f.health:SetHeight(healthH)

	if powerH > 0 then
		f.power = ns.StatusBar(f)
		f.power:SetPoint("BOTTOMLEFT")
		f.power:SetPoint("BOTTOMRIGHT")
		f.power:SetHeight(powerH)
		local sep = f:CreateTexture(nil, "OVERLAY")
		sep:SetTexture(0, 0, 0, 1)
		sep:SetPoint("BOTTOMLEFT", f.power, "TOPLEFT")
		sep:SetPoint("BOTTOMRIGHT", f.power, "TOPRIGHT")
		sep:SetHeight(1)
		if opts.powerText then
			f.powerText = ns.FontString(f.power, 9, "RIGHT")
			f.powerText:SetPoint("RIGHT", -3, 0)
		end
	end

	local textFrame = CreateFrame("Frame", nil, f)
	textFrame:SetAllPoints(f.health)
	textFrame:SetFrameLevel(f.health:GetFrameLevel() + 2)

	f.nameText = ns.FontString(textFrame, opts.fontSize or 12, "LEFT")
	f.nameText:SetPoint("LEFT", 4, 0)
	f.showLevel = opts.showLevel
	f.percent = opts.percent

	if opts.healthText ~= false then
		f.healthText = ns.FontString(textFrame, opts.fontSize or 12, "RIGHT")
		f.healthText:SetPoint("RIGHT", -4, 0)
		f.nameText:SetPoint("RIGHT", f.healthText, "LEFT", -4, 0)
	else
		f.nameText:SetPoint("RIGHT", -4, 0)
	end

	if opts.raidIcon then
		f.raidIcon = textFrame:CreateTexture(nil, "OVERLAY")
		f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		f.raidIcon:SetSize(16, 16)
		f.raidIcon:SetPoint("CENTER", f, "TOP", 0, 0)
		f.raidIcon:Hide()
		f:RegisterEvent("RAID_TARGET_UPDATE")
	end

	for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_FLAGS", "PLAYER_ENTERING_WORLD" }) do
		f:RegisterEvent(e)
	end
	if f.power then
		for _, e in ipairs(POWER_EVENTS) do f:RegisterEvent(e) end
	end
	f:SetScript("OnEvent", OnEvent)
	f:HookScript("OnShow", FullUpdate)

	if unit ~= "player" then
		RegisterUnitWatch(f)
	end

	ns.RegisterMover(f, key, label)
	ns.frames[key] = f
	return f
end

local function DisableBlizzard()
	for _, name in ipairs({ "PlayerFrame", "TargetFrame", "ComboFrame", "FocusFrame", "PetFrame", "TargetFrameSpellBar", "FocusFrameSpellBar" }) do
		ns.Kill(_G[name])
	end
	-- Blizzard's player castbar is replaced in CastBars.lua.
end

ns.AddModule("UnitFrames", function()
	DisableBlizzard()

	local player = CreateUnitFrame("player", "player", "Player", 220, { healthH = 26, powerH = 9, powerText = true })
	player:RegisterEvent("PLAYER_REGEN_DISABLED")
	player:RegisterEvent("PLAYER_REGEN_ENABLED")

	local target = CreateUnitFrame("target", "target", "Target", 220, {
		healthH = 26, powerH = 5, showLevel = true, percent = true, raidIcon = true,
	})
	target:RegisterEvent("PLAYER_TARGET_CHANGED")
	target:RegisterEvent("UNIT_AURA")
	target:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
	target.debuffs, target.buffs = {}, {}
	for i = 1, 8 do
		local b = CreateAuraIcon(target, 24)
		b:SetPoint("BOTTOMLEFT", target, "TOPLEFT", (i - 1) * 28, 6)
		target.debuffs[i] = b
	end
	for i = 1, 3 do
		local b = CreateAuraIcon(target, 20)
		b:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", -(i - 1) * 24, 36)
		b.border:SetBackdropBorderColor(0.3, 0.6, 1, 1)
		target.buffs[i] = b
	end

	local tot = CreateUnitFrame("targettarget", "targettarget", "ToT", 110, { healthH = 20, healthText = false, fontSize = 11 })
	local elapsed = 0
	tot:SetScript("OnUpdate", function(self, e)
		elapsed = elapsed + e
		if elapsed < 0.25 then return end
		elapsed = 0
		FullUpdate(self)
	end)

	local focus = CreateUnitFrame("focus", "focus", "Focus", 140, { healthH = 18, powerH = 3, fontSize = 11 })
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED")

	local pet = CreateUnitFrame("pet", "pet_frame", "Pet", 130, { healthH = 18, powerH = 5, fontSize = 11 })
	pet:RegisterEvent("UNIT_PET")
	pet:RegisterEvent("UNIT_HAPPINESS")
	pet:SetScript("OnEvent", function(self, event, unit)
		if event == "UNIT_PET" then
			if unit == "player" then FullUpdate(self) end
			return
		end
		OnEvent(self, event, unit)
	end)
	if ns.class == "HUNTER" then
		-- Happiness pip: red unhappy, yellow content, green happy.
		local pip = pet:CreateTexture(nil, "OVERLAY")
		pip:SetTexture(ns.media.blank)
		pip:SetSize(6, 6)
		pip:SetPoint("TOPRIGHT", pet, "TOPLEFT", -4, 0)
		local pipBorder = pet:CreateTexture(nil, "ARTWORK")
		pipBorder:SetTexture(0, 0, 0, 1)
		pipBorder:SetPoint("TOPLEFT", pip, -1, 1)
		pipBorder:SetPoint("BOTTOMRIGHT", pip, 1, -1)
		pip.border = pipBorder
		pet.happiness = pip
	end

	for _, f in pairs(ns.frames) do FullUpdate(f) end
end)
