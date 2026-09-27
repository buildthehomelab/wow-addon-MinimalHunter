local _, ns = ...

------------------------------------------------------------------------
-- Cooldown numbers on buttons and aura icons
------------------------------------------------------------------------

local function TimerOnUpdate(self, elapsed)
	self.tick = (self.tick or 0) - elapsed
	if self.tick > 0 then return end
	self.tick = 0.1
	local remain = self.endTime - GetTime()
	if remain <= 0 then
		self:Hide()
		return
	end
	if remain < 5 then
		self.text:SetTextColor(1, 0.3, 0.25)
	elseif remain < 60 then
		self.text:SetTextColor(1, 0.95, 0.6)
	else
		self.text:SetTextColor(0.8, 0.8, 0.8)
	end
	self.text:SetText(ns.FormatTime(remain))
end

local function SetupCooldownText()
	local mt = getmetatable(ActionButton1Cooldown).__index
	hooksecurefunc(mt, "SetCooldown", function(cd, start, duration)
		local timer = cd.mhTimer
		local width = cd:GetParent() and cd:GetParent():GetWidth() or 0
		if start and start > 0 and duration and duration > 2 and width >= 18 then
			if not timer then
				timer = CreateFrame("Frame", nil, cd)
				timer:SetAllPoints(cd)
				timer:SetFrameLevel(cd:GetFrameLevel() + 3)
				timer.text = ns.FontString(timer, 12, "CENTER")
				timer.text:SetPoint("CENTER", 1, 0)
				timer:SetScript("OnUpdate", TimerOnUpdate)
				cd.mhTimer = timer
			end
			timer.text:SetFont(ns.media.font, math.max(9, math.floor(width * 0.42)), "OUTLINE")
			timer.endTime = start + duration
			timer.tick = 0
			timer:Show()
		elseif timer then
			timer:Hide()
		end
	end)
end

------------------------------------------------------------------------
-- Thin XP bar
------------------------------------------------------------------------

local function SetupXPBar()
	local w = 12 * 30 + 11 * 3
	local holder = CreateFrame("Frame", "MinimalHunterXP", UIParent)
	holder:SetSize(w, 4)
	ns.RegisterMover(holder, "xp", "XP bar")
	ns.CreateBorder(holder)

	local rested = ns.StatusBar(holder, 0.3, 0.5, 0.9)
	rested:SetAllPoints()
	rested:SetAlpha(0.6)
	local xp = CreateFrame("StatusBar", nil, holder)
	xp:SetStatusBarTexture(ns.media.blank)
	xp:SetStatusBarColor(0.62, 0.4, 0.88)
	xp:SetAllPoints()
	xp:SetFrameLevel(rested:GetFrameLevel() + 1)

	local function Update()
		local maxLevel = MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or MAX_PLAYER_LEVEL
		if UnitLevel("player") >= (maxLevel or 80) or (IsXPUserDisabled and IsXPUserDisabled()) then
			holder:Hide()
			return
		end
		holder:Show()
		local cur, max = UnitXP("player"), UnitXPMax("player")
		local rest = GetXPExhaustion() or 0
		xp:SetMinMaxValues(0, max)
		xp:SetValue(cur)
		rested:SetMinMaxValues(0, max)
		rested:SetValue(math.min(cur + rest, max))
	end

	holder:EnableMouse(true)
	holder:SetScript("OnEnter", function(self)
		local cur, max = UnitXP("player"), UnitXPMax("player")
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(string.format("Level %d", UnitLevel("player")))
		GameTooltip:AddDoubleLine("XP", string.format("%d / %d (%.1f%%)", cur, max, cur / max * 100), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("To level", max - cur, 1, 1, 1, 1, 1, 1)
		local rest = GetXPExhaustion()
		if rest then
			GameTooltip:AddDoubleLine("Rested", string.format("%d (%.0f%%)", rest, rest / max * 100), 0.4, 0.6, 1, 0.4, 0.6, 1)
		end
		GameTooltip:Show()
	end)
	holder:SetScript("OnLeave", GameTooltip_Hide)

	for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN" }) do
		holder:RegisterEvent(e)
	end
	holder:SetScript("OnEvent", Update)
	Update()
end

------------------------------------------------------------------------
-- Micro menu + bags, shown on mouseover (bottom right)
------------------------------------------------------------------------

local MICRO = {
	"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton",
	"QuestLogMicroButton", "SocialsMicroButton", "PVPMicroButton", "LFDMicroButton",
	"MainMenuMicroButton", "HelpMicroButton",
}
local BAGS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton" }
local SCALE = 0.8

local function SetupMicroMenu()
	local holder = CreateFrame("Frame", "MinimalHunterMicro", UIParent)
	holder:SetSize(212, 84)
	ns.RegisterMover(holder, "micro", "Menu + bags")

	local function LayoutMicro()
		local prev
		for _, name in ipairs(MICRO) do
			local b = _G[name]
			if b then
				b:SetParent(holder)
				b:SetScale(SCALE)
				b:ClearAllPoints()
				if prev then
					b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", -3, 0)
				else
					b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
				end
				prev = b
			end
		end
	end

	local prev
	for _, name in ipairs(BAGS) do
		local b = _G[name]
		if b then
			b:SetParent(holder)
			b:SetScale(SCALE)
			b:ClearAllPoints()
			if prev then
				b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
			else
				b:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
			end
			prev = b
		end
	end

	LayoutMicro()
	-- Leaving a vehicle hands the micro buttons back to the (hidden) Blizzard bar.
	if VehicleMenuBar_MoveMicroButtons then
		hooksecurefunc("VehicleMenuBar_MoveMicroButtons", function(skin)
			if not skin then LayoutMicro() end
		end)
	end
	if MoveMicroButtons then
		hooksecurefunc("MoveMicroButtons", function(_, anchorTo)
			if anchorTo == MainMenuBarArtFrame then LayoutMicro() end
		end)
	end

	ns.MouseoverFade(holder, 0)
end

------------------------------------------------------------------------
-- Chat: drop the button clutter, scroll with the wheel
------------------------------------------------------------------------

local function ChatScroll(self, delta)
	if delta > 0 then
		if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
	else
		if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
	end
end

local function SetupChat()
	for i = 1, NUM_CHAT_WINDOWS do
		for _, suffix in ipairs({ "ButtonFrame", "UpButton", "DownButton", "BottomButton" }) do
			ns.Kill(_G["ChatFrame" .. i .. suffix])
		end
		local cf = _G["ChatFrame" .. i]
		if cf and not cf:GetScript("OnMouseWheel") then
			cf:EnableMouseWheel(true)
			cf:SetScript("OnMouseWheel", ChatScroll)
		end
	end
	ns.Kill(ChatFrameMenuButton)
	ns.Kill(FriendsMicroButton)
end

ns.AddModule("Misc", function()
	SetupCooldownText()
	SetupXPBar()
	SetupMicroMenu()
	SetupChat()
end)
