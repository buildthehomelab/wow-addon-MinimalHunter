local _, ns = ...

local SIZE = 150

ns.AddModule("Minimap", function()
	if not IsAddOnLoaded("Blizzard_TimeManager") then LoadAddOn("Blizzard_TimeManager") end

	-- Square, bordered minimap, detached from the cluster.
	MinimapCluster:EnableMouse(false)
	Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
	Minimap:SetSize(SIZE, SIZE)
	ns.CreateBorder(Minimap, 1)
	ns.RegisterMover(Minimap, "minimap", "Minimap")
	-- Blip positions refresh on a zoom change after a resize.
	local zoom = Minimap:GetZoom()
	Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
	Minimap:SetZoom(zoom)

	for _, name in ipairs({
		"MinimapBorder", "MinimapBorderTop", "MinimapNorthTag", "MinimapCompassTexture",
		"MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MinimapToggleButton",
		"MiniMapVoiceChatFrame", "GameTimeFrame", "MiniMapMailBorder", "MiniMapBattlefieldBorder",
		"MiniMapLFGFrameBorder",
	}) do
		ns.Kill(_G[name])
	end
	-- Tracking stays reachable via right-click, so keep its events alive.
	ns.Stash(MiniMapTracking)

	-- Status icons pinned inside the square.
	local function Pin(f, point, x, y)
		if not f then return end
		f:SetParent(Minimap)
		f:SetFrameLevel(Minimap:GetFrameLevel() + 3)
		f:ClearAllPoints()
		f:SetPoint(point, Minimap, point, x, y)
	end
	Pin(MiniMapMailFrame, "TOPRIGHT", 2, 2)
	Pin(MiniMapBattlefieldFrame, "BOTTOMLEFT", -2, -2)
	Pin(MiniMapLFGFrame, "BOTTOMLEFT", -2, -2)
	Pin(MiniMapInstanceDifficulty, "TOPLEFT", -6, 6)

	-- Clock: plain text, bottom center.
	if TimeManagerClockButton then
		Pin(TimeManagerClockButton, "BOTTOM", 0, -6)
		local bg = TimeManagerClockButton:GetRegions()
		if bg and bg.SetTexture then bg:SetTexture(nil) end
		TimeManagerClockTicker:SetFont(ns.media.font, 11, "OUTLINE")
		TimeManagerClockTicker:SetShadowOffset(0, 0)
	end

	-- Zone name at the top, only while hovering.
	MinimapZoneTextButton:SetParent(Minimap)
	MinimapZoneTextButton:ClearAllPoints()
	MinimapZoneTextButton:SetPoint("TOP", Minimap, "TOP", 0, -4)
	MinimapZoneTextButton:SetFrameLevel(Minimap:GetFrameLevel() + 3)
	MinimapZoneTextButton:EnableMouse(false)
	MinimapZoneText:SetFont(ns.media.font, 11, "OUTLINE")
	MinimapZoneText:SetShadowOffset(0, 0)
	MinimapZoneTextButton:SetAlpha(0)
	Minimap:HookScript("OnEnter", function() MinimapZoneTextButton:SetAlpha(1) end)
	Minimap:HookScript("OnLeave", function() MinimapZoneTextButton:SetAlpha(0) end)

	-- Wheel to zoom; right-click tracking; middle-click calendar.
	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", function(self, delta)
		local z = self:GetZoom() + (delta > 0 and 1 or -1)
		if z >= 0 and z < self:GetZoomLevels() then self:SetZoom(z) end
	end)
	Minimap:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
		elseif button == "MiddleButton" then
			if ToggleCalendar then ToggleCalendar() end
		else
			Minimap_OnClick(self)
		end
	end)

	-- Buffs hug the minimap. BuffFrame may hang off TemporaryEnchantFrame; move whichever leads.
	TemporaryEnchantFrame:ClearAllPoints()
	TemporaryEnchantFrame:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -12, 0)
	local _, rel = BuffFrame:GetPoint()
	if rel ~= TemporaryEnchantFrame then
		BuffFrame:ClearAllPoints()
		BuffFrame:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -12, 0)
	end
end)
