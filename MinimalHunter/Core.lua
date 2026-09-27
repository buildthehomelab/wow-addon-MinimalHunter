local ADDON, ns = ...

ns.media = {
	blank = "Interface\\Buttons\\WHITE8X8",
	font = "Fonts\\ARIALN.TTF",
}

ns.colors = {
	bg = { 0.06, 0.06, 0.07, 0.85 },
	border = { 0, 0, 0, 1 },
	accent = { 0.67, 0.83, 0.45 }, -- hunter green
	text = { 0.9, 0.9, 0.9 },
	dim = { 0.45, 0.45, 0.45 },
	warn = { 0.9, 0.25, 0.2 },
	caution = { 0.95, 0.75, 0.2 },
}

ns.mult = 1

-- Default positions: { point, relativePoint (on UIParent), x, y }
ns.defaults = {
	pos = {
		bar1 = { "BOTTOM", "BOTTOM", 0, 14 },
		bar2 = { "BOTTOM", "BOTTOM", 0, 47 },
		bar3 = { "BOTTOM", "BOTTOM", 0, 80 },
		side = { "RIGHT", "RIGHT", -6, 0 },
		pet = { "BOTTOM", "BOTTOM", 0, 118 },
		micro = { "BOTTOMRIGHT", "BOTTOMRIGHT", -6, 4 },
		xp = { "BOTTOM", "BOTTOM", 0, 6 },
		castbar = { "BOTTOM", "BOTTOM", 0, 190 },
		player = { "BOTTOM", "BOTTOM", -250, 230 },
		target = { "BOTTOM", "BOTTOM", 250, 230 },
		targettarget = { "BOTTOMLEFT", "BOTTOM", 368, 230 },
		pet_frame = { "BOTTOMRIGHT", "BOTTOM", -140, 200 },
		focus = { "BOTTOMLEFT", "BOTTOM", -360, 282 },
		hunter = { "BOTTOMRIGHT", "BOTTOM", -368, 230 },
		minimap = { "TOPRIGHT", "TOPRIGHT", -12, -12 },
	},
}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local hider = CreateFrame("Frame", "MinimalHunterHider", UIParent)
hider:Hide()
ns.hider = hider

-- Permanently hide a Blizzard frame or texture.
function ns.Kill(obj)
	if not obj then return end
	if obj.UnregisterAllEvents then
		obj:UnregisterAllEvents()
		obj:SetParent(hider)
	else
		obj:Hide()
		obj.Show = obj.Hide
	end
end

-- Hide a frame but let Blizzard keep driving its events.
function ns.Stash(obj)
	if obj then obj:SetParent(hider) end
end

function ns.SetTemplate(f, alpha)
	f:SetBackdrop({
		bgFile = ns.media.blank,
		edgeFile = ns.media.blank,
		edgeSize = ns.mult,
	})
	local bg = ns.colors.bg
	f:SetBackdropColor(bg[1], bg[2], bg[3], alpha or bg[4])
	f:SetBackdropBorderColor(unpack(ns.colors.border))
end

-- A bordered backdrop that sits 1px outside `parent`.
function ns.CreateBorder(parent, alpha)
	local b = CreateFrame("Frame", nil, parent)
	b:SetPoint("TOPLEFT", -ns.mult, ns.mult)
	b:SetPoint("BOTTOMRIGHT", ns.mult, -ns.mult)
	b:SetFrameLevel(math.max(parent:GetFrameLevel() - 1, 0))
	ns.SetTemplate(b, alpha)
	parent.mhBorder = b
	return b
end

function ns.FontString(parent, size, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(ns.media.font, size or 12, "OUTLINE")
	fs:SetShadowOffset(0, 0)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetTextColor(unpack(ns.colors.text))
	return fs
end

function ns.StatusBar(parent, r, g, b)
	local sb = CreateFrame("StatusBar", nil, parent)
	sb:SetStatusBarTexture(ns.media.blank)
	sb:SetStatusBarColor(r or 0.5, g or 0.5, b or 0.5)
	sb:SetMinMaxValues(0, 1)
	sb:SetValue(0)
	local bg = sb:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(ns.media.blank)
	bg:SetVertexColor(0.12, 0.12, 0.13, 0.9)
	sb.bg = bg
	return sb
end

function ns.Short(v)
	if not v then return "" end
	if v >= 1e6 then
		return string.format("%.1fm", v / 1e6)
	elseif v >= 1e4 then
		return string.format("%.1fk", v / 1e3)
	end
	return tostring(v)
end

function ns.FormatTime(s)
	if s >= 3600 then
		return string.format("%dh", math.ceil(s / 3600))
	elseif s >= 60 then
		return string.format("%dm", math.ceil(s / 60))
	elseif s >= 3 then
		return string.format("%d", math.ceil(s))
	end
	return string.format("%.1f", s)
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffaad372MinimalHunter|r " .. msg)
end

------------------------------------------------------------------------
-- Run-after-combat queue
------------------------------------------------------------------------

local queue = {}
function ns.AfterCombat(fn)
	if InCombatLockdown() then
		table.insert(queue, fn)
	else
		fn()
	end
end

------------------------------------------------------------------------
-- Movers
------------------------------------------------------------------------

ns.movers = {}
local unlocked = false

function ns.ApplyPosition(key)
	local m = ns.movers[key]
	local p = MinimalHunterDB.pos[key] or ns.defaults.pos[key]
	m.frame:ClearAllPoints()
	m.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

function ns.RegisterMover(frame, key, label)
	ns.movers[key] = { frame = frame, label = label }
	ns.ApplyPosition(key)
end

local function CreateOverlay(key, m)
	local o = CreateFrame("Frame", nil, UIParent)
	o:SetFrameStrata("DIALOG")
	o:SetAllPoints(m.frame)
	o:EnableMouse(true)
	o:SetBackdrop({ bgFile = ns.media.blank, edgeFile = ns.media.blank, edgeSize = ns.mult })
	o:SetBackdropColor(0.67, 0.83, 0.45, 0.25)
	o:SetBackdropBorderColor(0.67, 0.83, 0.45, 0.9)
	local fs = ns.FontString(o, 11, "CENTER")
	fs:SetPoint("CENTER")
	fs:SetText(m.label)
	o:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			m.frame:SetMovable(true)
			m.frame:StartMoving()
		end
	end)
	o:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			MinimalHunterDB.pos[key] = nil
			ns.ApplyPosition(key)
			return
		end
		m.frame:StopMovingOrSizing()
		m.frame:SetUserPlaced(false)
		-- Save relative to UIParent's BOTTOMLEFT; convert to the frame's center for stability.
		local cx, cy = m.frame:GetCenter()
		local ux, uy = UIParent:GetCenter()
		local scale = m.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		MinimalHunterDB.pos[key] = { "CENTER", "CENTER", cx * scale - ux, cy * scale - uy }
		ns.ApplyPosition(key)
	end)
	m.overlay = o
	return o
end

function ns.SetUnlocked(state)
	if state and InCombatLockdown() then
		ns.Print("can't unlock in combat.")
		return
	end
	unlocked = state
	for key, m in pairs(ns.movers) do
		if state then
			(m.overlay or CreateOverlay(key, m)):Show()
		elseif m.overlay then
			m.overlay:Hide()
		end
	end
	if state then
		ns.Print("unlocked. Drag to move, right-click to reset a frame. |cffffffff/mh lock|r when done.")
	end
end

------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------

ns.modules = {}
function ns.AddModule(name, init)
	table.insert(ns.modules, { name = name, init = init })
end

local core = CreateFrame("Frame")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("PLAYER_REGEN_ENABLED")
core:RegisterEvent("PLAYER_REGEN_DISABLED")
core:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_ENABLED" then
		for i = 1, #queue do queue[i]() end
		wipe(queue)
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		if unlocked then ns.SetUnlocked(false) end
		return
	end

	-- PLAYER_LOGIN
	if IsAddOnLoaded("DragonUI") then
		ns.Print("|cffff5555is off because DragonUI is enabled.|r Disable one of them for this character in the AddOns list.")
		return
	end

	MinimalHunterDB = MinimalHunterDB or {}
	MinimalHunterDB.pos = MinimalHunterDB.pos or {}

	local height = tonumber(string.match(GetCVar("gxResolution") or "", "%d+x(%d+)"))
	if height then
		ns.mult = 768 / height / UIParent:GetScale()
	end

	local _, class = UnitClass("player")
	ns.class = class

	-- A /reload mid-fight can't touch protected frames yet; build the UI once combat ends.
	ns.AfterCombat(function()
		for _, m in ipairs(ns.modules) do
			local ok, err = pcall(m.init)
			if not ok then
				geterrorhandler()(ADDON .. " [" .. m.name .. "]: " .. tostring(err))
			end
		end
	end)
end)

SLASH_MINIMALHUNTER1 = "/mh"
SLASH_MINIMALHUNTER2 = "/minimalhunter"
SlashCmdList.MINIMALHUNTER = function(msg)
	msg = string.lower(strtrim(msg or ""))
	if msg == "unlock" or msg == "move" then
		ns.SetUnlocked(true)
	elseif msg == "lock" then
		ns.SetUnlocked(false)
	elseif msg == "reset" then
		if InCombatLockdown() then return ns.Print("can't reset in combat.") end
		wipe(MinimalHunterDB.pos)
		for key in pairs(ns.movers) do ns.ApplyPosition(key) end
		ns.Print("positions reset.")
	else
		ns.Print("commands: |cffffffff/mh unlock|r, |cffffffff/mh lock|r, |cffffffff/mh reset|r")
	end
end
