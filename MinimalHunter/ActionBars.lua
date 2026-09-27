local _, ns = ...

local SIZE, GAP = 30, 3
local PET_SIZE = 24
local SIDE_SIZE = 26

local styled = {}
ns.actionButtons = {}

local function ShortenKey(text)
	if not text or text == "" or text == RANGE_INDICATOR then return text end
	text = text:upper()
	text = text:gsub("SHIFT%-", "S")
	text = text:gsub("CTRL%-", "C")
	text = text:gsub("ALT%-", "A")
	text = text:gsub("MOUSE BUTTON ", "M")
	text = text:gsub("BUTTON", "M")
	text = text:gsub("MIDDLE MOUSE", "M3")
	text = text:gsub("MOUSE WHEEL UP", "WU")
	text = text:gsub("MOUSE WHEEL DOWN", "WD")
	text = text:gsub("NUM PAD ", "N")
	text = text:gsub("PAGE UP", "PU")
	text = text:gsub("PAGE DOWN", "PD")
	text = text:gsub("SPACEBAR", "SPC")
	text = text:gsub("INSERT", "INS")
	text = text:gsub("DELETE", "DEL")
	text = text:gsub("HOME", "HM")
	return text
end

local function StyleButton(b)
	if styled[b] then return end
	styled[b] = true

	local name = b:GetName()
	local icon = _G[name .. "Icon"]
	local hotkey = _G[name .. "HotKey"]
	local count = _G[name .. "Count"]
	local macro = _G[name .. "Name"]
	local flash = _G[name .. "Flash"]
	local border = _G[name .. "Border"]
	local cooldown = _G[name .. "Cooldown"]

	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:ClearAllPoints()
	icon:SetAllPoints(b)
	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(b)
	end

	for _, tex in pairs({ _G[name .. "NormalTexture"], _G[name .. "NormalTexture2"], b:GetNormalTexture() }) do
		tex:SetAlpha(0)
	end
	if border then border:SetAlpha(0) end
	if _G[name .. "FloatingBG"] then ns.Kill(_G[name .. "FloatingBG"]) end
	if _G[name .. "AutoCastable"] then
		-- Pet autocast corner arrows: keep, but fit to the square.
		local ac = _G[name .. "AutoCastable"]
		ac:ClearAllPoints()
		ac:SetPoint("TOPLEFT", -8, 8)
		ac:SetPoint("BOTTOMRIGHT", 8, -8)
	end

	local hl = b:GetHighlightTexture()
	hl:SetTexture(1, 1, 1, 0.15)
	hl:SetAllPoints(b)
	local pushed = b:GetPushedTexture()
	pushed:SetTexture(1, 1, 1, 0.25)
	pushed:SetAllPoints(b)
	if b.GetCheckedTexture and b:GetCheckedTexture() then
		local checked = b:GetCheckedTexture()
		checked:SetTexture(0.67, 0.83, 0.45, 0.35)
		checked:SetAllPoints(b)
	end
	if flash then
		-- Red wash while Auto Shot / Attack is repeating.
		flash:SetTexture(0.9, 0.2, 0.15, 0.35)
		flash:SetAllPoints(b)
	end

	if hotkey then
		hotkey:SetFont(ns.media.font, 10, "OUTLINE")
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", -1, -2)
		hotkey:SetJustifyH("RIGHT")
	end
	if count then
		count:SetFont(ns.media.font, 11, "OUTLINE")
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -1, 2)
	end
	if macro then macro:SetAlpha(0) end

	ns.CreateBorder(b, 0.6)
end

local function Row(holder, prefix, count, size, vertical)
	for i = 1, count do
		local b = _G[prefix .. i]
		b:ClearAllPoints()
		b:SetSize(size, size)
		if i == 1 then
			b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		elseif vertical then
			b:SetPoint("TOP", _G[prefix .. (i - 1)], "BOTTOM", 0, -GAP)
		else
			b:SetPoint("LEFT", _G[prefix .. (i - 1)], "RIGHT", GAP, 0)
		end
		StyleButton(b)
	end
end

local function Holder(name, key, label, w, h, template)
	local f = CreateFrame("Frame", name, UIParent, template)
	f:SetSize(w, h)
	ns.RegisterMover(f, key, label)
	return f
end

-- Fade a frame in only while the mouse is over it.
function ns.MouseoverFade(frame, minAlpha)
	minAlpha = minAlpha or 0
	frame:SetAlpha(minAlpha)
	local t = 0
	frame:HookScript("OnUpdate", function(self, elapsed)
		t = t + elapsed
		if t < 0.1 then return end
		t = 0
		local over = MouseIsOver(self, 4, -4, -4, 4) or (SpellBookFrame and SpellBookFrame:IsShown() and CursorHasSpell())
		self:SetAlpha(over and 1 or minAlpha)
	end)
end

------------------------------------------------------------------------
-- Range / usability tint on the icon
------------------------------------------------------------------------

local function UpdateUsable(b)
	local action = b.action
	local icon = _G[b:GetName() .. "Icon"]
	if not action or not icon or not HasAction(action) then return end
	local usable, noMana = IsUsableAction(action)
	if ActionHasRange(action) and IsActionInRange(action) == 0 then
		icon:SetVertexColor(0.85, 0.25, 0.25)
	elseif usable then
		icon:SetVertexColor(1, 1, 1)
	elseif noMana then
		icon:SetVertexColor(0.35, 0.45, 0.9)
	else
		icon:SetVertexColor(0.35, 0.35, 0.35)
	end
end

ns.AddModule("ActionBars", function()
	local w12 = 12 * SIZE + 11 * GAP

	-- Blizzard's bar art: keep MainMenuBar alive (vehicle animations run on it) but invisible.
	MainMenuBar:EnableMouse(false)
	MainMenuBar:SetAlpha(0)
	MainMenuBarArtFrame:SetAlpha(0)
	MainMenuBarArtFrame:EnableMouse(false)
	for _, name in ipairs({ "MainMenuExpBar", "ReputationWatchBar", "MainMenuBarMaxLevelBar", "ShapeshiftBarFrame", "PossessBarFrame", "MainMenuBarPerformanceBarFrame" }) do
		ns.Stash(_G[name])
	end
	if BonusActionBarFrame then
		-- The page driver below swaps bar 1 to the vehicle/possess page instead.
		BonusActionBarFrame:UnregisterAllEvents()
		ns.Stash(BonusActionBarFrame)
	end
	if ExhaustionTick then ExhaustionTick:SetScript("OnUpdate", nil) end

	-- Make sure the four extra bars are turned on in Interface Options.
	if not (SHOW_MULTI_ACTIONBAR_1 and SHOW_MULTI_ACTIONBAR_2 and SHOW_MULTI_ACTIONBAR_3 and SHOW_MULTI_ACTIONBAR_4) then
		SetActionBarToggles(1, 1, 1, 1)
	end

	-- Everything bar-related hides while the Blizzard vehicle UI is up.
	local root = CreateFrame("Frame", "MinimalHunterBars", UIParent, "SecureHandlerStateTemplate")
	root:SetAllPoints(UIParent)
	RegisterStateDriver(root, "visibility", "[vehicleui] hide; show")

	-- Bar 1: the main action bar, paged by a state driver.
	local bar1 = Holder("MinimalHunterBar1", "bar1", "Bar 1", w12, SIZE, "SecureHandlerStateTemplate")
	bar1:SetParent(root)
	for i = 1, 12 do
		local b = _G["ActionButton" .. i]
		b:SetParent(bar1)
		bar1:SetFrameRef("b" .. i, b)
	end
	Row(bar1, "ActionButton", 12, SIZE)
	bar1:Execute([[
		buttons = newtable()
		for i = 1, 12 do table.insert(buttons, self:GetFrameRef("b" .. i)) end
	]])
	bar1:SetAttribute("_onstate-page", [[
		for _, b in ipairs(buttons) do b:SetAttribute("actionpage", tonumber(newstate)) end
	]])
	RegisterStateDriver(bar1, "page", "[bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1")

	-- Bars 2 and 3 stacked above it.
	local bar2 = Holder("MinimalHunterBar2", "bar2", "Bar 2", w12, SIZE)
	bar2:SetParent(root)
	MultiBarBottomLeft:SetParent(bar2)
	MultiBarBottomLeft:ClearAllPoints()
	MultiBarBottomLeft:SetAllPoints(bar2)
	Row(bar2, "MultiBarBottomLeftButton", 12, SIZE)

	local bar3 = Holder("MinimalHunterBar3", "bar3", "Bar 3", w12, SIZE)
	bar3:SetParent(root)
	MultiBarBottomRight:SetParent(bar3)
	MultiBarBottomRight:ClearAllPoints()
	MultiBarBottomRight:SetAllPoints(bar3)
	Row(bar3, "MultiBarBottomRightButton", 12, SIZE)

	-- Right-hand vertical bars, shown on mouseover.
	local sideH = 12 * SIDE_SIZE + 11 * GAP
	local side = Holder("MinimalHunterSideBars", "side", "Side bars", SIDE_SIZE * 2 + GAP, sideH)
	side:SetParent(root)
	local right = CreateFrame("Frame", nil, side)
	right:SetSize(SIDE_SIZE, sideH)
	right:SetPoint("TOPRIGHT")
	local left = CreateFrame("Frame", nil, side)
	left:SetSize(SIDE_SIZE, sideH)
	left:SetPoint("TOPLEFT")
	MultiBarRight:SetParent(right)
	MultiBarRight:ClearAllPoints()
	MultiBarRight:SetAllPoints(right)
	MultiBarLeft:SetParent(left)
	MultiBarLeft:ClearAllPoints()
	MultiBarLeft:SetAllPoints(left)
	Row(right, "MultiBarRightButton", 12, SIDE_SIZE, true)
	Row(left, "MultiBarLeftButton", 12, SIDE_SIZE, true)
	ns.MouseoverFade(side, 0)

	-- Pet bar. Blizzard's PetActionBarFrame keeps updating the buttons; we only own layout and visibility.
	local petW = 10 * PET_SIZE + 9 * GAP
	local pet = Holder("MinimalHunterPetBar", "pet", "Pet bar", petW, PET_SIZE, "SecureHandlerStateTemplate")
	pet:SetParent(root)
	PetActionBarFrame:SetParent(pet)
	PetActionBarFrame:EnableMouse(false)
	for _, tex in ipairs({ SlidingActionBarTexture0, SlidingActionBarTexture1 }) do
		if tex then tex:SetAlpha(0) end
	end
	for i = 1, 10 do
		_G["PetActionButton" .. i]:SetParent(pet)
	end
	Row(pet, "PetActionButton", 10, PET_SIZE)
	RegisterStateDriver(pet, "visibility", "[pet,novehicleui,nobonusbar:5] show; hide")

	for i = 1, 12 do
		table.insert(ns.actionButtons, _G["ActionButton" .. i])
		table.insert(ns.actionButtons, _G["MultiBarBottomLeftButton" .. i])
		table.insert(ns.actionButtons, _G["MultiBarBottomRightButton" .. i])
		table.insert(ns.actionButtons, _G["MultiBarRightButton" .. i])
		table.insert(ns.actionButtons, _G["MultiBarLeftButton" .. i])
	end

	-- Compact key labels.
	hooksecurefunc("ActionButton_UpdateHotkeys", function(self)
		local hk = _G[self:GetName() .. "HotKey"]
		if hk then hk:SetText(ShortenKey(hk:GetText())) end
	end)
	for _, b in ipairs(ns.actionButtons) do
		ActionButton_UpdateHotkeys(b, b.buttonType)
	end

	-- Range/usability tint, re-applied after Blizzard recolors on events.
	hooksecurefunc("ActionButton_UpdateUsable", function(self)
		if styled[self] then UpdateUsable(self) end
	end)
	local ticker, t = CreateFrame("Frame"), 0
	ticker:SetScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		if t < 0.2 then return end
		t = 0
		for _, b in ipairs(ns.actionButtons) do
			if b:IsVisible() then UpdateUsable(b) end
		end
	end)
end)
