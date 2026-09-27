local _, ns = ...

local CAST_COLOR = { 0.67, 0.83, 0.45 }
local CHANNEL_COLOR = { 0.45, 0.7, 0.95 }
local LOCKED_COLOR = { 0.55, 0.55, 0.55 }

local function Finish(bar, failed)
	bar.casting, bar.channeling = nil, nil
	if failed then
		bar:SetStatusBarColor(unpack(ns.colors.warn))
		bar:SetValue(select(2, bar:GetMinMaxValues()))
		bar.text:SetText(failed)
		bar.time:SetText("")
		bar.holdUntil = GetTime() + 0.6
	else
		bar.holdUntil = GetTime() + 0.15
	end
end

local function Start(bar, channel)
	local u = bar.unit
	local name, _, text, texture, startMs, endMs, _, castID, notInterruptible
	if channel then
		name, _, text, texture, startMs, endMs, _, notInterruptible = UnitChannelInfo(u)
	else
		name, _, text, texture, startMs, endMs, _, castID, notInterruptible = UnitCastingInfo(u)
	end
	if not name then
		bar:Hide()
		return
	end
	bar.casting, bar.channeling = not channel, channel
	bar.castID = castID
	bar.startTime, bar.endTime = startMs / 1000, endMs / 1000
	bar.holdUntil = nil
	bar:SetMinMaxValues(0, bar.endTime - bar.startTime)
	bar.text:SetText(text ~= "" and text or name)
	bar.icon:SetTexture(texture)
	local c = notInterruptible and LOCKED_COLOR or (channel and CHANNEL_COLOR or CAST_COLOR)
	bar:SetStatusBarColor(c[1], c[2], c[3])

	if bar.safe then
		local _, _, latency = GetNetStats()
		local frac = math.min((latency / 1000) / (bar.endTime - bar.startTime), 1)
		bar.safe:ClearAllPoints()
		bar.safe:SetPoint(channel and "LEFT" or "RIGHT")
		bar.safe:SetPoint("TOP")
		bar.safe:SetPoint("BOTTOM")
		bar.safe:SetWidth(math.max(bar:GetWidth() * frac, 1))
	end
	bar:Show()
end

local function OnUpdate(bar)
	local now = GetTime()
	if bar.casting then
		if now >= bar.endTime then return Finish(bar) end
		bar:SetValue(now - bar.startTime)
		bar.time:SetFormattedText("%.1f", bar.endTime - now)
	elseif bar.channeling then
		if now >= bar.endTime then return Finish(bar) end
		bar:SetValue(bar.endTime - now)
		bar.time:SetFormattedText("%.1f", bar.endTime - now)
	elseif not bar.holdUntil or now >= bar.holdUntil then
		bar:Hide()
	end
end

local function OnEvent(bar, event, unit, _, _, castID)
	if event == "PLAYER_TARGET_CHANGED" then
		if UnitCastingInfo(bar.unit) then return Start(bar) end
		if UnitChannelInfo(bar.unit) then return Start(bar, true) end
		bar.casting, bar.channeling, bar.holdUntil = nil, nil, nil
		bar:Hide()
		return
	end
	if unit ~= bar.unit then return end

	if event == "UNIT_SPELLCAST_START" then
		Start(bar)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		Start(bar, true)
	elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		if bar.casting or bar.channeling then Start(bar, bar.channeling) end
	elseif event == "UNIT_SPELLCAST_STOP" then
		if bar.casting and (not castID or not bar.castID or castID == bar.castID) then Finish(bar) end
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if bar.channeling then Finish(bar) end
	elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		-- FAILED also fires for a spell you tried to start mid-cast; only react to the current cast.
		if bar.casting and (not castID or not bar.castID or castID == bar.castID) then
			Finish(bar, event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		if bar.casting or bar.channeling then Start(bar, bar.channeling) end
	end
end

local function CreateCastbar(unit, w, h, fontSize)
	local bar = ns.StatusBar(UIParent)
	bar.unit = unit
	bar:SetSize(w, h)
	ns.CreateBorder(bar)

	bar.icon = bar:CreateTexture(nil, "ARTWORK")
	bar.icon:SetSize(h, h)
	bar.icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local iconBorder = bar:CreateTexture(nil, "BACKGROUND")
	iconBorder:SetTexture(0, 0, 0, 1)
	iconBorder:SetPoint("TOPLEFT", bar.icon, -1, 1)
	iconBorder:SetPoint("BOTTOMRIGHT", bar.icon, 1, -1)

	bar.text = ns.FontString(bar, fontSize, "LEFT")
	bar.text:SetPoint("LEFT", 4, 0)
	bar.time = ns.FontString(bar, fontSize, "RIGHT")
	bar.time:SetPoint("RIGHT", -4, 0)
	bar.text:SetPoint("RIGHT", bar.time, "LEFT", -4, 0)

	for _, e in ipairs({
		"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
		"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
		"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	}) do
		bar:RegisterEvent(e)
	end
	bar:SetScript("OnEvent", OnEvent)
	bar:SetScript("OnUpdate", OnUpdate)
	bar:Hide()
	return bar
end

------------------------------------------------------------------------
-- Auto Shot swing timer
------------------------------------------------------------------------

local function CreateAutoShot(anchor)
	local autoShot = GetSpellInfo(75)
	local bar = ns.StatusBar(UIParent, unpack(ns.colors.accent))
	bar:SetHeight(4)
	bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
	bar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
	ns.CreateBorder(bar)
	bar:Hide()

	local repeating = false
	bar:RegisterEvent("START_AUTOREPEAT_SPELL")
	bar:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	bar:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	bar:SetScript("OnEvent", function(self, event, unit, spell)
		if event == "START_AUTOREPEAT_SPELL" then
			repeating = true
			self.endTime = nil
			self:SetMinMaxValues(0, 1)
			self:SetValue(1)
			self:SetStatusBarColor(0.45, 0.45, 0.45)
			self:Show()
		elseif event == "STOP_AUTOREPEAT_SPELL" then
			repeating = false
			if not self.endTime then self:Hide() end
		elseif unit == "player" and spell == autoShot then
			local speed = UnitRangedDamage("player")
			if not speed or speed <= 0 then return end
			self.startTime = GetTime()
			self.endTime = self.startTime + speed
			self:SetMinMaxValues(0, speed)
			self:SetStatusBarColor(unpack(ns.colors.accent))
			self:Show()
		end
	end)
	bar:SetScript("OnUpdate", function(self)
		if not self.endTime then return end
		local now = GetTime()
		if now >= self.endTime then
			self.endTime = nil
			if repeating then
				self:SetValue(select(2, self:GetMinMaxValues()))
				self:SetStatusBarColor(0.45, 0.45, 0.45)
			else
				self:Hide()
			end
			return
		end
		self:SetValue(now - self.startTime)
	end)
	return bar
end

ns.AddModule("CastBars", function()
	ns.Kill(CastingBarFrame)

	local player = CreateCastbar("player", 240, 18, 11)
	player.safe = player:CreateTexture(nil, "OVERLAY")
	player.safe:SetTexture(0.8, 0.2, 0.15, 0.45)
	ns.RegisterMover(player, "castbar", "Cast bar")

	if ns.class == "HUNTER" then
		ns.autoShotBar = CreateAutoShot(player)
	end

	local target = ns.frames and ns.frames.target
	if target then
		local tcb = CreateCastbar("target", 202, 14, 10)
		tcb:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -6)
		tcb:RegisterEvent("PLAYER_TARGET_CHANGED")
	end
end)
