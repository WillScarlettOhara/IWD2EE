
-- HD UI master gate (install-time, flipped false->true by the WeiDU 2x UI component). See the same
-- flag in IEex_UIScale_Patch.lua. Core ships OFF = stock 1x UI.
local IEEX_HD_UI = false

-----------------------
-- General Functions --
-----------------------

function IEex_GetCursorXY()
	local g_pBaldurChitin = IEex_ReadDword(0x8CF6DC)
	local x = IEex_ReadDword(g_pBaldurChitin + 0x1906)
	local y = IEex_ReadDword(g_pBaldurChitin + 0x190A)
	return x, y
end

function IEex_GetPrivateProfileInt(lpAppName, lpKeyName, nDefault, lpFileName)
	local toReturn
	IEex_RunWithStackManager({
		{["name"] = "lpAppName",  ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpAppName}  }},
		{["name"] = "lpKeyName",  ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpKeyName}  }},
		{["name"] = "lpFileName", ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpFileName} }}, },
		function(manager)
			toReturn = IEex_Call(IEex_ReadDword(0x847310), {
				manager:getAddress("lpFileName"),
				nDefault,
				manager:getAddress("lpKeyName"),
				manager:getAddress("lpAppName"),
			})
		end)
	return toReturn
end

function IEex_WritePrivateProfileInt(lpAppName, lpKeyName, nInt, lpFileName)
	IEex_WritePrivateProfileString(lpAppName, lpKeyName, tostring(nInt), lpFileName)
end

function IEex_WritePrivateProfileString(lpAppName, lpKeyName, lpString, lpFileName)
	IEex_RunWithStackManager({
		{["name"] = "lpAppName",  ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpAppName}  }},
		{["name"] = "lpKeyName",  ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpKeyName}  }},
		{["name"] = "lpString",   ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpString}   }},
		{["name"] = "lpFileName", ["struct"] = "string", ["constructor"] = {["luaArgs"] = {lpFileName} }}, },
		function(manager)
			IEex_Call(IEex_ReadDword(0x847308), {
				manager:getAddress("lpFileName"),
				manager:getAddress("lpString"),
				manager:getAddress("lpKeyName"),
				manager:getAddress("lpAppName"),
			})
		end)
end

-- The GL renderer requires [Program Options] "3D Acceleration"=1, but a fresh (GOG) install ships
-- an explicit =0 and the engine re-persists its runtime field back to the key on shutdown -- an
-- explicit 0 would otherwise lock the software renderer forever (the README already promises:
-- "IWD2EE turns on 3D Acceleration automatically at each launch"). Rewrite the key EVERY launch,
-- before anything reads it (the IEEX_HD_UI / IEEX_GL_ACTIVE reads below run at State load; every
-- *_Patch.lua gate runs later). Player opt-out: [IEex Options] "Software Renderer"=1 -> the key is
-- forced 0 instead -> every GL gate (render/UI-scale/zoom/HD-tiles) self-disables coherently.
if not IEex_Vanilla then
	local softwareRenderer = IEex_GetPrivateProfileInt("IEex Options", "Software Renderer", 0, ".\\Icewind2.ini") ~= 0
	IEex_WritePrivateProfileInt("IEex Options", "Software Renderer", softwareRenderer and 1 or 0, ".\\Icewind2.ini")
	IEex_WritePrivateProfileInt("Program Options", "3D Acceleration", softwareRenderer and 0 or 1, ".\\Icewind2.ini")

	-- The GOG install ships [Program Options] "Gamma Correction"=2 (the in-game "contrast"
	-- slider, notch 2 of 5; the engine's own default for a missing key is 0 = identity).
	-- Vanilla applies that boost to the scene AND the mainscreen MOS alike, so it reads
	-- coherent; modded, the mainscreen MOS deliberately renders gamma-less ("Disable
	-- Gamma-correction on mainscreen MOS" in IEex_Gui_Patch.lua), which turns the HUD into
	-- a neutral reference the boosted scene clashes against -- the shipped default looks
	-- over-contrasted until the player discovers the slider. Normalize to 0 ONCE per
	-- install, behind a marker key: later launches never touch it again, so the in-game
	-- contrast slider stays fully respected.
	if IEex_GetPrivateProfileInt("IEex Options", "Gamma Normalized", 0, ".\\Icewind2.ini") == 0 then
		local shippedGamma = IEex_GetPrivateProfileInt("Program Options", "Gamma Correction", 0, ".\\Icewind2.ini")
		if shippedGamma ~= 0 then
			print(string.format("[IEex] Normalized [Program Options] \"Gamma Correction\" %d -> 0 (one-time; the GOG default is tuned for the unmodded renderer)", shippedGamma))
		end
		IEex_WritePrivateProfileInt("Program Options", "Gamma Correction", 0, ".\\Icewind2.ini")
		IEex_WritePrivateProfileInt("IEex Options", "Gamma Normalized", 1, ".\\Icewind2.ini")
	end

	-- Seed the remaining [IEex Options] keys so a fresh Icewind2.ini is fully populated on
	-- the first launch (the in-game IEex Options menu otherwise materialises each key only
	-- when its row is built/toggled). Read-with-default then write BACK the read value: an
	-- existing key keeps the player's value (never re-clobbered to its default), an absent
	-- key is created at its default. Software Renderer is handled above.
	local ex_ini_option_defaults = {
		{"Present Thread", 1},
		{"HUD Layer", 1},
		{"UI Scale", 100},
		{"SFX Audible Percent", 60},
		{"Loop Sleep Ms", 0},
		{"IP Behavior Flags", 15},
		{"IP Enemy Bumping", 1},
		{"IP Directed Adjust", 1},
		{"IP Combat Slide", 0},
		{"Windowed", 0},
		{"Run In Background", 1},
		{"Vsync", 1},
		{"Max FPS", 0},
		{"Show FPS", 0},
		{"Tile Atlas", 1},
		{"Colored Selection Circles", 0},
		{"Selection Circle Thickness", 1},
		{"Destination Marker Thickness", 0},
		{"Colored Portrait Frames", 0},
		{"Portrait Frame Thickness", 1},
		{"Smooth Cursor", 1},
		{"Stretch UI to Screen", 0},
		{"Integer Zoom", 0},
		{"Cutscene Log", 0},
		{"Cutscene Zoom", 1},
		{"UI Borders", 1},
		{"Transparent Fog of War", 0},
		{"Action Indicators", 1},
		{"Highlight Empty Containers in Gray", 1},
		{"Improved Pathfinding", 1},
		{"IP Pursuit Repath", 8},
		{"IP Pursuit Keep Path", 1},
		{"IP Bump Idle NPCs", 1},
		{"IP Ally Queue", 1},
		{"IP Collision Smoothing", 0},
		{"IP Enemy Soft Block", 0},
		{"Prevent Equipping Armor During Combat", 0},
	}
	for _, opt in ipairs(ex_ini_option_defaults) do
		IEex_WritePrivateProfileInt("IEex Options", opt[1], IEex_GetPrivateProfileInt("IEex Options", opt[1], opt[2], ".\\Icewind2.ini"), ".\\Icewind2.ini")
	end
	if softwareRenderer then
		-- Without cnc-ddraw (ddraw.dll in the game root) the stock software blit is unaccelerated
		-- and crawls at high resolutions. cnc-ddraw is harmless under GL (the GL path never calls
		-- DirectDrawCreate, the wrapper stays dormant), so it can stay installed as the software
		-- fallback. Tell the player why software mode is slow when it is missing.
		local ddraw = io.open("ddraw.dll", "rb")
		if ddraw then
			ddraw:close()
		else
			print("[IEex] Software Renderer=1 but cnc-ddraw (ddraw.dll) is absent -- software mode will be VERY slow at high resolutions; reinstall the ddrawfix component or lower the resolution.")
		end
	end
end

-- Software-renderer opt-out ("3D Acceleration" = 0, normalized just above from "Software
-- Renderer"): the software
-- (DirectDraw) renderer has no GL canvas to downscale a 2x UI, so force HD UI off here -> the whole
-- 2x machinery (engine m_bUseNewGui doubling @1598 + every IEex coord *2 @374/1981/2151 + divider
-- read @3102) stays disabled and the stock 1x UI renders correctly. Mirrors the GL-enable gate in
-- IEex_Render_Patch.lua and the hook gate in IEex_UIScale_Patch.lua. (No `local` -> NOT touched by
-- the 2x UI component's REPLACE_TEXTUALLY of `local IEEX_HD_UI = false`.)
if IEEX_HD_UI and IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") == 0 then
	IEEX_HD_UI = false
end

-- True when the GL renderer is active (stock ini key "3D Acceleration" != 0, launch-time config).
-- Used to hide GL-irrelevant options (e.g. "Transparent Fog of War", whose software FoW pass is
-- skipped in GL -- see Export_RenderFoW). Global (no `local`) to mirror IEEX_HD_UI and stay visible
-- to the option-panel builder / IEex_Load|WriteOptions defined later in this chunk.
IEEX_GL_ACTIVE = IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") ~= 0

-- IEex Options menu (panel 14) option rows, top->bottom by LABEL id. Some rows are renderer-specific
-- and are not built (and their toggle is skipped in IEex_InitOptionButtons) in the wrong renderer:
--   Transparent Fog of War (5) is SOFTWARE-only  -> hidden under GL  (Export_RenderFoW early-returns in GL).
--   Stretch UI (13), Vsync (17) are GL-only -> hidden in software
--   (their C++ no-ops without a GL context: ComputeUIScale / EnsureVSync).
--   Colored Portrait Frames (23) needs the World HUD Refonte, which is what installs the portrait
--   render override the tint lives in -> the row only exists when IEex_Gui_Patch.lua wrote that
--   hook (IEEX_PORTRAIT_FRAMES_AVAILABLE). It works under BOTH renderers (the override's DrawLine
--   fallback covers software), so do NOT gate it on GL. Frame WEIGHT has no row either: [IEex
--   Options] "Portrait Frame Thickness" (0 = follow the circles). (Row 23 was 'Smooth Cursor',
--   now hardwired via its ini key only -- nobody turns it off, and it needs a restart.)
--   Colored Selection Circles (27) is renderer-independent (the tint hooks CMarker::Asynchronous-
--   Update, not a draw call) -> always visible. Only the marker THICKNESS that ships with it is
--   GL-only, and that has no row: [IEex Options] "Selection Circle Thickness" in Icewind2.ini.
--   (Row 27 was 'Tile Atlas', now hardwired via its ini key only -- nobody turns it off.)
--   Integer Zoom (29) is GL-only (the camera zoom is a GL matrix; the software renderer never
--   leaves 1.0) -> hidden in software. It took its slot from 'Cap FPS to Display Refresh' (25),
--   now hardwired via its ini key only ([IEex Options] "Max FPS"): that cap needs a restart to
--   take effect, so the row was worth less than one that applies live.
--   The panel fits 11 rows at the authored 27px step; IEex_OptionRowStep tightens the step only
--   if a longer list would run the bottom row into the Done/Cancel bar.
--   Improved Pathfinding (21) is renderer-independent -> always visible. (Row 21 was 'UI Single
--   Buffer', now hardwired via its ini key only: =0 is never correct with the GL present FBO --
--   RENDER_COUNT=2 on a single buffer truncates dialog/UI text until an alt-tab FBO rebuild.)
-- IEex_OptionRowY packs the VISIBLE rows so a hidden one leaves no gap, on a step that is 27px
-- whenever the list fits and tightens just enough when it does not (IEex_OptionRowStep).
--
-- ORDER = what the player sees, top to bottom, grouped by what the option is about:
--   rules            11 armour-in-combat, 21 pathfinding
--   world readability 7 action indicators, 9 empty containers, 27 selection circles,
--                    23 portrait frames, 5 transparent fog
--   interface        19 UI borders, 13 stretch UI, 29 integer zoom
--   display          17 vsync, 15 FPS counter
-- Every row coordinate is DERIVED from this table (IEex_OptionRowY), so reordering the menu
-- is a one-line edit here -- it used to mean hand-editing 24 hardcoded y values in lockstep.
IEEX_OPTION_ROW_ORDER = {11, 21, 7, 9, 27, 23, 5, 19, 13, 29, 17, 15}

function IEex_OptionRowVisible(labelId)
	if labelId == 5 then return not IEEX_GL_ACTIVE end
	if labelId == 13 or labelId == 17 or labelId == 29 then return IEEX_GL_ACTIVE end
	-- Captured from IEex_PortraitGridEnabled at load (see the declaration): read live it would
	-- go false at game load via IEex_InstallPortraitGrid's veto, and read from a patch-file
	-- global it would be missing on the Async thread, where IEex_InitOptionButtons runs.
	-- `== true` keeps an undefined global falsy-safe on a core-only install.
	if labelId == 23 then return IEEX_PORTRAIT_FRAMES_AVAILABLE == true end
	return true
end

-- Option label/description text: the TRA strref when the mod's strings are installed,
-- otherwise the English fallback. Needed because a freshly deployed lua can run against an
-- IEex_TRA.LUA whose placeholders are still 0 (the WeiDU install resolves them), and
-- IEex_FetchString(0) would render strref 0.
function IEex_OptionText(traId, fallback)
	return (traId or 0) ~= 0 and IEex_FetchString(traId) or fallback
end

function IEex_OptionRowCount()
	local n = 0
	for _, id in ipairs(IEEX_OPTION_ROW_ORDER) do
		if IEex_OptionRowVisible(id) then n = n + 1 end
	end
	return n
end

-- Vertical step between rows. 27px is the authored spacing and stays exact for any list that
-- fits; it only tightens when the visible rows would otherwise run into the Done/Cancel bar at
-- y=375 (labels are 18px tall and toggles sit 3px higher and are 24px tall, so the LAST label
-- must start by IEEX_OPTION_ROW_LAST_Y). The row list grew to 12 under GL when "Pixel-perfect
-- zoom" was added, which at 27px put the bottom row's toggle in the button strip.
IEEX_OPTION_ROW_FIRST_Y = 70
IEEX_OPTION_ROW_LAST_Y  = 345
function IEex_OptionRowStep()
	local n = IEex_OptionRowCount()
	if n < 2 then return 27 end
	local step = math.floor((IEEX_OPTION_ROW_LAST_Y - IEEX_OPTION_ROW_FIRST_Y) / (n - 1))
	if step > 27 then step = 27 end
	return step
end

-- Y of a row's LABEL, straight from its position in IEEX_OPTION_ROW_ORDER: hidden rows are
-- skipped (no gap) and the remaining ones are packed on the step above, starting at
-- IEEX_OPTION_ROW_FIRST_Y. Toggles sit 3px higher. Deriving both means the menu order lives in
-- exactly one place.
function IEex_OptionRowY(labelId)
	local step = IEex_OptionRowStep()
	local visibleAbove = 0
	for _, id in ipairs(IEEX_OPTION_ROW_ORDER) do
		if id == labelId then return IEEX_OPTION_ROW_FIRST_Y + visibleAbove * step end
		if IEex_OptionRowVisible(id) then visibleAbove = visibleAbove + 1 end
	end
	return IEEX_OPTION_ROW_FIRST_Y
end

-- Which options-screen panel opened the IEex options panel (14): 2 = in-game main options panel,
-- 13 = main-menu options popup (the engine hides panel 2 + summons popup 13 pre-game, so the in-game
-- button on panel 2 is never visible there -- a duplicate button lives on panel 13). open/close restore it.
IEex_OptionsParentPanelID = 2

function IEex_GetPrivateProfileString(lpAppName, lpKeyName, lpDefault, lpFileName)
	local toReturn
	IEex_RunWithStackManager({
		{["name"] = "lpAppName",        ["struct"] = "string",        ["constructor"] = {["luaArgs"] = {lpAppName}  }},
		{["name"] = "lpKeyName",        ["struct"] = "string",        ["constructor"] = {["luaArgs"] = {lpKeyName}  }},
		{["name"] = "lpDefault",        ["struct"] = "string",        ["constructor"] = {["luaArgs"] = {lpDefault}  }},
		{["name"] = "lpReturnedString", ["struct"] = "uninitialized", ["constructor"] = {["luaArgs"] = {0x1000}     }},
		{["name"] = "lpFileName",       ["struct"] = "string",        ["constructor"] = {["luaArgs"] = {lpFileName} }}, },
		function(manager)
			local returnedString = manager:getAddress("lpReturnedString")
			IEex_Call(IEex_ReadDword(0x84730C), {
				manager:getAddress("lpFileName"),
				0x1000,
				returnedString,
				manager:getAddress("lpDefault"),
				manager:getAddress("lpKeyName"),
				manager:getAddress("lpAppName"),
			})
			toReturn = IEex_ReadString(returnedString)
		end)
	return toReturn
end

function IEex_GetResolution()
	return IEex_ReadWord(0x8BA31C, 0), IEex_ReadWord(0x8BA31E, 0)
end

-- A spell's icon resref lives in its (immutable) SPL header, so cache it. The
-- action indicators resolve this every AI tick while a party member is casting;
-- without the cache each tick did a full IEex_DemandRes (malloc + 3 IEex_Call
-- trampolines + free) and churned the SPL refcount down to 0 -> disk/BIF reload.
IEex_SpellIconResrefCache = {}
function IEex_GetSpellIconResref(spellResref)
	if spellResref == nil then return "" end
	local cached = IEex_SpellIconResrefCache[spellResref]
	if cached ~= nil then return cached end
	local spellWrapper = IEex_DemandRes(spellResref, "SPL")
	if not spellWrapper:isValid() then
		IEex_SpellIconResrefCache[spellResref] = ""
		return ""
	end
	local iconResref = IEex_ReadLString(spellWrapper:getData() + 0x3A, 8)
	spellWrapper:free()
	IEex_SpellIconResrefCache[spellResref] = iconResref
	return iconResref
end

-------------------------
-- CInfinity Functions --
-------------------------

function IEex_GetViewportRectFromCInfinity(CInfinity)
	local rViewPort = CInfinity + 0x48
	return IEex_ReadDword(rViewPort),       -- left
		   IEex_ReadDword(rViewPort + 0x4), -- top
		   IEex_ReadDword(rViewPort + 0x8), -- right
		   IEex_ReadDword(rViewPort + 0xC)  -- bottom
end

------------------------
-- Viewport Functions --
------------------------

function IEex_GetMainViewportBottom(excludeQuickloot, checkHidden)
	local _, _, _, minY = IEex_GetViewportRect()
	local worldScreen = IEex_GetEngineWorld()
	if not checkHidden or not IEex_IsEngineUIManagerHidden(worldScreen) then
		local ids = {0, 1, 7, 8, 9, 6, 17, 19, 21, 22}
		if not IEex_Vanilla and not excludeQuickloot then table.insert(ids, 23) end
		for _, panelID in ipairs(ids) do
			local panel = IEex_GetPanelFromEngine(worldScreen, panelID)
			if IEex_IsPanelActive(panel) then
				local _, y = IEex_GetPanelArea(panel)
				minY = math.min(minY, y)
			end
		end
	end
	return minY
end

function IEex_GetViewportRect()
	return IEex_GetViewportRectFromCInfinity(IEex_GetCInfinity())
end

function IEex_ResetViewport()
	local panel = IEex_GetPanelFromEngine(IEex_GetEngineWorld(), 1)
	local _, y, _, _ = IEex_GetPanelArea(panel)
	IEex_SetViewportBottom(y)
end

function IEex_SetViewportBottom(bottom)
	IEex_WriteDword(IEex_GetCInfinity() + 0x48 + 0xC, bottom)
end

----------------------
-- Engine Functions --
----------------------

function IEex_GetCHUResrefFromEngine(CBaldurEngine)
	return IEex_GetCHUResrefFromUIManager(IEex_GetUIManagerFromEngine(CBaldurEngine))
end

function IEex_GetPanelFromEngine(CBaldurEngine, panelID)
	return IEex_GetPanel(IEex_GetUIManagerFromEngine(CBaldurEngine), panelID)
end

function IEex_GetUIManagerFromEngine(CBaldurEngine)
	return CBaldurEngine + 0x30
end

function IEex_IsEngineUIManagerHidden(CBaldurEngine)
	return IEex_ReadDword(IEex_GetUIManagerFromEngine(CBaldurEngine)) == 1
end

function IEex_SetEngineScrollbarFocus(CBaldurEngine, CUIControlScrollbar)
	IEex_WriteDword(CBaldurEngine + 0xFA, CUIControlScrollbar)
end

--------------------------
-- UI Manager Functions --
--------------------------

function IEex_GetCHUResrefFromUIManager(CUIManager)
	return IEex_ReadLString(CUIManager + 0x8, 8)
end

function IEex_GetPanel(CUIManager, panelID)
	return IEex_Call(0x4D4000, {panelID}, CUIManager, 0x0)
end

function IEex_InvalidateUIManagerRect(CUIManager, l, r, t, b)
	IEex_RunWithStackManager({
		{["name"] = "rect", ["struct"] = "CRect", ["constructor"] = {["variant"] = "fill", ["luaArgs"] = {l, r, t, b} }}, },
		function(manager)
			IEex_Call(0x4D45E0, {manager:getAddress("rect")}, CUIManager, 0x0)
		end)
end

function IEex_IsUIManagerHidden(CUIManager)
	return IEex_ReadDword(CUIManager) == 1
end

---------------------
-- Panel Functions --
---------------------

function IEex_GetCHUResrefFromPanel(CUIPanel)
	return IEex_GetCHUResrefFromUIManager(IEex_GetUIManagerFromPanel(CUIPanel))
end

function IEex_GetControlFromPanel(CUIPanel, controlID)
	local foundControl = 0x0
	IEex_IterateCPtrList(CUIPanel + 0x4, function(CUIControl)
		if IEex_GetControlID(CUIControl) == controlID then
			foundControl = CUIControl
			return true
		end
	end)
	return foundControl
end

function IEex_GetPanelArea(CUIPanel)
	local x = IEex_ReadDword(CUIPanel + 0x24)
	local y = IEex_ReadDword(CUIPanel + 0x28)
	local w = IEex_ReadDword(CUIPanel + 0x34)
	local h = IEex_ReadDword(CUIPanel + 0x38)
	return x, y, w, h
end

function IEex_GetPanelBackgroundImage(CUIPanel)
	-- CUIPanel.m_mosaic.resHelper.cResRef
	return IEex_ReadLString(CUIPanel + 0x3E + 0xA0 + 0x8, 8)
end

function IEex_GetPanelID(CUIPanel)
	return IEex_ReadDword(CUIPanel + 0x20)
end

function IEex_GetUIManagerFromPanel(CUIPanel)
	return IEex_ReadDword(CUIPanel)
end

function IEex_InvalidatePanelUIManager(panel)
	IEex_InvalidateUIManagerRect(IEex_GetUIManagerFromPanel(panel), IEex_GetPanelArea(panel))
end

function IEex_IsPanelActive(CUIPanel)
	return IEex_ReadDword(CUIPanel + 0xF4) == 1
end

-- Flagged when panel is not interactable yet should still render
function IEex_IsPanelInactiveRender(CUIPanel)
	return IEex_ReadDword(CUIPanel + 0x10A) == 1
end

function IEex_IsPointOverControlID(CUIPanel, controlID, x, y)
	return IEex_IsPointOverControl(IEex_GetControlFromPanel(CUIPanel, controlID), x, y)
end

function IEex_IsPointOverPanel(CUIPanel, x, y)
	local panelX, panelY, panelW, panelH = IEex_GetPanelArea(CUIPanel)
	return x >= panelX and x <= (panelX + panelW) and y >= panelY and y <= (panelY + panelH)
end

function IEex_IteratePanelControls(CUIPanel, func)
	IEex_IterateCPtrList(CUIPanel + 0x4, func)
end

function IEex_PanelHasBackground(CUIPanel)
	return IEex_ReadDword(CUIPanel + 0xE2) ~= 0x0
end

function IEex_PanelInvalidate(CUIPanel)
	IEex_Call(0x4D3810, {0x0}, CUIPanel, 0x0)
end

function IEex_PanelInvalidateRect(CUIPanel, left, top, right, bottom)
	local rect = IEex_Malloc(0x10)
	IEex_WriteDword(rect + 0x0, left)
	IEex_WriteDword(rect + 0x4, top)
	IEex_WriteDword(rect + 0x8, right)
	IEex_WriteDword(rect + 0xC, bottom)
	IEex_Call(0x4D3810, {rect}, CUIPanel, 0x0)
	IEex_Free(rect)
end

function IEex_SetPanelActive(CUIPanel, active)
	IEex_Call(0x4D3980, {active and 1 or 0}, CUIPanel, 0x0)
end

function IEex_SetPanelArea(CUIPanel, x, y, w, h, bSetOriginal)
	IEex_SetPanelXY(CUIPanel, x, y, bSetOriginal)
	if w then IEex_WriteDword(CUIPanel + 0x34, w) end
	if h then IEex_WriteDword(CUIPanel + 0x38, h) end
end

function IEex_SetPanelEnabled(CUIPanel, enabled)
	IEex_Call(0x4D29D0, {enabled and 1 or 0}, CUIPanel, 0x0)
end

function IEex_SetPanelMosaicResref(CUIPanel, resref)
	IEex_Helper_SetPanelMosaicResref(CUIPanel, resref)
end

function IEex_SetPanelXY(CUIPanel, x, y, bSetOriginal)
	if x then
		IEex_WriteDword(CUIPanel + 0x24, x)
		if bSetOriginal then IEex_WriteDword(CUIPanel + 0x2C, x) end
	end
	if y then
		IEex_WriteDword(CUIPanel + 0x28, y)
		if bSetOriginal then IEex_WriteDword(CUIPanel + 0x30, y) end
	end
end

----------------------------
-- Control Base Functions --
----------------------------

function IEex_GetControlArea(CUIControl)
	local x = IEex_ReadDword(CUIControl + 0xE)
	local y = IEex_ReadDword(CUIControl + 0x12)
	local w = IEex_ReadDword(CUIControl + 0x16)
	local h = IEex_ReadDword(CUIControl + 0x1A)
	return x, y, w, h
end

function IEex_GetControlAreaAbsolute(CUIControl)
	local panelX, panelY, _, _ = IEex_GetPanelArea(IEex_GetControlPanel(CUIControl))
	local controlX, controlY, controlW, controlH = IEex_GetControlArea(CUIControl)
	return panelX + controlX, panelY + controlY, controlW, controlH
end

function IEex_GetControlID(CUIControl)
	return IEex_ReadDword(CUIControl + 0xA)
end

function IEex_GetControlPanel(CUIControl)
	return IEex_ReadDword(CUIControl + 0x6)
end

function IEex_IsControlActive(CUIControl)
	return IEex_ReadByte(CUIControl + 0x1E) ~= 0
end

function IEex_IsControlActiveForRender(CUIControl)
	return IEex_IsControlActive(CUIControl) or IEex_IsControlInactiveRender(CUIControl)
end

function IEex_IsControlInactiveRender(CUIControl)
	return IEex_ReadDword(CUIControl + 0x32) ~= 0
end

function IEex_IsControlOnPanel(CUIControl, CUIPanel)
	return IEex_GetControlPanel(CUIControl) == CUIPanel
end

function IEex_IsPointOverControl(CUIControl, x, y)
	local controlX, controlY, controlW, controlH = IEex_GetControlAreaAbsolute(CUIControl)
	return x >= controlX and x <= (controlX + controlW) and y >= controlY and y <= (controlY + controlH)
end

function IEex_SetControlActive(CUIControl, active)
	IEex_WriteByte(CUIControl + 0x1E, active and 1 or 0)
end

function IEex_SetControlArea(CUIControl, x, y, w, h)
	if x then IEex_WriteDword(CUIControl + 0xE, x) end
	if y then IEex_WriteDword(CUIControl + 0x12, y) end
	if w then IEex_WriteDword(CUIControl + 0x16, w) end
	if h then IEex_WriteDword(CUIControl + 0x1A, h) end
end

function IEex_SetControlCustomHotkeyHintIndex(CUIControl, customMapIndex)
	-- IEexHelper's reimplementation of the hotkey hint formatting routine uses
	-- flag 0x8000 to differentiate between the engine's hardcoded hotkeys and
	-- our custom ones.
	IEex_SetControlHotkeyHintIndex(CUIControl, bit.bor(customMapIndex, 0x8000))
end

function IEex_SetControlHotkeyHintIndex(CUIControl, hotkeyIndex)
	IEex_WriteWord(CUIControl + 0x4A, hotkeyIndex)
end

function IEex_SetControlInactiveRender(CUIControl, inactiveRender)
	IEex_WriteDword(CUIControl + 0x32, inactiveRender and 1 or 0)
end

function IEex_SetControlXY(CUIControl, x, y)
	-- HD UI (2x): every caller passes 1x-authored coords -- these nudge VANILLA controls aside to make
	-- room for IEex additions (e.g. moving the "Return"/"Level Up" buttons). SetControlXY writes m_ptOrigin
	-- DIRECTLY, bypassing the ctor doubling, so the coord must always be in the 2x layout space -- and the
	-- layout is 2x EITHER via a pre-scaled CHU (most menus) OR engine doubling (the inventory-class screens
	-- GUIINV/GUIREC/GUISTORE/GUICG, forced bDoubleSize=TRUE). So always scale x2 when HD, regardless of the
	-- manager's double-size flag. (All callers pass 1x hardcoded coords -- 655/361, 612/338, 0/0 -- so this
	-- never double-scales an already-2x value.)
	if IEEX_HD_UI then
		if x then x = x * 2 end
		if y then y = y * 2 end
	end
	if x then IEex_WriteDword(CUIControl + 0xE, x) end
	if y then IEex_WriteDword(CUIControl + 0x12, y) end
end

------------------------------
-- Control Button Functions --
------------------------------

function IEex_GetControlButtonBAM(CUIControlButton)
	-- CUIControlButton.m_vidCellButton.resHelper.cResRef
	return IEex_ReadLString(CUIControlButton + 0x52 + 0xA4 + 0x8, 8)
end

function IEex_GetControlButtonFrameDown(CUIControlButton)
	return IEex_ReadWord(CUIControlButton + 0x12E)
end

function IEex_GetControlButtonFrameUp(CUIControlButton)
	return IEex_ReadWord(CUIControlButton + 0x12C)
end

function IEex_GetControlButtonPendingRenderCount(CUIControlButton)
	return IEex_ReadWord(CUIControlButton + 0x132)
end

function IEex_SetControlButtonFrame(CUIControlButton, frame)
	IEex_WriteWord(CUIControlButton + 0x116, frame)
end

function IEex_SetControlButtonFrameDown(CUIControlButton, frame)
	IEex_WriteWord(CUIControlButton + 0x12E, frame)
end

function IEex_SetControlButtonFrameUp(CUIControlButton, frame)
	IEex_WriteWord(CUIControlButton + 0x12C, frame)
end

function IEex_SetControlButtonFrameUpForce(CUIControlButton, frame)
	IEex_SetControlButtonFrameUp(CUIControlButton, frame)
	IEex_SetControlButtonFrame(CUIControlButton, frame)
end

-- m_cVidCell.m_nCurrentSequence (0x52 + 0xC6). The button's BAM cycle: frame indices
-- (normal/pressed/disabled) are resolved WITHIN this cycle via the BAM lookup table
-- (CVidCell::GetFrame), and out-of-range indices clamp to the cycle's last frame.
function IEex_SetControlButtonSequence(CUIControlButton, sequence)
	IEex_WriteWord(CUIControlButton + 0x118, sequence)
end

function IEex_SetControlButtonPendingRenderCount(CUIControlButton, newCount)
	return IEex_WriteWord(CUIControlButton + 0x132, newCount)
end

function IEex_SetControlButtonPlayLButtonDownSound(CUIControlButton, bPlayLButtonDownSound)
	return IEex_WriteDword(CUIControlButton + 0x662, bPlayLButtonDownSound and 1 or 0)
end

function IEex_SetControlButtonText(CUIControlButton, text)

	local manager = IEex_NewMemoryManager({
		{
			["name"] = "varChars",
			["struct"] = "string",
			["constructor"] = {
				["luaArgs"] = {text},
			},
		},
		{
			["name"] = "varString",
			["struct"] = "CString",
			["constructor"] = {
				["variant"] = "fromString",
				["args"] = {"varChars"},
			},
		},
	})

	IEex_Call(0x4D58A0, {manager:getAddress("varString")}, CUIControlButton, 0x0)
	manager:free()
end

function IEex_ShouldControlButtonRender(CUIControlButton, bForceRender)
	return IEex_GetControlButtonPendingRenderCount(CUIControlButton) ~= 0 or bForceRender ~= 0
end

-----------------------------
-- Control Label Functions --
-----------------------------

function IEex_GetControlLabelTextFlags(CUIControlLabel)
	return IEex_ReadWord(CUIControlLabel + 0x55A)
end

function IEex_SetControlLabelText(CUIControlLabel, text)

	local manager = IEex_NewMemoryManager({
		{
			["name"] = "varChars",
			["struct"] = "string",
			["constructor"] = {
				["luaArgs"] = {text},
			},
		},
		{
			["name"] = "varString",
			["struct"] = "CString",
			["constructor"] = {
				["variant"] = "fromString",
				["args"] = {"varChars"},
			},
		},
	})

	IEex_Call(0x4E46F0, {manager:getAddress("varString")}, CUIControlLabel, 0x0)
	manager:free()
end

function IEex_SetControlLabelTextFlags(CUIControlLabel, flags)
	IEex_WriteWord(CUIControlLabel + 0x55A, flags)
end

---------------------------------------------------
-- Control Button Mage Spell Info Icon Functions --
---------------------------------------------------

function IEex_SetControlButtonMageSpellInfoIcon(CUIControlButtonMageSpellInfoIcon, resref)
	IEex_RunWithStackManager({
		{["name"] = "resref",  ["struct"] = "CResRef", ["constructor"] = {["luaArgs"] = {resref}  }}, },
		function(manager)
			IEex_Call(0x66E500, {manager:getAddress("resref")}, CUIControlButtonMageSpellInfoIcon, 0x0)
		end)
end

--------------------------------
-- /START Container Functions --
--------------------------------

function IEex_GetContainerIDNumItems(containerID)
	local share = IEex_GetActorShare(containerID)
	local toReturn = IEex_GetContainerNumItems(share)
	IEex_UndoActorShare(containerID)
	return toReturn
end

function IEex_GetContainerIDType(containerID)
	local share = IEex_GetActorShare(containerID)
	local toReturn = IEex_GetContainerType(share)
	IEex_UndoActorShare(containerID)
	return toReturn
end

-- Returns the CItem in the container's slot, 0x0 when the slot is empty or the id is stale.
function IEex_GetContainerIDItem(containerID, slotIndex)
	local share = IEex_GetActorShare(containerID)
	if share == 0x0 then return 0x0 end
	-- CGameContainer::GetItem()
	local toReturn = IEex_Call(0x4802B0, {slotIndex}, share, 0x0)
	IEex_UndoActorShare(containerID)
	return toReturn
end

function IEex_GetContainerNumItems(CGameContainer)
	return IEex_ReadDword(CGameContainer + 0x5AE + 0xC)
end

function IEex_GetContainerType(CGameContainer)
	return IEex_ReadWord(CGameContainer + 0x5CA, 0)
end

function IEex_GetGroundPilesAroundActor(actorID)

	local toReturn = {}
	local panic = false

	local share = IEex_GetActorShare(actorID)
	local area = nil

	if share ~= 0x0 then
		area = IEex_ReadDword(share + 0x12)
		if area == 0x0 then
			panic = true
		end
	else
		panic = true
	end

	if panic then
		-- Actor is invalid, panic and use the area's AI runner just to have a valid object
		actorID = IEex_ReadDword(IEex_GetVisibleArea() + 0x41A) -- m_nAIIndex
		share = IEex_GetActorShare(actorID)
		area = IEex_ReadDword(share + 0x12)
	end

	local actorX, actorY = IEex_GetActorLocation(actorID)
	local m_lVertSortBack = area + 0x9AE

	local defaultContainerID = -1

	if not panic then

		IEex_IterateCPtrList(m_lVertSortBack, function(containerID)

			local containerShare = IEex_GetActorShare(containerID)
			if containerShare == 0x0 then return end
			if IEex_ReadByte(containerShare + 0x4, 0) ~= 0x11 then return end

			defaultContainerID = containerID

			if IEex_GetContainerType(containerShare) ~= 4 then return end -- Only ground piles
			if not IEex_CheckActorLOSObject(actorID, containerID) then return end
			if IEex_GetContainerNumItems(containerShare) <= 0 then return end

			local containerX, containerY = IEex_GetActorLocation(containerID)
			local distance = IEex_GetDistanceIsometric(actorX, actorY, containerX, containerY)
			table.insert(toReturn, {["containerID"] = containerID, ["distance"] = distance})
		end)

		table.sort(toReturn, function(a, b)
			return a.distance < b.distance
		end)
	else
		IEex_IterateCPtrList(m_lVertSortBack, function(containerID)

			local containerShare = IEex_GetActorShare(containerID)
			if containerShare == 0x0 then return end
			if IEex_ReadByte(containerShare + 0x4, 0) ~= 0x11 then return end

			defaultContainerID = containerID
			return true -- break loop
		end)
	end

	if defaultContainerID == -1 then
		defaultContainerID = IEex_Call(0x5B75C0, {actorID}, IEex_GetGameData(), 0x0)
	end

	toReturn.defaultContainerID = defaultContainerID
	return toReturn
end

------------------------------
-- /END Container Functions --
------------------------------

function IEex_MapCHU(chuWrapper)

	local chuData = chuWrapper:getData()

	local panelIDToAddress = {}
	local panelIDToControlIDToAddress = {}

	local curPanelAddress = chuData + IEex_ReadDword(chuData + 0x10)
	local numPanels = IEex_ReadDword(chuData + 0x8)

	for i = 1, numPanels do

		local panelID = IEex_ReadWord(curPanelAddress, 0)
		panelIDToAddress[panelID] = curPanelAddress

		local controlIDToAddress = {}
		panelIDToControlIDToAddress[panelID] = controlIDToAddress

		local firstControlIndex = IEex_ReadWord(curPanelAddress + 0x18)
		local currentListingIndex = chuData + IEex_ReadDword(chuData + 0xC) + (firstControlIndex * 0x8)
		local numControls = IEex_ReadWord(curPanelAddress + 0xE)

		for j = 1, numControls do
			local currentControlAddress = chuData + IEex_ReadDword(currentListingIndex)
			local controlID = IEex_ReadWord(currentControlAddress)
			controlIDToAddress[controlID] = currentControlAddress
			currentListingIndex = currentListingIndex + 0x8
		end

		curPanelAddress = curPanelAddress + 0x1C
	end

	chuWrapper.getPanel = function(panelID)
		return panelIDToAddress[panelID]
	end

	chuWrapper.getControl = function(panelID, controlID)
		return (panelIDToControlIDToAddress[panelID] or {})[controlID]
	end
end

-----------------------
-- General Variables --
-----------------------

IEex_WorldScreenSpellInfoPanelID = 50
IEex_WorldScreenItemInfoPanelID = 51
IEex_ActionIndicatorsPanelID = 100
-- World-HUD refonte (PoE/BG2EE-style floating HUD): portrait busts bottom-right, bars
-- bottom-centre, resizable log bottom-left. WeiDU-MANAGED: the core ships false; the
-- "World HUD Refonte" component (DESIGNATED 103) flips it true (REPLACE_TEXTUALLY, same
-- pattern as IEEX_HD_UI). Runtime requirements enforced in IEex_InstallPortraitGrid:
-- OpenGL renderer + GUIW10 (the installer flips this back off when unmet).
IEex_PortraitGridEnabled = false

-- Whether the "Colored portrait frames" options row (label 23) exists: that option is drawn by
-- the RenderPortrait override, which only the refonte installs. Captured HERE, at load, for two
-- independent reasons:
--   * NOT read live, because IEex_InstallPortraitGrid's runtime veto (software renderer /
--     non-GUIW10) flips IEex_PortraitGridEnabled false at GAME LOAD -- after the panel was built,
--     and before later opens. The hook bytes are written by then and the override's DrawLine
--     fallback covers software, so the option keeps working; only the flag would lie.
--   * In a STATE file, because IEex_OptionRowVisible is called from BOTH threads: the row is
--     built on Sync (CHU init) but IEex_InitOptionButtons runs on Async (the options button
--     click, IEex_Extern_UI_ButtonLClick). A patch-file global exists in only one of those
--     states, so the row built correctly and then its toggle silently kept the CHU default
--     frame -- the checkbox read "off" while the bridge said on, so the first click only wrote
--     "off" again and it took a second click to light up. Same reason IEEX_GL_ACTIVE lives here.
IEEX_PORTRAIT_FRAMES_AVAILABLE = IEex_PortraitGridEnabled

IEex_AllWorldScreenPanelIDs = {0, 1, 7, 8, 9, 6, 17, 19, 21, 22}
if not IEex_Vanilla then
	table.insert(IEex_AllWorldScreenPanelIDs, 23) -- Quickloot
	table.insert(IEex_AllWorldScreenPanelIDs, IEex_WorldScreenSpellInfoPanelID)
	table.insert(IEex_AllWorldScreenPanelIDs, IEex_WorldScreenItemInfoPanelID)
	table.insert(IEex_AllWorldScreenPanelIDs, IEex_ActionIndicatorsPanelID)
end

IEex_Helper_InitBridgeFromTable("IEex_ActionIndicators", {
	[0] = { [0] = nil, [1] = nil, [2] = nil },
	[1] = { [0] = nil, [1] = nil, [2] = nil	},
	[2] = { [0] = nil, [1] = nil, [2] = nil	},
	[3] = { [0] = nil, [1] = nil, [2] = nil },
	[4] = { [0] = nil, [1] = nil, [2] = nil },
	[5] = { [0] = nil, [1] = nil, [2] = nil },
	-- Bumped (async) whenever any portrait's icons / control-active flags are
	-- re-resolved; the sync thread repaints panel 100 in the HUD layer only when
	-- this moves (a counter, not a clearable flag: sync never writes it, so an
	-- async bump can't be lost to a read-then-clear race).
	["updateCounter"] = 0,
})

IEex_ActionIndicators_PanelHeight = 31

IEex_ActionIndicators_PrimarySlotSize = 30
IEex_ActionIndicators_PrimarySlotOffsetX = 46 - IEex_ActionIndicators_PrimarySlotSize
IEex_ActionIndicators_PrimarySlotOffsetY = -IEex_ActionIndicators_PrimarySlotSize
IEex_ActionIndicators_PrimarySlotInset = 3
IEex_ActionIndicators_PrimarySlotDimension = IEex_ActionIndicators_PrimarySlotSize - 2 * IEex_ActionIndicators_PrimarySlotInset

IEex_ActionIndicators_SecondarySlotSize = 16
IEex_ActionIndicators_SecondarySlotOffsetX = 0
IEex_ActionIndicators_SecondarySlotOffsetY = -IEex_ActionIndicators_SecondarySlotSize

IEex_ActionIndicators_TertiarySlotSize = 16
IEex_ActionIndicators_TertiarySlotOffsetX = 0
IEex_ActionIndicators_TertiarySlotOffsetY = IEex_ActionIndicators_SecondarySlotOffsetY - IEex_ActionIndicators_TertiarySlotSize

IEex_ActionIndicators_PreviousIconsBuffer = {
	[0] = {}, [1] = {}, [2] = {},
	[3] = {}, [4] = {}, [5] = {},
}
IEex_ActionIndicators_PreviousIconsBufferSize = 2
IEex_ActionIndicators_MovementDelay = 2

-- Sync-thread trackers for the HUD layer's event-driven repaint of the live
-- panels (see IEex_Extern_BeforeWorldRender): last seen game tick (panel 1)
-- and last consumed IEex_ActionIndicators updateCounter (panel 100).
IEex_HudLayer_LastGameTime = -1
IEex_HudLayer_LastIndicatorsCounter = -1

IEex_NewScope(function()
	for i = 0, 5 do
		local buffer = IEex_ActionIndicators_PreviousIconsBuffer[i]
		buffer.movementDelayCounter = 0
		buffer.lastSig = nil    -- signature of the last resolved tick (dirty check)
		buffer.settleTicks = 0  -- forced full passes remaining after a change
		for j = 1, IEex_ActionIndicators_PreviousIconsBufferSize do
			buffer[j] = {}
		end
	end
end)

--------------------------------
-- Action Indicator Functions --
--------------------------------

function IEex_ActionIndicators_Show()
	local panel = IEex_ActionIndicators_GetPanel()
	if panel == 0 then return end
	IEex_SetPanelActive(panel, true)
end

function IEex_ActionIndicators_Hide()
	local panel = IEex_ActionIndicators_GetPanel()
	if panel == 0 then return end
	IEex_SetPanelActive(panel, false)
end

function IEex_ActionIndicators_GetPanel()
	-- No world engine on the main menu (options "Done" can call Hide from there):
	-- GetEngineWorld() reads 0, so GetPanelFromEngine(0, ...) would deref ~null
	-- (UI manager = engine+0x30) and AV with 0xC0000005. Bail out safely instead.
	local world = IEex_GetEngineWorld()
	if world == 0 then return 0 end
	return IEex_GetPanelFromEngine(world, IEex_ActionIndicatorsPanelID)
end

function IEex_ActionIndicators_GetCursorIndexIcons(cursorIndex)
	-- cursorIndex ==  0 -> AR6051, stones
	-- cursorIndex ==  2 -> AR1200, shield watched by soldier
	-- cursorIndex ==  8 -> AR2001, gate mechanism
	-- cursorIndex == 12 -> AR2000, logs
	-- cursorIndex == 20 -> AR6201, magic barrier
	-- cursorIndex == 22 -> AR3000, fortress main gate
	-- cursorIndex == 28 -> AR5100, pit
	-- cursorIndex == 32 -> AR6003, hidden container
	-- cursorIndex == 34 -> AR6001, unknown condition
	return {
		{"STONSLOT", 0, 0},
		{"B3INDCUR", cursorIndex + 1, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
	}
end

function IEex_ActionIndicators_GetAction(sprite)

	local action = IEex_GetObjectCurrentAction(sprite)
	local actionID = IEex_GetSpriteRealCurrentActionID(sprite)

	-- MoveToPoint, SmallWait
	if actionID == 23 or actionID == 83 then
		-- Hack to detect player-issued ProtectPoint
		local pendingActionNode = IEex_ReadDword(sprite + 0x416)
		if pendingActionNode ~= 0x0 then
			action = IEex_ReadDword(pendingActionNode + 0x8)
			actionID = IEex_GetActionID(action)
		end
	end

	return action, actionID
end

function IEex_ActionIndicators_GetPrimaryIcons(sprite, action, actionID)

	-- Spell, SpellPoint, ForceSpell, ForceSpellPoint, SpellNoDec, SpellPointNoDec
	if IEex_IsActionIDSpellCast(actionID) then

		local spellResref = IEex_GetObjectSpellRES(sprite)
		if spellResref == nil then return end

		if spellResref == "SPIN108" then
			 -- Animal Empathy
			return {{"GUIBTACT", 0, 124}}
		end

		return {
			{"STONSLOT", 0, 0},
			{IEex_GetSpellIconResref(spellResref), 0, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}

	-- UseItem, UseItemPoint
	elseif IEex_IsActionIDItemUse(actionID) then

		local slotNum, item, abilityNum = IEex_Helper_GetUseItemFields(sprite)
		if slotNum == nil then return end

		-- Read item ability icon
		if item ~= 0x0 then
			IEex_SafeDemandCItem(item)
			local ability = IEex_GetCItemAbilityNum(item, abilityNum)
			if ability == 0x0 then
				IEex_SafeUndemandCItem(item)
				return
			end
			local abilityIcon = IEex_ReadLString(ability + 0x4, 8)
			IEex_SafeUndemandCItem(item)
			return {
				{"STONSLOT", 0, 0},
				{abilityIcon, 1, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
			}
		end

		return

	-- Attack, GroupAttack, AttackNoSound, AttackOneRound, AttackReevaluate
	elseif IEex_IsActionIDAttack(actionID) then

		local slotNum, item, abilityNum, launcherSlotNum, launcherItem = IEex_Helper_GetAttackItemFields(sprite)
		if slotNum == nil then return end

		local toReturn = {{"STONSLOT", 0, 0}}

		-- Read launcher item ability icon
		if launcherItem ~= 0x0 then
			IEex_SafeDemandCItem(launcherItem)
			local launcherAbility = IEex_GetCItemAbilityNum(launcherItem, 0)
			if launcherAbility ~= 0x0 then
				local launcherAbilityIcon = IEex_ReadLString(launcherAbility + 0x4, 8)
				table.insert(toReturn, {launcherAbilityIcon, 1, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension})
			end
			IEex_SafeUndemandCItem(launcherItem)
		end

		-- Read item ability icon
		if item ~= 0x0 then
			IEex_SafeDemandCItem(item)
			local ability = IEex_GetCItemAbilityNum(item, abilityNum)
			if ability ~= 0x0 then
				local abilityIcon = IEex_ReadLString(ability + 0x4, 8)
				table.insert(toReturn, {abilityIcon, 1, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension})
			end
			IEex_SafeUndemandCItem(item)
		end

		return toReturn

	-- PickPockets
	elseif actionID == 25 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 41, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	-- ProtectPoint
	elseif actionID == 27 then

		return {{"GUIBTACT", 0, 0}}

	-- RemoveTraps
	elseif actionID == 28 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 39, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	-- LeaveArea
	elseif actionID == 91 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 35, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	-- LeaveAreaName
	elseif actionID == 93 then

		local targetID = IEex_GetActionInt1(action)
		local targetShare = IEex_GetActorShare(targetID)
		if targetShare == 0x0 then return end
		local cursorIndex = IEex_ReadDword(targetShare + 0x5AA)
		return IEex_ActionIndicators_GetCursorIndexIcons(cursorIndex)

	-- UseContainer
	elseif actionID == 112 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 3, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	-- PlayerDialog
	elseif actionID == 139 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 19, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	-- OpenDoor
	elseif actionID == 142 then

		local targetID = IEex_GetActionInt1(action)
		local targetShare = IEex_GetActorShare(targetID)
		if targetShare == 0x0 then return end
		local cursorIndex = IEex_ReadDword(targetShare + 0x5C0)
		return IEex_ActionIndicators_GetCursorIndexIcons(cursorIndex)

	-- PickLock
	elseif actionID == 145 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 25, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	-- BashDoor
	elseif actionID == 148 then
		return {
			{"STONSLOT", 0, 0},
			{"B3INDCUR", 13, 0, IEex_ActionIndicators_PrimarySlotDimension, IEex_ActionIndicators_PrimarySlotDimension},
		}
	end
end

function IEex_ActionIndicators_GetSecondaryIcons(sprite, action, actionID, ignoreMovement)

	local modalState = IEex_GetSpriteModalState(sprite)
	local hasModalStateToDisplay = modalState == 1 or modalState == 2 or modalState == 3
	local hasMoveActionToDisplay = not ignoreMovement and (actionID == 23 or actionID == 84)

	if hasModalStateToDisplay then
		if modalState == 1 then -- BATTLE_SONG
			local bardSongResref = IEex_BardSongIndexToResref(IEex_GetSpriteCurrentBardSongIndex(sprite))
			local bardSongIcon = IEex_GetSpellIconResref(bardSongResref)
			return {
				{"GUIBTBUT", 0, 0, IEex_ActionIndicators_TertiarySlotSize, IEex_ActionIndicators_TertiarySlotSize},
				{bardSongIcon, 0, 0, IEex_ActionIndicators_SecondarySlotSize - 2, IEex_ActionIndicators_SecondarySlotSize - 2},
			}
		elseif modalState == 2 then -- SEARCH
			return {{"GUIBTACT", 0, 36, IEex_ActionIndicators_SecondarySlotSize, IEex_ActionIndicators_SecondarySlotSize}}
		elseif modalState == 3 then -- STEALTH
			return {{"GUIBTACT", 0, 28, IEex_ActionIndicators_SecondarySlotSize, IEex_ActionIndicators_SecondarySlotSize}}
		end
	end

	-- MoveToPoint, Face
	if hasMoveActionToDisplay then
		return {
			{"GUIBTBUT", 0, 0, IEex_ActionIndicators_SecondarySlotSize, IEex_ActionIndicators_SecondarySlotSize},
			{"B3MOVE", 0, 0, IEex_ActionIndicators_SecondarySlotSize - 5, IEex_ActionIndicators_SecondarySlotSize - 5},
		}
	end
end

function IEex_ActionIndicators_GetTertiaryIcons(sprite, action, actionID)

	local modalState = IEex_GetSpriteModalState(sprite)
	local hasModalStateToDisplay = modalState == 1 or modalState == 2 or modalState == 3
	local hasMoveActionToDisplay = actionID == 23 or actionID == 84

	if hasModalStateToDisplay and hasMoveActionToDisplay then
		return {
			{"GUIBTBUT", 0, 0, IEex_ActionIndicators_TertiarySlotSize, IEex_ActionIndicators_TertiarySlotSize},
			{"B3MOVE", 0, 0, IEex_ActionIndicators_TertiarySlotSize - 5, IEex_ActionIndicators_TertiarySlotSize - 5},
		}
	end
end

-- Thread: Async
function IEex_ActionIndicators_Update()

	-- Feature disabled -> skip all per-tick work. This runs on the AI thread every
	-- tick (~30 Hz); it previously ran unconditionally (the option only Show/Hid
	-- the panel), re-demanding SPL/CItem resources and re-marshalling the bridge
	-- for all 6 portraits, so the stall throttled game-logic cadence.
	if not IEex_Helper_GetBridge("IEex_Options", "options", "actionIndicators") then
		return
	end

	local anyUpdated = false

	for portraitI = 0, 5 do

		local sprite = IEex_GetActorShare(IEex_GetActorIDPortrait(portraitI))
		local previousIconsBuffer = IEex_ActionIndicators_PreviousIconsBuffer[portraitI]

		-- Cheap signature of every input that determines this portrait's icons
		-- (all raw memory reads, no IEex_Call trampolines). While it holds steady
		-- the resolved icons, bridge data and control-active flags are already
		-- correct, so the whole body below can be skipped -- avoiding the expensive
		-- per-tick SPL/CItem demands while casting/attacking and the DeepCopy +
		-- 3x SetBridge marshal while walking. movementDelayCounter is part of the
		-- signature so the 2-tick move-reveal ramp still animates; settleTicks
		-- forces a few full passes after any change so the previous-icons buffer
		-- still drains exactly as before.
		local sig
		if IEex_IsObjectSprite(sprite) then
			local sigAction, sigActionID = IEex_ActionIndicators_GetAction(sprite)
			local sigModalState = IEex_GetSpriteModalState(sprite)
			local sigBardSong = (sigModalState == 1) and IEex_GetSpriteCurrentBardSongIndex(sprite) or 0
			sig = sprite .. "|" .. (sigActionID or 0) .. "|" .. (sigAction or 0) .. "|" .. sigModalState
				.. "|" .. (IEex_GetObjectSpellRES(sprite) or "") .. "|" .. sigBardSong
				.. "|" .. previousIconsBuffer.movementDelayCounter
		else
			sig = "x"
		end

		if sig ~= previousIconsBuffer.lastSig then
			previousIconsBuffer.lastSig = sig
			previousIconsBuffer.settleTicks = IEex_ActionIndicators_PreviousIconsBufferSize + 1
		end

		if previousIconsBuffer.settleTicks > 0 then

			previousIconsBuffer.settleTicks = previousIconsBuffer.settleTicks - 1

			local primaryIcons = nil
			local secondaryIcons = nil
			local tertiaryIcons = nil

			local storeIcons = false

			if IEex_IsObjectSprite(sprite) then

				local action, actionID = IEex_ActionIndicators_GetAction(sprite)
				local noMovementDelay = actionID ~= 23 and actionID ~= 84

				-- Reset the movement delay when a non-movement action is started
				if actionID ~= 0 and noMovementDelay then
					previousIconsBuffer.movementDelayCounter = 0
				end

				-- Slightly delay showing movement actions to prevent flicker on certain player-issued actions
				if not noMovementDelay then
					local delayCount = previousIconsBuffer.movementDelayCounter
					if delayCount < IEex_ActionIndicators_MovementDelay then
						previousIconsBuffer.movementDelayCounter = delayCount + 1
					else
						noMovementDelay = true
					end
				end

				if actionID ~= 0 and noMovementDelay then
					-- Use the action as is
					primaryIcons = IEex_ActionIndicators_GetPrimaryIcons(sprite, action, actionID)
					secondaryIcons = IEex_ActionIndicators_GetSecondaryIcons(sprite, action, actionID)
					tertiaryIcons = IEex_ActionIndicators_GetTertiaryIcons(sprite, action, actionID)
					storeIcons = true
				else
					-- Attempt to use previous icons
					local previousIcons = nil
					for i = 1, IEex_ActionIndicators_PreviousIconsBufferSize do
						local previousIconsTemp = previousIconsBuffer[i]
						if previousIconsTemp.valid then
							previousIcons = previousIconsTemp
							break
						end
					end

					if previousIcons ~= nil then
						primaryIcons = previousIcons[1]
						secondaryIcons = IEex_ActionIndicators_GetSecondaryIcons(sprite, action, actionID, true) or previousIcons[2]
						tertiaryIcons = previousIcons[3]
						storeIcons = not noMovementDelay
					else
						primaryIcons = nil
						secondaryIcons = IEex_ActionIndicators_GetSecondaryIcons(sprite, action, actionID)
						tertiaryIcons = nil
					end
				end
			end

			-- Advance the buffers
			for i = IEex_ActionIndicators_PreviousIconsBufferSize, 2, -1 do
				previousIconsBuffer[i] = IEex_Helper_DeepCopy(previousIconsBuffer[i - 1])
			end

			-- Store the resolved icons (or a dummy entry if no icons were resolved)
			local previousIcons = previousIconsBuffer[1]
			if storeIcons then
				previousIcons.valid = true
				previousIcons[1] = primaryIcons
				previousIcons[2] = secondaryIcons
				previousIcons[3] = tertiaryIcons
			else
				previousIcons.valid = false
				previousIcons[1] = nil
				previousIcons[2] = nil
				previousIcons[3] = nil
			end

			local portraitBridge = IEex_Helper_GetBridge("IEex_ActionIndicators", portraitI)
			IEex_Helper_SetBridge(portraitBridge, 0, primaryIcons)
			IEex_Helper_SetBridge(portraitBridge, 1, secondaryIcons)
			IEex_Helper_SetBridge(portraitBridge, 2, tertiaryIcons)

			local actionIndicatorsPanel = IEex_ActionIndicators_GetPanel()
			IEex_SetControlActive(IEex_GetControlFromPanel(actionIndicatorsPanel, portraitI * 3    ), primaryIcons   ~= nil and #primaryIcons   > 0)
			IEex_SetControlActive(IEex_GetControlFromPanel(actionIndicatorsPanel, portraitI * 3 + 1), secondaryIcons ~= nil and #secondaryIcons > 0)
			IEex_SetControlActive(IEex_GetControlFromPanel(actionIndicatorsPanel, portraitI * 3 + 2), tertiaryIcons  ~= nil and #tertiaryIcons  > 0)

			anyUpdated = true
		end
	end

	-- Icons / active flags can only have changed inside a settle window above;
	-- signal the sync thread to repaint panel 100 in the HUD layer.
	if anyUpdated then
		IEex_Helper_SetBridge("IEex_ActionIndicators", "updateCounter",
			(IEex_Helper_GetBridge("IEex_ActionIndicators", "updateCounter") or 0) + 1)
	end
end

-------------------------
-- Quickloot Functions --
-------------------------

IEex_Helper_InitBridgeFromTable("IEex_Quickloot", {
	["on"] = false,
	["itemsAccessIndex"] = 1,
	["pendingItemsAccessChange"] = 0,
	["pendingItemsAccessChangeDelayCounter"] = 0,
	["highlightContainerID"] = -1,
	["oldActorX"] = nil,
	["oldActorY"] = nil,
})

function IEex_Quickloot_Start()
	IEex_Helper_SetBridge("IEex_Quickloot", "on", true)
end

function IEex_Quickloot_Stop()
	IEex_Helper_SetBridge("IEex_Quickloot", "on", false)
	IEex_Quickloot_Hide()
end

function IEex_Quickloot_Show()
	local panel = IEex_Quickloot_GetPanel()
	IEex_SetPanelActive(panel, true)
end

function IEex_Quickloot_Hide()
	local panel = IEex_Quickloot_GetPanel()
	IEex_SetPanelActive(panel, false)
end

function IEex_Quickloot_UpdateItems(alreadyLocked)

	local doUpdate = function()

		local items = IEex_Helper_GetBridgeCreateNL("IEex_Quickloot", "items")
		IEex_Helper_ClearBridgeNL(items)

		-- Build IEex_Quickloot
		local actorID = IEex_Quickloot_GetValidPartyMember()
		local piles = IEex_GetGroundPilesAroundActor(actorID)

		IEex_Helper_SetBridgeNL("IEex_Quickloot", "defaultContainerID", piles.defaultContainerID)

		for _, pile in ipairs(piles) do
			local maxIndex = IEex_GetContainerIDNumItems(pile.containerID) - 1
			for i = 0, maxIndex, 1 do
				local newEntry = IEex_AppendBridgeTable(items)
				IEex_Helper_SetBridgeNL(newEntry, "containerID", pile.containerID)
				IEex_Helper_SetBridgeNL(newEntry, "slotIndex", i)
			end
		end

		-- If actor moved, force list back to start
		local actorX, actorY = IEex_GetActorLocation(actorID)
		local oldX = IEex_Helper_GetBridgeNL("IEex_Quickloot", "oldActorX")
		local oldY = IEex_Helper_GetBridgeNL("IEex_Quickloot", "oldActorY")

		-- Fixes weird flicker when performing right-side adjustment; unknown why this occurs
		-- without a 2 tick delay on itemsAccessIndex modification when picking up an item.
		local pendingItemsAccessChange = IEex_Helper_GetBridgeNL("IEex_Quickloot", "pendingItemsAccessChange")
		if pendingItemsAccessChange ~= 0 then
			local pendingItemsAccessChangeDelayCounter = IEex_Helper_GetBridgeNL("IEex_Quickloot", "pendingItemsAccessChangeDelayCounter") + 1
			if pendingItemsAccessChangeDelayCounter == 2 then
				IEex_Helper_SetBridgeNL("IEex_Quickloot", "pendingItemsAccessChange", 0)
				IEex_Helper_SetBridgeNL("IEex_Quickloot", "pendingItemsAccessChangeDelayCounter", 0)
				local newItemsAccessIndex = IEex_Helper_GetBridgeNL("IEex_Quickloot", "itemsAccessIndex") + pendingItemsAccessChange
				local maxIndex = math.max(1, IEex_Helper_GetBridgeNumIntsNL("IEex_Quickloot", "items") - 10 + 1)
				IEex_Helper_SetBridgeNL("IEex_Quickloot", "itemsAccessIndex", math.max(1, math.min(newItemsAccessIndex, maxIndex)))
			else
				IEex_Helper_SetBridgeNL("IEex_Quickloot", "pendingItemsAccessChangeDelayCounter", pendingItemsAccessChangeDelayCounter)
			end
		end

		if actorX ~= oldX or actorY ~= oldY then
			IEex_Helper_SetBridgeNL("IEex_Quickloot", "itemsAccessIndex", 1)
		end

		IEex_Helper_SetBridgeNL("IEex_Quickloot", "oldActorX", actorX)
		IEex_Helper_SetBridgeNL("IEex_Quickloot", "oldActorY", actorY)

		-- Update container highlight on hover
		local highlightContainerID = -1
		if IEex_Quickloot_IsPanelActive() then
			local panel = IEex_Quickloot_GetPanel()
			local cursorX, cursorY = IEex_GetCursorXY()
			for i = 0, 9, 1 do
				if IEex_IsPointOverControlID(panel, i, cursorX, cursorY) then
					local overSlotData = IEex_Quickloot_GetSlotData(i, true)
					if not overSlotData.isFallback then
						highlightContainerID = overSlotData.containerID
					end
				end
			end
		end
		IEex_Helper_SetBridgeNL("IEex_Quickloot", "highlightContainerID", highlightContainerID)
	end

	if not alreadyLocked then
		IEex_Helper_SynchronizedBridgeOperation("IEex_Quickloot", doUpdate)
	else
		doUpdate()
	end

	-- Redraw panel
	IEex_Quickloot_InvalidatePanel()
end

function IEex_Quickloot_GetSlotData(controlID, alreadyLocked)

	local slotData = nil

	local getSlotData = function()

		local accessIndex = IEex_Helper_GetBridgeNL("IEex_Quickloot", "itemsAccessIndex") + controlID
		local maxItemIndex = IEex_Helper_GetBridgeNumIntsNL("IEex_Quickloot", "items")

		if accessIndex > maxItemIndex then

			local defaultContainerID = IEex_Helper_GetBridgeNL("IEex_Quickloot", "defaultContainerID")

			if IEex_GetActorShare(defaultContainerID) == 0x0 then
				IEex_Quickloot_UpdateItems(true)
				defaultContainerID = IEex_Helper_GetBridgeNL("IEex_Quickloot", "defaultContainerID")
			end

			slotData = {
				["containerID"] = defaultContainerID,
				["slotIndex"] = IEex_GetContainerIDNumItems(defaultContainerID),
				["isFallback"] = true,
			}
		else
			local entry = IEex_Helper_GetBridgeNL("IEex_Quickloot", "items", accessIndex)
			slotData = {
				["containerID"] = IEex_Helper_GetBridgeNL(entry, "containerID"),
				["slotIndex"] = IEex_Helper_GetBridgeNL(entry, "slotIndex"),
			}
		end
	end

	if not alreadyLocked then
		IEex_Helper_SynchronizedBridgeOperation("IEex_Quickloot", getSlotData)
	else
		getSlotData(IEex_Bridge_LockFunctions)
	end

	return slotData
end

function IEex_Quickloot_GetValidPartyMember()

	local validate = function(actorID)
		if actorID == -1 then return false end
		local share = IEex_GetActorShare(actorID)
		if share == 0x0 then return false end
		local area = IEex_ReadDword(share + 0x12)
		return area ~= 0x0
	end

	local selectedID = IEex_GetActorIDSelected()
	if validate(selectedID) then return selectedID end

	for i = 0, 5, 1 do
		local portraitID = IEex_GetActorIDPortrait(i)
		if validate(portraitID) then return portraitID end
	end
	return -1
end

function IEex_Quickloot_GetPanel()
	return IEex_GetPanelFromEngine(IEex_GetEngineWorld(), 23)
end

function IEex_Quickloot_InvalidatePanel()
	IEex_PanelInvalidate(IEex_Quickloot_GetPanel())
end

function IEex_Quickloot_IsPanelActive()
	return IEex_IsPanelActive(IEex_Quickloot_GetPanel())
end

function IEex_Quickloot_IsControlOnPanel(control)
	return IEex_IsControlOnPanel(control, IEex_Quickloot_GetPanel())
end

---------------------------------------
-- World Screen Spell Info Functions --
---------------------------------------

function IEex_LaunchWorldScreenSpellInfo(spellResref)

	local spellWrapper = IEex_DemandRes(spellResref, "SPL")
	if not spellWrapper:isValid() then
		return
	end

	local worldScreen = IEex_GetEngineWorld()
	local newSpellInfoPanel = IEex_GetPanelFromEngine(worldScreen, IEex_WorldScreenSpellInfoPanelID)

	local spellData = spellWrapper:getData()
	local spellName = IEex_FetchString(IEex_ReadDword(spellData + 0x8))
	local spellDesc = IEex_FetchString(IEex_ReadDword(spellData + 0x50))
	spellWrapper:free()

	local nameLabel = IEex_GetControlFromPanel(newSpellInfoPanel, 1)
	IEex_SetControlLabelText(nameLabel, spellName)

	local iconControl = IEex_GetControlFromPanel(newSpellInfoPanel, 2)
	IEex_SetControlButtonMageSpellInfoIcon(iconControl, spellResref)
	IEex_SetPanelActive(newSpellInfoPanel, true)

	local descTextDisplay = IEex_GetControlFromPanel(newSpellInfoPanel, 3)
	IEex_SetControlTextDisplay(descTextDisplay, spellDesc)
end

-- Shows the info panel for a CItem instead of a spell (right-click in the loot window /
-- quickloot bar). Reads the CItem, not the .ITM file, so the unidentified item shows its
-- unidentified name and text.
function IEex_LaunchWorldScreenItemInfo(CItem)

	if CItem == 0x0 then return end

	local worldScreen = IEex_GetEngineWorld()
	-- Items get their OWN panel -- a replica of the stock inventory "Item" popup (GUIINV panel 5):
	-- a static "Item" title, the item name in yellow above the description, and a full-size (64x64)
	-- icon. Spells and bard songs keep the spellbook-style panel (IEex_WorldScreenSpellInfoPanelID).
	local newItemInfoPanel = IEex_GetPanelFromEngine(worldScreen, IEex_WorldScreenItemInfoPanelID)

	-- Item name (control 1, yellow) - CItem::GetGenericName() gives the identified name only once the
	-- item is identified, else the unidentified name. (The title, control 0, is a static "Item" label.)
	local nameLabel = IEex_GetControlFromPanel(newItemInfoPanel, 1)
	IEex_SetControlLabelText(nameLabel, IEex_FetchString(IEex_Call(0x4E9B10, {}, CItem, 0x0)))

	-- Icon (control 2): the inventory's item-icon control. SetItem() copies the CItem into the
	-- control's embedded m_item and points m_pItem at it, so Render draws GetItemIcon() with the item
	-- BAM's centre-point offset applied -- the icon lands in the frame slot instead of far below it.
	local iconControl = IEex_GetControlFromPanel(newItemInfoPanel, 2)
	IEex_Call(0x633EA0, {CItem}, iconControl, 0x0)                   -- CUIControlButtonInventoryHistoryIcon::SetItem()

	IEex_SetPanelActive(newItemInfoPanel, true)

	-- CItem::FormatItemDescription() appends the same description + stats block the inventory
	-- popup shows, so RemoveAll() the previous entry's text first.
	local descTextDisplay = IEex_GetControlFromPanel(newItemInfoPanel, 3)
	IEex_Call(0x4E2B50, {}, descTextDisplay, 0x0)                    -- CUIControlTextDisplay::RemoveAll()
	IEex_Call(0x4EA580, {0xC8C8, descTextDisplay}, CItem, 0x0)       -- RGB(200, 200, 0)
end

function IEex_StopWorldScreenSpellInfo()
	local worldScreen = IEex_GetEngineWorld()
	for _, panelID in ipairs({IEex_WorldScreenSpellInfoPanelID, IEex_WorldScreenItemInfoPanelID}) do
		local panel = IEex_GetPanelFromEngine(worldScreen, panelID)
		if IEex_IsPanelActive(panel) then
			IEex_SetPanelActive(panel, false)
			IEex_InvalidatePanelUIManager(panel)
		end
	end
end

---------------
-- Listeners --
---------------

function IEex_GuiKeyPressedListener(key)
	local worldScreen = IEex_GetEngineWorld()
	if IEex_GetActiveEngine() == worldScreen then
		if key == IEex_KeyIDS.ESC then
			IEex_StopWorldScreenSpellInfo()
		end
	end
end

function IEex_GuiRegisterListeners()
	if IEex_Vanilla then return end
	IEex_AddKeyPressedListener("IEex_GuiKeyPressedListener")
	IEex_AddKeyPressedListener("IEex_Hotkeys_KeyPressedListener")
end

function IEex_GuiReloadListener()
	IEex_GuiRegisterListeners()
	IEex_ReaddReloadListener("IEex_GuiReloadListener")
end

IEex_AbsoluteOnce("IEex_GuiInitListeners", function()
	IEex_GuiRegisterListeners()
	IEex_AddReloadListener("IEex_GuiReloadListener")
end)

------------------------
-- GUI Hook Functions --
------------------------

-- The World HUD Refonte inflates panels 0 and 1 into bounding boxes so that CUIPanel::IsOver still
-- covers the relocated controls: panel 0 spans the full-width bottom band from the (draggable) log
-- top down to the screen bottom, panel 1 the bottom-right column. Both keep their stock MOS
-- background, so the IEex_PanelHasBackground shortcut below reports that whole band as UI -- the
-- world showing through the inflated gaps became a click / hover / world-coordinate dead-zone, and
-- it grows with the log box and with the 2x UI. Gate those two panels on the ACTUAL visible HUD
-- instead: the composite content rects (portrait slots id 1; bar block id -3, which holds the
-- action bar, command row, statue buttons and quickloot toggle; log box id -2). The ids are ignored
-- here -- every refonte control on either panel sits inside one of the rects, and the only question
-- is whether the cursor is on visible HUD. Mirrors PointerOverRefonteContent in IEexHelper, which
-- the wheel already gates on (Export_WheelShouldZoom), so wheel-zoom and click/hover agree.
function IEex_Refonte_OwnsViewportPanel(nPanelID)
	return IEex_PortraitGridEnabled and IEex_Refonte_StaticRects ~= nil
		and (nPanelID == 0 or nPanelID == 1)
end

function IEex_Refonte_PointOverContent(nCursorX, nCursorY)
	local over = function(x, y, w, h)
		-- w/h <= 0 skips the degenerate id 0 keep-alive rect (it draws nothing).
		return w > 0 and h > 0
			and nCursorX >= x and nCursorX < x + w
			and nCursorY >= y and nCursorY < y + h
	end
	for _, r in ipairs(IEex_Refonte_StaticRects) do
		if over(r[2], r[3], r[4], r[5]) then return true end
	end
	local lr = IEex_Refonte_LogRect
	return lr ~= nil and over(lr.x, lr.y, lr.w, lr.h)
end

function IEex_IsPanelBlockingViewport(panel, nCursorX, nCursorY)
	if not IEex_IsPanelActive(panel) then return false end
	if IEex_Refonte_OwnsViewportPanel(IEex_GetPanelID(panel)) then
		return IEex_Refonte_PointOverContent(nCursorX, nCursorY)
	end
	if IEex_PanelHasBackground(panel) then
		return IEex_IsPointOverPanel(panel, nCursorX, nCursorY)
	else
		local result = false
		IEex_IteratePanelControls(panel, function(control)
			result = IEex_IsControlActiveForRender(control) and IEex_IsPointOverControl(control, nCursorX, nCursorY)
			return result
		end)
		return result
	end
end

function IEex_IsUIBlockingViewport(nCursorX, nCursorY)
	local worldScreen = IEex_GetEngineWorld()
	if IEex_GetActiveEngine() == worldScreen and not IEex_IsEngineUIManagerHidden(worldScreen) then
		-- UI-scaling Stage 2: nCursorX/Y derive from m_ptPointer / m_ptMousePos, which the
		-- systemic capture-source transform (Export_UIScaleCaptureMap) already makes LOGICAL
		-- whenever the cursor is over the scaled HUD -- so they can be tested directly against
		-- the (logical) panel rects. (Old per-site IEex_Helper_UIScaleMapWorldCursor removed.)
		for _, i in ipairs(IEex_AllWorldScreenPanelIDs) do
			if IEex_IsPanelBlockingViewport(IEex_GetPanelFromEngine(worldScreen, i), nCursorX, nCursorY) then
				return true
			end
		end
	end
	return false
end

function IEex_MouseInViewport(CInfinity, nCursorX, nCursorY)

	if IEex_IsUIBlockingViewport(nCursorX, nCursorY) then
		return false
	end

	local rViewPortLeft, rViewPortTop, rViewPortRight, rViewPortBottom = IEex_GetViewportRectFromCInfinity(CInfinity)
	return nCursorX >= rViewPortLeft and nCursorX < rViewPortRight
	   and nCursorY >= rViewPortTop  and nCursorY < rViewPortBottom
end

function IEex_MoveHighResolutionPaddingPanels()

	local g_pBaldurChitin = IEex_ReadDword(0x8CF6DC)
	panelLeft_st = g_pBaldurChitin + 0x49B4
	panelRight_st = g_pBaldurChitin + 0x49D0
	panelTop_st = g_pBaldurChitin + 0x49EC
	panelBottom_st = g_pBaldurChitin + 0x4A08

	local getMosWidthHeight = function(resref)
		local wrapper = IEex_DemandRes(resref, "MOS")
		local data = wrapper:getData()
		local w = IEex_ReadWord(data + 0x8)
		local h = IEex_ReadWord(data + 0xA)
		wrapper:free()
		return w, h
	end

	local leftW, leftH = getMosWidthHeight("STON10L")
	local rightW, rightH = getMosWidthHeight("STON10R")
	local topW, topH = getMosWidthHeight("STON10T")
	local bottomW, bottomH = getMosWidthHeight("STON10B")

	local resW, resH = IEex_GetResolution()

	-- panel x/y are signed 16-bit; the border can sit at a NEGATIVE logical coord (off the UI,
	-- into the letterbox void) or be taller than the UI (cropped top/bottom).
	local sw16 = function(v) v = math.floor(v + 0.5); if v < 0 then v = v + 0x10000 end; return v end

	if IEex_ReadByte(g_pBaldurChitin + 0x4A28) == 1 then
		-- Engine NATIVE 2x tier (m_bUseNewGui pivot). The border panels are stored in LOGICAL coords --
		-- the engine DOUBLES x/y/w/h at render (m_bDoubleSize) -- with the UI content = 800x600 centred in
		-- the logical screen (= physical/2). The STON mosaics are FIXED-SIZE art (de-doubled -> render at
		-- their native physical px), authored for the engine's own 2048 tier where the side void is exactly
		-- 224px. They do NOT stretch: place each flush against the UI edge at its native size. At wider
		-- resolutions black void remains beyond L/R, and the taller L/R pieces overshoot top/bottom
		-- (cropped) -- expected. Native physical px -> logical = /2 (the engine re-doubles).
		local DEFW, DEFH = 800, 600
		local uiLeft = math.floor((resW / 2 - DEFW) / 2)
		local uiTop  = math.floor((resH / 2 - DEFH) / 2)
		local lW, lH = leftW / 2, leftH / 2
		local rW, rH = rightW / 2, rightH / 2
		local tW, tH = topW / 2, topH / 2
		local bW, bH = bottomW / 2, bottomH / 2
		IEex_WriteWord(panelLeft_st + 0x4, sw16(uiLeft - lW));            IEex_WriteWord(panelLeft_st + 0x6, sw16(uiTop + (DEFH - lH) / 2))
		IEex_WriteWord(panelLeft_st + 0x8, sw16(lW));                    IEex_WriteWord(panelLeft_st + 0xA, sw16(lH))
		IEex_WriteWord(panelRight_st + 0x4, sw16(uiLeft + DEFW));         IEex_WriteWord(panelRight_st + 0x6, sw16(uiTop + (DEFH - rH) / 2))
		IEex_WriteWord(panelRight_st + 0x8, sw16(rW));                   IEex_WriteWord(panelRight_st + 0xA, sw16(rH))
		IEex_WriteWord(panelTop_st + 0x4, sw16(uiLeft + (DEFW - tW) / 2)); IEex_WriteWord(panelTop_st + 0x6, sw16(uiTop - tH))
		IEex_WriteWord(panelTop_st + 0x8, sw16(tW));                     IEex_WriteWord(panelTop_st + 0xA, sw16(tH))
		IEex_WriteWord(panelBottom_st + 0x4, sw16(uiLeft + (DEFW - bW) / 2)); IEex_WriteWord(panelBottom_st + 0x6, sw16(uiTop + DEFH))
		IEex_WriteWord(panelBottom_st + 0x8, sw16(bW));                  IEex_WriteWord(panelBottom_st + 0xA, sw16(bH))
		return
	end

	local baseResolutionW = 800
	local baseResolutionH = 600

	IEex_WriteWord(panelLeft_st + 0x4, (resW - baseResolutionW) / 2 - leftW)
	IEex_WriteWord(panelLeft_st + 0x6, (resH - leftH) / 2)
	IEex_WriteWord(panelLeft_st + 0x8, leftW)
	IEex_WriteWord(panelLeft_st + 0xA, leftH)

	IEex_WriteWord(panelRight_st + 0x4, (resW + baseResolutionW) / 2)
	IEex_WriteWord(panelRight_st + 0x6, (resH - rightH) / 2)
	IEex_WriteWord(panelRight_st + 0x8, rightW)
	IEex_WriteWord(panelRight_st + 0xA, rightH)

	IEex_WriteWord(panelTop_st + 0x4, (resW - topW) / 2)
	IEex_WriteWord(panelTop_st + 0x6, (resH - baseResolutionH) / 2 - topH)
	IEex_WriteWord(panelTop_st + 0x8, topW)
	IEex_WriteWord(panelTop_st + 0xA, topH)

	IEex_WriteWord(panelBottom_st + 0x4, (resW - bottomW) / 2)
	IEex_WriteWord(panelBottom_st + 0x6, (resH + baseResolutionH) / 2)
	IEex_WriteWord(panelBottom_st + 0x8, bottomW)
	IEex_WriteWord(panelBottom_st + 0xA, bottomH)
end

------------------
-- Thread: Sync --
------------------

-- HUD layer perf: cheap content hash of the party portraits' DYNAMIC RenderPortrait inputs
-- (CGameSprite::RenderPortrait draws: HP bar height, dead/low-HP tint, blood-flash + talking
-- pulse animations, health colour). Computed ONLY on AI-tick frames (see BeforeWorldRender),
-- so the 6x GetActorShare resolves run at tick rate (~30 Hz), never per render frame. When the
-- hash is unchanged the portraits are pixel-identical, so the ~5ms full panel-1 repaint (measured
-- 93% portraits) is pure waste and gets skipped. Selection/hover rings are engine-invalidated
-- natively and are NOT hashed. Offsets are CGameSprite-relative (RE'd struct, pristine .text).
-- The slot's actorID is hashed too: a party REORDER (CUIControlPortraitWorld::OnLButtonUp 0x77B160
-- -> CInfGame::SwapCharacters) rewrites the slot->actor mapping while touching none of the stat
-- fields below, and it invalidates the two portrait CONTROLS but never panel 1 -- so without the
-- id in the hash, swapping two same-stat PCs leaves the layer showing the old order.
--
-- The id comes from the PORTRAIT array (m_characterPortraits, 0x382E) -- what the slot actually
-- draws. CInfGame::RenderPortrait resolves its sprite through GetCharacterId (0x452FE0), which
-- despite the name indexes m_characterPortraits, NOT m_characters (0x3816, IEex_GetActorIDCharacter).
-- The two orders are distinct, and a reorder permutes the portrait one.
function IEex_HudLayer_PortraitContentHash()
	local h = 0
	for c = 0, 5 do
		local actorID = IEex_GetActorIDPortrait(c)
		if actorID and actorID >= 0 and IEex_IsSprite(actorID, true) then
			local spr = IEex_GetActorShare(actorID)
			if spr and spr ~= 0 then
				local hp    = IEex_ReadSignedWord(spr + 0x5C0, 0x0)   -- m_baseStats.m_hitPoints
				local maxHP = IEex_ReadSignedWord(spr + 0x924, 0x0)   -- m_derivedStats.m_nMaxHitPoints
				local flAmt = IEex_ReadSignedWord(spr + 0x53DA, 0x0)  -- m_nBloodFlashAmount (animates)
				local flOn  = IEex_ReadDword(spr + 0x53E2)            -- m_bBloodFlashOn
				local hcol  = IEex_ReadDword(spr + 0x53E6)            -- health-colour tint state
				local talk  = IEex_ReadDword(spr + 0x712A)            -- m_talkingCounter (animates)
				-- Ring inputs (selection ring / speaker highlight). RenderPortrait derives the
				-- ring colour from these, but ring repaints used to rely on the ENGINE's native
				-- control invalidates -- and the pre-world UI render can consume that counter
				-- before the HUD-layer render runs, so a selection change sometimes never
				-- reached the layer (ring stuck absent -- or stale -- until the next unrelated
				-- repaint). Hashing them re-invalidates panel 1 deterministically instead.
				local sel    = IEex_ReadDword(spr + 0x50B2)           -- m_bSelected
				local marker = IEex_ReadDword(spr + 0x564E)           -- m_marker.m_rgbColor (pulses while talking)
				local area   = IEex_ReadDword(spr + 0x12)             -- m_pArea
				local pick   = 0
				if area ~= 0 and IEex_ReadDword(spr + 0x5C) == IEex_ReadDword(area + 0x246) then
					pick = 1                                          -- m_id == area->m_iPicked (hover marker)
				end
				h = (h * 131 + c * 1000003 + actorID * 31 + hp + 100000) % 2147483647
				h = (h * 131 + maxHP + flAmt * 7 + flOn * 13 + hcol * 17 + talk * 19) % 2147483647
				h = (h * 131 + sel * 23 + pick * 29 + marker) % 2147483647
			end
		end
	end
	return h
end

function IEex_Extern_BeforeWorldRender()

	IEex_AssertThread(IEex_Thread.Sync, true)

	local worldScreen = IEex_GetEngineWorld()

	------------------------------------------------
	-- Worldscreen spell info position processing --
	------------------------------------------------

	if not IEex_Vanilla then

		-- Both info popups -- spell/bard song (50) and item (51) -- are constructed at the ctor
		-- origin (0,0) with no def x/y and centred HERE every frame via SetPanelXY, which moves the
		-- panel m_ptOrigin (+0x24). The engine MageSpellInfoIcon renders at m_pPanel->m_ptOrigin +
		-- m_ptOrigin, so moving the panel origin drags the icon with it and it stays in the frame.
		-- (A def x/y or SetPanelArea shifts the panel but leaves the icon at its build position, so
		-- the icon alone lands top-left of the background.) Only one is ever active at a time.
		for _, infoPanelID in ipairs({IEex_WorldScreenSpellInfoPanelID, IEex_WorldScreenItemInfoPanelID}) do

			local infoPanel = IEex_GetPanelFromEngine(worldScreen, infoPanelID)

			if IEex_IsPanelActive(infoPanel) then

				local rViewPortLeft, rViewPortTop, rViewPortRight, rViewPortBottom = IEex_GetViewportRect()
				local _, _, panelWidth, panelHeight = IEex_GetPanelArea(infoPanel)

				-- Desired on-screen centre of the popup: middle of the visible play area.
				local centreX = rViewPortLeft + (rViewPortRight - rViewPortLeft) / 2
				local centreY = rViewPortTop + (IEex_GetMainViewportBottom() - rViewPortTop) / 2

				-- UI-scaling Stage 2: the world HUD (incl. this panel) renders through a bottom-
				-- centre MODELVIEW scale, which would shove a panel stored at the play-area centre
				-- off the top of the screen (cropped). Inverse-map the desired on-screen centre to
				-- the stored coord so the forward render scale lands the panel centre back there.
				-- Identity on the software renderer / native UI scale, so vanilla centring is
				-- unchanged. Subtract NATIVE half-size: the panel's own scaling cancels out.
				local mappedX, mappedY = IEex_Helper_UIScaleMapWorldCursor(centreX, centreY)
				local centeredX = mappedX - panelWidth / 2
				local centeredY = math.max(0, mappedY - panelHeight / 2)

				IEex_SetPanelXY(infoPanel, centeredX, centeredY)
				IEex_PanelInvalidate(infoPanel)
			end
		end
	end

	-- Dialog-family panels (debug console, dialog, container, dialog chat): while any is
	-- active the game is paused and the engine shrinks the world viewport -- the IEex bars
	-- (action indicators / quickloot) sit over a region the world no longer paints (solid
	-- black) and are meaningless anyway -> hide them, and the HUD layer takes its dialog
	-- bypass below.
	local dialogFamilyActive = false
	for _, i in ipairs({6, 7, 8, 22}) do
		if IEex_IsPanelActive(IEex_GetPanelFromEngine(worldScreen, i)) then
			dialogFamilyActive = true
			break
		end
	end

	--------------------------------------------
	-- Action Indicators show/hide processing --
	--------------------------------------------

	if IEex_Helper_GetBridge("IEex_Options", "options", "actionIndicators") then

		local panel1 = IEex_GetPanelFromEngine(worldScreen, 1)
		local actionIndicatorsPanel = IEex_GetPanelFromEngine(worldScreen, IEex_ActionIndicatorsPanelID)

		if IEex_IsPanelActive(panel1) and not dialogFamilyActive then

			local _, panel1Y = IEex_GetPanelArea(panel1)
			local _, _, _, panelHeight = IEex_GetPanelArea(actionIndicatorsPanel)
			-- Anchor: stock = flush above the HUD (panel-1 top; the old +3 overlap bit into the
			-- stone border). Refonte: panel 1 is a widened bounding box whose top stays at the
			-- stock action bar, but the portraits live in the bottom-right row -- anchor to the
			-- portrait controls' actual top instead (control 0 Y is panel-relative device px).
			local anchorY = panel1Y
			if IEex_PortraitGridEnabled then
				local _, ctrl0Y = IEex_GetControlArea(IEex_GetControlFromPanel(panel1, 0))
				anchorY = panel1Y + ctrl0Y
			end
			IEex_SetPanelXY(actionIndicatorsPanel, nil, anchorY - panelHeight)

			if not IEex_IsPanelActive(actionIndicatorsPanel) then
				IEex_ActionIndicators_Show()
			end

		elseif IEex_IsPanelActive(actionIndicatorsPanel) then
			IEex_ActionIndicators_Hide()
		end
	end

	------------------------------------
	-- Quickloot show/hide processing --
	------------------------------------

	if IEex_Helper_GetBridge("IEex_Quickloot", "on") then

		local quicklootPanel = IEex_GetPanelFromEngine(worldScreen, 23)

		if IEex_IsPanelActive(quicklootPanel) and dialogFamilyActive then
			IEex_Quickloot_Hide()
		elseif IEex_IsPanelActive(IEex_GetPanelFromEngine(worldScreen, 1)) then -- Main Panel
			IEex_Quickloot_Show()
		end

		-- Anchor: bottom of the free area = viewport bottom. The content-sized bar
		-- shares the row directly above the HUD with the action indicators (disjoint
		-- X ranges); only if the rects DO overlap horizontally (narrow resolutions)
		-- stack it above the indicator row instead.
		local quicklootAnchor = IEex_GetMainViewportBottom(true)
		if IEex_Helper_GetBridge("IEex_Options", "options", "actionIndicators") then
			local indicatorsPanel = IEex_GetPanelFromEngine(worldScreen, IEex_ActionIndicatorsPanelID)
			if IEex_IsPanelActive(indicatorsPanel) then
				-- The indicators PANEL is full-width; its useful controls sit over the
				-- portraits (right side). Compare against the leftmost CONTROL instead
				-- of the panel rect, else this would always stack.
				local qlX, _, qlW = IEex_GetPanelArea(quicklootPanel)
				local indX, indicatorsY = IEex_GetPanelArea(indicatorsPanel)
				local leftmost = math.huge
				for i = 0, 2 do
					local ctrlX = IEex_GetControlArea(IEex_GetControlFromPanel(indicatorsPanel, i))
					leftmost = math.min(leftmost, indX + ctrlX)
				end
				if leftmost ~= math.huge and qlX + qlW > leftmost then
					quicklootAnchor = math.min(quicklootAnchor, indicatorsY)
				end
			end
		end
		local _, _, qlWidth, panelHeight = IEex_GetPanelArea(quicklootPanel)
		local panel1 = IEex_GetPanelFromEngine(worldScreen, 1)
		local abFirst = IEex_GetControlFromPanel(panel1, 6)
		local abLast = IEex_GetControlFromPanel(panel1, 17)
		if IEex_PortraitGridEnabled and abFirst ~= 0x0 and abLast ~= 0x0 then
			-- Refonte: sit the bar just above the ACTION BAR (panel 1 ctrl 6..17, relocated
			-- to the bottom-centre block). Read the row's LIVE geometry rather than the
			-- refonte globals -- this per-tick handler runs in a lua State where the CHU-set
			-- IEex_Refonte_BarBlock is nil, so the global path silently fell through to the
			-- viewport anchor and floated the bar to the top of the screen.
			local p1x, p1y = IEex_GetPanelArea(panel1)
			local c6x, c6y, c6w = IEex_GetControlArea(abFirst)
			local c17x, _, c17w = IEex_GetControlArea(abLast)
			local rowLeft = p1x + c6x
			local rowW = (p1x + c17x + c17w) - rowLeft
			-- Stick the bar FLUSH to the BLOCK ART top: the action-bar buttons sit 8px
			-- (art px) inside the block frame, so anchoring at the button top overlapped
			-- the frame ("bar too low"). No refonte globals in this lua state -- derive
			-- the art scale from the button width (38 * s).
			local blockCap = math.floor(c6w * 8 / 38 + 0.5)
			-- Small gap so the bar art CLEARS the block frame instead of touching it (user: it
			-- read as overlapping the action bar; a full blockCap gap was too high). ~3 art px,
			-- scaled from the button width like blockCap (no refonte globals in this lua state). Tunable.
			local qGap = math.floor(c6w * 3 / 38 + 0.5)
			IEex_SetPanelXY(quicklootPanel, rowLeft + math.floor((rowW - qlWidth) / 2), p1y + c6y - panelHeight - blockCap - qGap)
		else
			IEex_SetPanelXY(quicklootPanel, nil, quicklootAnchor - panelHeight)
		end
	end

	-------------------------------------------------
	-- Refonte: track the party size (reform party) --
	-------------------------------------------------

	-- The portrait row's composite rects are per-SLOT and REPLACE opaque, so a slot freed by a
	-- reform (or a member leaving) must lose its rect -- otherwise it composites as a black box
	-- over the world and still blocks clicks. Rebuilding also re-registers the log rect.
	if IEex_PortraitGridEnabled and IEex_Refonte_PortraitRow then
		if IEex_Refonte_SlotMask() ~= IEex_Refonte_LastSlotMask then
			IEex_Refonte_RebuildStaticRects()
			IEex_Refonte_RegisterRects()
			IEex_PanelInvalidate(IEex_GetPanelFromEngine(worldScreen, 1))
		end
	end

	---------------------------------------
	-- Invalidate all worldscreen panels --
	-- (so they render above viewport)   --
	---------------------------------------

	-- With the HUD layer active (GL: UI composited from its own persistent FBO,
	-- IEex_Gui_Patch.lua @0x68DFB6) panels persist across frames and only real
	-- engine invalidations repaint -- the blanket per-frame invalidate would
	-- defeat the layer (measured ~1.5ms/frame of MOS+control redraw at 4K).
	-- Keep it only for the fallback path where the UI draws straight into the
	-- world-covered framebuffer.
	-- DIALOG MODE: dialog panels reflow/resize continuously and show/hide their
	-- controls (Continue) -- in the persistent layer that left either residue
	-- (event-driven) or flicker (forced repaint). Bypass the layer entirely for
	-- these frames (IEex_Helper_HudLayerSkipFrame = the proven pre-layer path,
	-- with the blanket invalidate below) -- dialog fps is a non-issue.
	local hudLayerLive = IEex_Helper_IsHudLayerActive()
	if hudLayerLive and dialogFamilyActive then
		IEex_Helper_HudLayerSkipFrame()
		hudLayerLive = false
	end
	if hudLayerLive then
		-- EVENT-DRIVEN repaint of the two live panels (previously forced every
		-- frame: ~0.62ms panel 1 + ~0.13ms panel 100 at 4K, plus their share of
		-- GL command volume in swap).
		--
		-- Panel 1 (portrait row): engine UI events (hover/press/selection/swap)
		-- invalidate the portrait CONTROLS natively and those repaints reach the
		-- layer on their own -- but the portrait CONTENT (CInfGame::RenderPortrait:
		-- damage tint, state overlays, casting glow) is live sprite state drawn
		-- with no invalidate on change. All of it advances at AI-tick rate, so
		-- repaint once per game tick (~15 Hz). While PAUSED the tick stops, so there
		-- is no edge to gate on -- hash EVERY frame there instead. The old blanket
		-- per-frame invalidate on the paused branch cost 2.3ms/frame of panel-1 full
		-- repaint (it holds m_doRender > 0, which defeats the DLL's
		-- HudLayerContentPanel1CleanSkip): measured on Bubb's 240Hz box as render CPU
		-- 2.14 -> 4.50ms/frame, over the 4.167ms budget of the 238 cap, so paused fps
		-- fell 240 -> 210. The hash still covers what that fallback was written for:
		-- the initial post-load stamp under auto-pause (sprites not yet loaded ->
		-- black portraits, no tick to heal them) moves hp/maxHP the moment they land,
		-- and selection/hover ring inputs are hashed too.
		local invalidatePortraits = true
		-- Refonte: the stale-selection-border cause was PIXEL RESIDUE in the persistent layer, not
		-- invalidation timing -- RenderPortrait draws NOTHING where it means "off" (the ring DrawLines
		-- are skipped when rgbColor==0), and the relocated corner has no MOS beneath to erase old green
		-- (GUIRSPOR's opaque art heals only the ring's bottom row). The DLL now owns panel-1 freshness
		-- while the refonte's content-rects are registered: HudLayerSparseClear scissor-clears every
		-- registered rect + full-invalidates the panel before each repaint. The tick-gate below stays
		-- for the portrait CONTENT cadence (damage tint, casting glow at AI-tick rate) in BOTH layouts.
		local game = IEex_GetGameData()
		if game ~= 0x0 then
			-- Running: gate on the game-tick edge (the content only advances per tick).
			-- Paused: m_worldTime.m_active is 0 and m_gameTime is frozen, so there is no
			-- edge -- treat every frame as one and let the hash below do the gating.
			local tickEdge = true
			if IEex_ReadByte(game + 0x1B7C) ~= 0 then           -- m_worldTime.m_active
				local gameTime = IEex_ReadDword(game + 0x1B78)   -- m_worldTime.m_gameTime
				tickEdge = gameTime ~= IEex_HudLayer_LastGameTime
				if tickEdge then
					IEex_HudLayer_LastGameTime = gameTime
				end
			end
			if tickEdge then
				-- Repaint portraits ONLY if their content actually changed (HP / blood-flash /
				-- talking / health-colour / selection / hover). Idle/walking leaves them
				-- identical -> skip the ~5ms full panel-1 repaint (93% portraits, measured).
				-- Flash/talk animate the hashed fields each tick so they still play; a missed
				-- state self-heals on the next HP change.
				local hash = IEex_HudLayer_PortraitContentHash()
				invalidatePortraits = hash ~= IEex_HudLayer_LastPortraitHash
				IEex_HudLayer_LastPortraitHash = hash
			else
				invalidatePortraits = false
			end
		end
		if invalidatePortraits then
			local panel = IEex_GetPanelFromEngine(worldScreen, 1)
			if IEex_IsPanelActive(panel) or IEex_IsPanelInactiveRender(panel) then
				IEex_PanelInvalidate(panel)
			end
		end

		-- Panel 100 (action indicators): icon choice + control-active flags are
		-- resolved ONLY inside IEex_ActionIndicators_Update's settle window
		-- (async thread), which bumps updateCounter after every pass. Repaint
		-- when the counter moves.
		local counter = IEex_Helper_GetBridge("IEex_ActionIndicators", "updateCounter")
		if counter ~= IEex_HudLayer_LastIndicatorsCounter then
			IEex_HudLayer_LastIndicatorsCounter = counter
			local panel = IEex_GetPanelFromEngine(worldScreen, IEex_ActionIndicatorsPanelID)
			if IEex_IsPanelActive(panel) or IEex_IsPanelInactiveRender(panel) then
				IEex_PanelInvalidate(panel)
			end
		end
	else
		for _, i in ipairs(IEex_AllWorldScreenPanelIDs) do
			local panel = IEex_GetPanelFromEngine(worldScreen, i)
			if IEex_IsPanelActive(panel) or IEex_IsPanelInactiveRender(panel) then
				IEex_PanelInvalidate(panel)
			end
		end
	end

	-------------------------------------------------------------------
	-- Adjust viewport if a panel state change exposed out-of-bounds --
	-------------------------------------------------------------------

	IEex_CheckViewPosition()
end

function IEex_Extern_OverrideWorldScreenScrollbarFocus()

	IEex_AssertThread(IEex_Thread.Sync, true)

	local worldScreen = IEex_GetEngineWorld()
	local newSpellInfoPanel = IEex_GetPanelFromEngine(worldScreen, IEex_WorldScreenSpellInfoPanelID)

	if IEex_IsPanelActive(newSpellInfoPanel) then
		local descTextDisplayScrollbar = IEex_GetControlFromPanel(newSpellInfoPanel, 4)
		IEex_SetEngineScrollbarFocus(worldScreen, descTextDisplayScrollbar)
		return true
	end

	return false
end

function IEex_Extern_InitResolution()

	IEex_AssertThread(IEex_Thread.Sync, true)

	-- Pass the 2x UI install state so the dialog can warn below the component's 2048x1200
	-- minimum (red status line, "Recommended" retag, SELECT confirm) -- see MFCLibrary1.cpp.
	-- Plain boolean, NOT "and 1 or 0": the helper reads lua_toboolean, and the NUMBER 0 is
	-- truthy in lua -- passing 0 reported the component installed on clean installs.
	local nWidth, nHeight = IEex_Helper_AskResolution(IEEX_HD_UI)
	IEex_WriteWord(0x8BA31C, nWidth)  -- g_resolution.width
	IEex_WriteWord(0x8BA31E, nHeight) -- g_resolution.height
	IEex_WritePrivateProfileInt("Program Options", "BitsPerPixel", 32, ".\\Icewind2.ini")

	-- 2x UI below its 2048x1200 minimum (player confirmed through the dialog warning): the 2x
	-- tier gate (IEex_Extern_InitGUIConstants) keeps m_bUseNewGui off, but the helper's HD-UI
	-- canvas (GetUICanvasScale = 2.0 in engine-1x mode) would still declare a phantom 1600x1200
	-- base -> clipped/mis-fit UI. Force it off so the GL canvas is honest 1x. The 2x assets in
	-- override still render oversized on the 1x tier -- that is unfixable at runtime (the
	-- component replaces the stock 1x files), which is exactly what the dialog warned about.
	-- Runs AFTER IEex_UIScale_Patch.lua's load-time SetHDUI, so this override sticks.
	if IEEX_HD_UI and (nWidth < 2048 or nHeight < 1200) then
		IEex_Helper_SetHDUI(0)
	end
	-- NOTE: the engine's OpenGL renderer is enabled by the ctor byte-patch in IEex_Render_Patch.lua
	-- (m_cVideo.m_bIs3dAccelerated). The retail engine hardcodes that flag FALSE (mov [esi+0x91c],ebx,
	-- ebx=0) and ignores the "3D Acceleration" ini key entirely, so there is nothing to set here.

	------------------------------------------------------------------
	-- Standardize when the engine non-instantaneously auto-scrolls --
	-- to dialog to just outside of viewport range                  --
	------------------------------------------------------------------

	IEex_DisableCodeProtection()

	local maxNonInstantRange = math.pow(nWidth / 2, 2) + math.pow(nHeight / 2, 2)
	IEex_WriteDword(0x484BA2, maxNonInstantRange)
	IEex_HookRestore(0x6902D4, 3, 2, {"!mov_ecx", {maxNonInstantRange, 4}})

	------------------------------------------------------------------------------
	-- Resolution-scale positional-SFX PAN spread. CBaldurChitin init calls        --
	-- SetPanRange(1024); Play/ResetVolume divide pan by m_nPanRange, so at hi-res  --
	-- the stereo field must widen with the viewport. Scale the SetPanRange arg by  --
	-- nWidth/800 (true render width; applied HERE, not at Sound_Patch load time,   --
	-- when SCREENWIDTH @0x8BA31C is still the 800 default). The paired m_nRange     --
	-- (audible radius) is scaled per-construction and zoom-aware by                --
	-- IEex_Helper_ScaleSoundRange (see IEex_Sound_Patch.lua) -- do NOT also patch  --
	-- the 0x7A8C57 store here: that region is now a jmp to the range stub.         --
	------------------------------------------------------------------------------
	if nWidth > 800 then
		IEex_WriteDword(0x42629E, math.floor(1024 * nWidth / 800 + 0.5))  -- m_nPanRange arg (push imm32 @0x42629D +1)
	end

	IEex_EnableCodeProtection()
end

function IEex_Extern_CheckBitDepth()
	local g_pBaldurChitin = IEex_ReadDword(0x8CF6DC)
	local nBitDepth = IEex_ReadWord(g_pBaldurChitin + 0x7EA)
	if nBitDepth ~= 32 then
		IEex_MessageBox("Error: Unable to find a display mode at the target resolution with a 32-bit color depth.\n\nThe game will exit after you press OK...")
		return false
	end
	return true
end

function IEex_Extern_InitGUIConstants()
	IEex_AssertThread(IEex_Thread.Sync, true)
	local resW, resH = IEex_GetResolution()
	IEex_SetCRect(0x8E7548, 0, 0, resW, resH) -- WorldScreenInterfaceHiddenViewPortRect
	IEex_SetCRect(0x8E79B8, 0, 0, resW, resH) -- WorldScreenCurrentHiddenViewPortRect
	IEex_SetCRect(0x8E7958, 0, 0, resW, resH) -- WorldScreenDialogViewPortRect
	IEex_SetCRect(0x8E7988, 0, 0, resW, resH) -- WorldScreenDeathViewPortRect
	IEex_WriteDword(0x8E79D4, resH)           -- WorldScreenConsoleBottom
	IEex_WriteDword(0x8E79EC, resH)           -- WorldScreenToolbarBottom
	IEex_SetCRect(0x8E79F8, 0, 0, resW, resH) -- WorldScreenContainerViewPortRect
	-- Save-thumbnail (ICEWIND2.BMP) capture window: CScreenWorld::SaveScreen renders the area into this
	-- fixed 512x384 physical-screen rect, then the save downsamples it (x5) to the 102x76 thumbnail. The
	-- stock engine centres it PER RESOLUTION TIER in CBaldurChitin (800/1024/1600/2048); at any other /
	-- higher resolution it falls back to the 800 top-left rect -> the thumbnail captures the top-left
	-- corner (usually black / not the party). Recentre it for the ACTUAL resolution here (runs after the
	-- tier switch). This formula reproduces the stock 800/1024/1600 tiers EXACTLY and generalises: 512
	-- wide x 384 tall, 42px vertical up-bias. Output stays the stock 102x76 1x BMP -> loads with/without mod.
	IEex_SetCRect(0x8E79A8,
		math.floor(resW / 2) - 256, math.floor(resH / 2) - 234,
		math.floor(resW / 2) + 256, math.floor(resH / 2) + 150) -- WorldScreenSaveScreenShotRect
end

function IEex_Extern_InitHighResolutionPaddingPanels(pBaldurChitin)

	IEex_AssertThread(IEex_Thread.Sync, true)

	local resW, resH = IEex_GetResolution()

	-- HD UI (2x) -- enable the engine's NATIVE 2x tier GLOBALLY so the WHOLE UI (menus, world HUD,
	-- inventory content, borders, centring) doubles consistently. m_bUseNewGui @+0x4A28 (BOOLEAN) +
	-- field_4A2C @+0x4A2C (= GetDoubleSize()) both gate CUIManager::fInit(...,bDoubleSize) -> the engine
	-- renders all UI geometry + art x2. The engine sets these only at width 1600/2048; IEex's resolution
	-- path bypasses that, so set them here (the CBaldurChitin ctor stage -- use pBaldurChitin, NOT
	-- [0x8CF6DC] which isn't assigned yet). Only at >=2048x1200 (below that the centred record screen
	-- clips). UIMult() reads 0x4A28, so the GL render-scale auto-fits the 2x UI to the screen (+ Stretch);
	-- the selective de-double keeps the 2x art crisp. Gated on IEEX_HD_UI (the 2x UI WeiDU component flips
	-- it true; core ships 1x). This is the canonical 2x mechanism -- supersedes the pre-scaled-CHU hybrid.
	if IEEX_HD_UI and resW >= 2048 and resH >= 1200 then
		IEex_WriteByte(pBaldurChitin + 0x4A28, 1)   -- m_bUseNewGui -> fInit bDoubleSize
		IEex_WriteDword(pBaldurChitin + 0x4A2C, 1)  -- field_4A2C   -> GetDoubleSize()
	end

	-- Remove the high-res padding panels if the resolution can't display them, OR whenever the player has
	-- NOT opted into decorative borders ("UI Borders" off) -> clean black margins (a partially-positioned
	-- padding panel crashes). The "UI Borders" toggle now applies in BOTH the 2x (m_bUseNewGui) and the 1x
	-- UI -- previously it was honoured only under m_bUseNewGui, so without the 2x UI the borders were forced
	-- on and the toggle was inert. The STON10* mosaics ship 2x-authored (L/R = 224px = the side void at
	-- 2048x1200) when the 2x UI is installed; IEex_MoveHighResolutionPaddingPanels positions them natively
	-- (top/bottom overshoot, cropped = fine). The borders-on path (panels kept + natively positioned) is the
	-- same one already used without the 2x UI, so this only newly enables the borders-OFF case there.
	local bordersOn = IEex_GetPrivateProfileInt("IEex Options", "UI Borders", 1, ".\\Icewind2.ini") ~= 0
	if resW < 1024 or resH < 768 or not bordersOn then

		IEex_DisableCodeProtection()

		-- Wipe out the hardcoded panel definitions. This is overkill, but they deserve it.
		IEex_Helper_Memset(pBaldurChitin + 0x49B4, 0, 4 * 0x1C)

		-- Common panels are disabled - skip code that assumes they are there.
		-- Note: Multiplayer panels HAVE NOT BEEN FIXED because IWD2:EE doesn't
		-- support Multiplayer.
		IEex_WriteAssembly(0x5DBC09, {"!jmp_byte"})
		IEex_WriteAssembly(0x5FEDE9, {"!jmp_byte"})
		IEex_WriteAssembly(0x607B57, {"!jmp_byte"})
		IEex_WriteAssembly(0x626D59, {"!jmp_byte"})
		IEex_WriteAssembly(0x63DBA9, {"!jmp_byte"})
		IEex_WriteAssembly(0x641789, {"!jmp_byte"})
		IEex_WriteAssembly(0x654F19, {"!jmp_byte"})
		IEex_WriteAssembly(0x65CF09, {"!jmp_byte"})
		IEex_WriteAssembly(0x661D29, {"!jmp_byte"})
		IEex_WriteAssembly(0x66A854, {"!jmp_byte"})
		IEex_WriteAssembly(0x672EED, {"!jmp_byte"})

		IEex_EnableCodeProtection()
	end
end

-------------------
-- Thread: Async --
-------------------

function IEex_Extern_MouseInAreaViewport(CGameArea)

	IEex_AssertThread(IEex_Thread.Async, true)

	if IEex_GetActiveEngine() ~= IEex_GetEngineWorld() then
		return false
	end

	-- m_ptMousePos (CGameArea+0x256) is the PHYSICAL cursor whenever a world handler physicalized
	-- it (the *Phys wrappers); over the world it is physical anyway. The device-space viewport-rect
	-- test below wants that physical point, but the UI-block test wants the LOGICAL cursor -- so map
	-- a copy back for the block test only (IEex_Helper_WorldRejectMapCursor: no-op off the scaled
	-- HUD / at s==1). Inlined (not IEex_MouseInViewport) because the two tests want different spaces.
	local nCursorX = IEex_ReadDword(CGameArea + 0x256)
	local nCursorY = IEex_ReadDword(CGameArea + 0x25A)
	local lx, ly = nCursorX, nCursorY
	if IEex_Helper_WorldRejectMapCursor then
		lx, ly = IEex_Helper_WorldRejectMapCursor(nCursorX, nCursorY)
	end
	if IEex_IsUIBlockingViewport(lx, ly) then
		return false
	end
	local L, T, R, B = IEex_GetViewportRectFromCInfinity(IEex_GetCInfinityFromArea(CGameArea))
	return nCursorX >= L and nCursorX < R and nCursorY >= T and nCursorY < B
end

function IEex_Extern_RejectGetWorldCoordinates(CInfinity, x, y)
	IEex_AssertThread(IEex_Thread.Async, true)
	-- A world-interaction handler may have swapped its pt to the PHYSICAL cursor (the *Phys
	-- wrappers) so its world math + device-space viewport gate work over the scaled-HUD gaps; map
	-- it back to the LOGICAL cursor for the panel content test. No-op for a genuine logical cursor,
	-- a non-cursor point, or at s==1 (physical == logical). Keeps IEex_IsUIBlockingViewport correct.
	if IEex_Helper_WorldRejectMapCursor then
		x, y = IEex_Helper_WorldRejectMapCursor(x, y)
	end
	return IEex_IsUIBlockingViewport(x, y)
end

function IEex_Extern_OnActionbarUnhandledRButtonClick(nIndex)
	IEex_AssertThread(IEex_Thread.Async, true)
	local nState = IEex_GetActionbarState()
	-- 0x66/0x67 = spell pick, 0x6A/0x6B = innate, 0x70/0x7A = bard-song pick (#126).
	-- Song list entries use the same 0x15-0x20 button types as spells, so the info
	-- panel works for them too once the song states reach this handler.
	if nState == 0x66 or nState == 0x67 or nState == 0x6A or nState == 0x6B
		or nState == 0x70 or nState == 0x7A then
		local nButtonType = IEex_GetActionbarButtonType(nIndex)
		if nButtonType >= 0x15 and nButtonType <= 0x20 then
			local nScrollIndex = IEex_GetActionbarScrollIndex()
			local nSpellButtonIndex = nScrollIndex + (nButtonType - 0x15)
			local buttonData = IEex_GetAtCPtrListIndex(IEex_GetCurrentActionbarQuickButtons(), nSpellButtonIndex)
			if not buttonData then return end
			local resref = IEex_ReadLString(buttonData + 0x1A + 0x6, 8) -- CButtonData.m_abilityId.m_res
			IEex_LaunchWorldScreenSpellInfo(resref)
		end
	end
end

function IEex_Extern_RejectWorldScreenEsc()
	IEex_AssertThread(IEex_Thread.Async, true)
	local newSpellInfoPanel = IEex_GetPanelFromEngine(IEex_GetEngineWorld(), IEex_WorldScreenSpellInfoPanelID)
	return IEex_IsPanelActive(newSpellInfoPanel)
end

function IEex_Extern_StartDebugConsole()
	IEex_AssertThread(IEex_Thread.Async, true)
	local worldScreen = IEex_GetEngineWorld()
	local panel1 = IEex_GetPanelFromEngine(worldScreen, 1)
	IEex_SetPanelActive(panel1, false)
end

function IEex_Extern_StopDebugConsole()
	IEex_AssertThread(IEex_Thread.Async, true)
	local worldScreen = IEex_GetEngineWorld()
	local panel1 = IEex_GetPanelFromEngine(worldScreen, 1)
	IEex_SetPanelActive(panel1, true)
end

------------------
-- Thread: Both --
------------------

function IEex_Extern_OnSetActionbarState(nState)
	IEex_AssertThread(IEex_Thread.Both, true)
	if IEex_GetGameData() == 0x0 then return end
end

IEex_TooltipKillReason = {
	UNKNOWN = 0,
	EFFECT_LIST_UPDATE = 1,
}

function IEex_Extern_ShouldTooltipRefreshInsteadOfDying(killReason)
	IEex_AssertThread(IEex_Thread.Both, true)
	return killReason == IEex_TooltipKillReason.EFFECT_LIST_UPDATE
end

function IEex_Extern_CUIManager_fInit_CHUInitialized(CUIManager, resrefPointer)

	IEex_AssertThread(IEex_Thread.Both, true)
	local resref = IEex_ReadLString(resrefPointer, 8)

	IEex_OnCHUInitialized(resref)

	if not IEex_Vanilla then

		local resrefOverride = IEex_Helper_GetBridge("IEex_GUIConstants", "panelActiveByDefault", resref)
		if not resrefOverride then return end

		IEex_Helper_IterateBridge(resrefOverride, function(panelID, active)
			local panel = IEex_GetPanel(CUIManager, panelID)
			if panel ~= 0x0 then
				IEex_SetPanelActive(panel, active)
			end
		end)
	end
end

function IEex_Extern_CUIControlBase_CreateControl(resrefPointer, panel, controlInfo)

	IEex_AssertThread(IEex_Thread.Both, true)

	local resref = IEex_ReadLString(resrefPointer, 8)
	local panelID = IEex_ReadDword(panel + 0x20)
	local controlID = IEex_ReadDword(controlInfo)

	-- Hack to get the chargen animation preview control to call its TimerAsynchronousUpdate() every tick
	if resref == "GUICG" and panelID == 13 and controlID == 1 then
		local flagsAddress = controlInfo + 0xD
		IEex_WriteByte(flagsAddress, IEex_SetBit(IEex_ReadByte(flagsAddress), 0))
	end

	local controlOverride = IEex_Helper_GetBridge("IEex_GUIConstants", "controlOverrides", resref, panelID, controlID)
	if not controlOverride then return 0x0 end

	local controlMeta = IEex_Helper_GetBridge("IEex_GUIConstants", "controlTypeMeta", controlOverride)
	if not controlMeta then
		IEex_TracebackMessage("IEex Critical Error - No metadata defined for IEex_ControlType "..controlOverride)
		return 0x0
	end

	local control = IEex_Malloc(IEex_Helper_GetBridge(controlMeta, "size"))
	IEex_Call(IEex_Helper_GetBridge(controlMeta, "constructor"), {controlInfo, panel}, control, 0x0)

	return control
end

-------------------
-- GUI Additions --
-------------------

IEex_Helper_InitBridgeFromTable("IEex_GUIConstants", {

	["panelActiveByDefault"] = {
		["GUIW08"] = {
			[23] = false,
			[IEex_ActionIndicatorsPanelID] = false,
		},
		["GUIW10"] = {
			[23] = false,
			[IEex_ActionIndicatorsPanelID] = false,
		},
	},

	["controlTypeMeta"] = {
		["ButtonWorldContainerSlot"] = { ["constructor"] = 0x6956F0, ["size"] = 0x666 },
		["ButtonMageSpellInfoIcon"] =  { ["constructor"] = 0x66E3A0, ["size"] = 0x676 },
		-- Inventory's own item-icon control: its Render adds the BAM centre-point offset that item
		-- icons carry (GetCurrentCenterPoint) + uses ICON_SIZE_LG, so an item icon lands in its frame
		-- (the spell MageSpellInfoIcon omits the offset -> item icon renders far below). size = m_item
		-- (CItem, 0xEE) @0x66A end = 0x758; ctor 0x633D50 constructs the embedded CItem so SetItem is safe.
		["InventoryHistoryIcon"] =     { ["constructor"] = 0x633D50, ["size"] = 0x758 },
	},

	["controlOverrides"] = {
		["GUIW08"] = {
			[23] = {
				[0] = "ButtonWorldContainerSlot",
				[1] = "ButtonWorldContainerSlot",
				[2] = "ButtonWorldContainerSlot",
				[3] = "ButtonWorldContainerSlot",
				[4] = "ButtonWorldContainerSlot",
				[5] = "ButtonWorldContainerSlot",
				[6] = "ButtonWorldContainerSlot",
				[7] = "ButtonWorldContainerSlot",
				[8] = "ButtonWorldContainerSlot",
				[9] = "ButtonWorldContainerSlot",
			},
		},
		["GUIW10"] = {
			[23] = {
				[0] = "ButtonWorldContainerSlot",
				[1] = "ButtonWorldContainerSlot",
				[2] = "ButtonWorldContainerSlot",
				[3] = "ButtonWorldContainerSlot",
				[4] = "ButtonWorldContainerSlot",
				[5] = "ButtonWorldContainerSlot",
				[6] = "ButtonWorldContainerSlot",
				[7] = "ButtonWorldContainerSlot",
				[8] = "ButtonWorldContainerSlot",
				[9] = "ButtonWorldContainerSlot",
			},
		},
	},
})

function IEex_AddControlOverride(resref, panelID, controlID, controlType)
	IEex_Helper_SetBridge("IEex_GUIConstants", "controlOverrides", resref, panelID, controlID, controlType)
end

function IEex_DefineCustomControl(controlName, controlStructType, args)

	local newVFTable

	local fillVFTableDefaults = function(vftableSize, vftableAddress)
		newVFTable = IEex_Malloc(vftableSize)
		local currentFillAddress = newVFTable
		for i = vftableAddress, vftableAddress + vftableSize - 0x4, 0x4 do
			IEex_WriteDword(currentFillAddress, IEex_ReadDword(i))
			currentFillAddress = currentFillAddress + 0x4
		end
	end

	local structSize
	local newConstructor

	if controlStructType == IEex_ControlStructType.BUTTON then

		fillVFTableDefaults(0x78, 0x84C984)
		IEex_WriteArgs(newVFTable, args, {
			{ "OnLButtonClick", 0x68, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
			{ "OnLButtonDoubleClick", 0x6C, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		})

		structSize = 0x666
		newConstructor = IEex_WriteAssemblyAuto({[[
			!push_esi
			!mov_esi_ecx
			!push_byte 01 ; bInvalidatePanel ;
			!push_byte 01 ; bButtonActive ;
			!push_[esp+byte] 14 ; pControlInfo ;
			!push_[esp+byte] 14 ; pPanel ;
			!mov_ecx_esi
			!call :4D47D0 ; CUIControlButton_Construct ;
			!mov_[esi]_dword ]], {newVFTable, 4}, [[
			!mov_eax_esi
			!pop_esi
			!ret_word 08 00
		]]})

	elseif controlStructType == IEex_ControlStructType.LABEL then

		fillVFTableDefaults(0x68, 0x84CCD4)

		structSize = 0x560
		newConstructor = IEex_WriteAssemblyAuto({[[
			!mark_esp
			!push(esi)
			!mov(esi,ecx)
			!marked_esp !push([esp+8]) ; pControlInfo ;
			!marked_esp !push([esp+4]) ; pPanel ;
			!mov(ecx,esi)
			!call :4E4000 ; CUIControlLabel_Construct ;
			!mov([esi],$1) ]], {newVFTable}, [[
			!mov(eax,esi)
			!pop(esi)
			!ret(8)
		]]})

	elseif controlStructType == IEex_ControlStructType.TEXT_AREA then

		fillVFTableDefaults(0x78, 0x84CC5C)

		structSize = 0xAB8
		newConstructor = IEex_WriteAssemblyAuto({[[
			!mark_esp
			!push(esi)
			!mov(esi,ecx)
			!push(1) ; bInitStringsList ;
			!marked_esp !push([esp+8]) ; pControlInfo ;
			!marked_esp !push([esp+4]) ; pPanel ;
			!mov(ecx,esi)
			!call :4E1A90 ; CUIControlTextDisplay_Construct ;
			!mov([esi],$1) ]], {newVFTable}, [[
			!mov(eax,esi)
			!pop(esi)
			!ret(8)
		]]})

	elseif controlStructType == IEex_ControlStructType.SCROLL_BAR then

		fillVFTableDefaults(0x84, 0x84CDB4)

		structSize = 0x14A
		newConstructor = IEex_WriteAssemblyAuto({[[
			!mark_esp
			!push(esi)
			!mov(esi,ecx)
			!marked_esp !push([esp+8]) ; pControlInfo ;
			!marked_esp !push([esp+4]) ; pPanel ;
			!mov(ecx,esi)
			!call :4E47C0 ; CUIControlTextDisplay_Construct ;
			!mov([esi],$1) ]], {newVFTable}, [[
			!mov(eax,esi)
			!pop(esi)
			!ret(8)
		]]})
	else
		IEex_Error("Unimplemented controlStructType")
	end

	IEex_WriteArgs(newVFTable, args, {
		{ "SetActive",               0x4,  IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "NeedMouseMove",           0x8,  IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnLButtonUp",             0xC,  IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "KillFocus",               0x10, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnMouseMove",             0x14, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnLButtonDown",           0x18, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnLButtonUpCoords",       0x1C, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnLButtonDblClk",         0x20, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnRButtonDown",           0x24, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnRButtonUp",             0x28, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "OnKeyDown",               0x2C, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "TimerAsynchronousUpdate", 0x30, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "ActivateToolTip",         0x4C, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "InvalidateRect",          0x50, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "TimerSynchronousUpdate",  0x54, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "Render",                  0x58, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "NeedRender",              0x64, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
	})

	IEex_Helper_SetBridge("IEex_GUIConstants", "controlTypeMeta", controlName, {
		["constructor"] = newConstructor,
		["size"] = structSize,
	})
end

IEex_ControlStructType = {
	["BUTTON"]     = 0,
	["UNKNOWN1"]   = 1,
	["SLIDER"]     = 2,
	["TEXT_FIELD"] = 3,
	["UNKNOWN2"]   = 4,
	["TEXT_AREA"]  = 5,
	["LABEL"]      = 6,
	["SCROLL_BAR"] = 7,
}

IEex_ControlStructTypeLength = {
	[IEex_ControlStructType.BUTTON]     = 0x20,
	[IEex_ControlStructType.UNKNOWN1]   = 0xE,
	[IEex_ControlStructType.SLIDER]     = 0x34,
	[IEex_ControlStructType.TEXT_FIELD] = 0x6A,
	[IEex_ControlStructType.UNKNOWN2]   = 0xE,
	[IEex_ControlStructType.TEXT_AREA]  = 0x2E,
	[IEex_ControlStructType.LABEL]      = 0x24,
	[IEex_ControlStructType.SCROLL_BAR] = 0x28,
}

function IEex_AddControlStToPanel(CUIPanel, UI_Control_st)
	IEex_Call(0x4D2AE0, {UI_Control_st}, CUIPanel, 0x0)
end

function IEex_AddControlToPanel(CUIPanel, args)

	-- HD UI (2x): the control ctor (CUIControlBase, 0x4D47D0+) doubles x/y/w/h ONLY when the panel's
	-- manager is in double-size mode. That is TRUE for the in-world HUD (engine field_4A2C 2x tier) but
	-- FALSE for the menus, which scale via a PRE-SCALED CHU instead. So in a menu our 1x-authored control
	-- coords would land at 1x inside the 2x layout (tiny / mis-placed custom controls). Pre-scale them x2
	-- here when the target manager is NOT double-size, so they match the 2x menu. The world manager IS
	-- double-size -> skip (the ctor doubles). Assets are 2x-authored, so they fill the scaled rects.
	if IEEX_HD_UI then
		local mgr = IEex_GetUIManagerFromPanel(CUIPanel)
		if mgr and mgr ~= 0 and IEex_ReadDword(mgr + 0xAA) == 0 then
			if args.x      then args.x      = args.x      * 2 end
			if args.y      then args.y      = args.y      * 2 end
			if args.width  then args.width  = args.width  * 2 end
			if args.height then args.height = args.height * 2 end
		end
	end

	local type = args.type
	if not type then IEex_Error("type must be defined") end

	local typeLength = IEex_ControlStructTypeLength[type]
	if not typeLength then IEex_Error("Invalid type") end

	local UI_Control_st = IEex_Malloc(typeLength)

	IEex_WriteArgs(UI_Control_st, args, {
		{ "id",           0x0, IEex_WriteType.WORD, IEex_WriteFailType.ERROR      },
		{ "bufferLength", 0x2, IEex_WriteType.WORD, IEex_WriteFailType.DEFAULT, 0 },
		{ "x",            0x4, IEex_WriteType.WORD, IEex_WriteFailType.DEFAULT, 0 },
		{ "y",            0x6, IEex_WriteType.WORD, IEex_WriteFailType.DEFAULT, 0 },
		{ "width",        0x8, IEex_WriteType.WORD, IEex_WriteFailType.DEFAULT, 0 },
		{ "height",       0xA, IEex_WriteType.WORD, IEex_WriteFailType.DEFAULT, 0 },
		{ "type",         0xC, IEex_WriteType.BYTE, IEex_WriteFailType.ERROR      },
		{ "unknown",      0xD, IEex_WriteType.BYTE, IEex_WriteFailType.DEFAULT, 0 },
	})

	if type == IEex_ControlStructType.BUTTON then
		IEex_WriteArgs(UI_Control_st, args, {
			{ "bam",              0xE,  IEex_WriteType.RESREF, IEex_WriteFailType.ERROR      },
			{ "sequence",         0x16, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "textFlags",        0x17, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "frameUnpressed",   0x18, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "textAnchorLeft",   0x19, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "framePressed",     0x1A, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "textAnchorRight",  0x1B, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "frameSelected",    0x1C, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "textAnchorTop",    0x1D, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "frameDisabled",    0x1E, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
			{ "textAnchorBottom", 0x1F, IEex_WriteType.BYTE,   IEex_WriteFailType.DEFAULT, 0 },
		})
	elseif type == IEex_ControlStructType.LABEL then
		IEex_WriteArgs(UI_Control_st, args, {
			{ "initialTextStrref", 0xE,  IEex_WriteType.DWORD,  IEex_WriteFailType.DEFAULT, -1       },
			{ "fontBam",           0x12, IEex_WriteType.RESREF, IEex_WriteFailType.ERROR             },
			{ "fontColor1",        0x1A, IEex_WriteType.DWORD,  IEex_WriteFailType.DEFAULT, 0xFFFFF6 },
			{ "fontColor2",        0x1E, IEex_WriteType.DWORD,  IEex_WriteFailType.DEFAULT, 0x0      },
			{ "textFlags",         0x22, IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0        },
		})
	elseif type == IEex_ControlStructType.TEXT_AREA then
		IEex_WriteArgs(UI_Control_st, args, {
			{ "fontBam",         0xE,  IEex_WriteType.RESREF, IEex_WriteFailType.ERROR                 },
			{ "fontBamInitials", 0x16, IEex_WriteType.RESREF, IEex_WriteFailType.DEFAULT, args.fontBam },
			{ "fontColor1",      0x1E, IEex_WriteType.DWORD,  IEex_WriteFailType.DEFAULT, 0xFFFFFF     },
			{ "fontColor2",      0x22, IEex_WriteType.DWORD,  IEex_WriteFailType.DEFAULT, 0xFFFFFF     },
			{ "fontColor3",      0x26, IEex_WriteType.DWORD,  IEex_WriteFailType.DEFAULT, 0x0          },
			{ "scrollbarID",     0x2A, IEex_WriteType.DWORD,  IEex_WriteFailType.ERROR                 },
		})
	elseif type == IEex_ControlStructType.SCROLL_BAR then
		IEex_WriteArgs(UI_Control_st, args, {
			{ "graphicsBam",             0xE,  IEex_WriteType.RESREF, IEex_WriteFailType.ERROR },
			{ "animationNumber",         0x16, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "upArrowFrameUnpressed",   0x18, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "upArrowFramePressed",     0x1A, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "downArrowFrameUnpressed", 0x1C, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "downArrowFramePressed",   0x1E, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "troughFrame",             0x20, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "sliderFrame",             0x22, IEex_WriteType.WORD,   IEex_WriteFailType.ERROR },
			{ "textAreaID",              0x24, IEex_WriteType.DWORD,  IEex_WriteFailType.ERROR },
		})
	else
		IEex_Error("type unimplemented")
	end

	IEex_AddControlStToPanel(CUIPanel, UI_Control_st)
	IEex_Free(UI_Control_st)

	local control = IEex_GetControlFromPanel(CUIPanel, args.id)

	IEex_WriteArgs(control, args, {
		{ "tooltipStrref",   0x3E, IEex_WriteType.DWORD, IEex_WriteFailType.NOTHING },
		{ "hotkeyHintIndex", 0x4A, IEex_WriteType.WORD,  IEex_WriteFailType.NOTHING },
	})

	local customHotkeyHintIndex = args["customHotkeyHintIndex"]
	if customHotkeyHintIndex ~= nil then
		IEex_SetControlCustomHotkeyHintIndex(control, customHotkeyHintIndex)
	end

	if type == IEex_ControlStructType.BUTTON then
		local playLButtonDownSound = args["playLButtonDownSound"]
		if playLButtonDownSound ~= nil then
			IEex_SetControlButtonPlayLButtonDownSound(control, playLButtonDownSound)
		end
	end
end

function IEex_ReadControlSt(UI_Control_st)

	local toReturn = {}

	IEex_FillArgs(toReturn, UI_Control_st, {
		{ "id",           0x0, IEex_ReadType.WORD },
		{ "bufferLength", 0x2, IEex_ReadType.WORD },
		{ "x",            0x4, IEex_ReadType.WORD },
		{ "y",            0x6, IEex_ReadType.WORD },
		{ "width",        0x8, IEex_ReadType.WORD },
		{ "height",       0xA, IEex_ReadType.WORD },
		{ "type",         0xC, IEex_ReadType.BYTE },
		{ "unknown",      0xD, IEex_ReadType.BYTE },
	})

	local type = toReturn.type
	if type == IEex_ControlStructType.BUTTON then
		IEex_FillArgs(toReturn, UI_Control_st, {
			{ "bam",              0xE,  IEex_ReadType.RESREF },
			{ "sequence",         0x16, IEex_ReadType.BYTE   },
			{ "textFlags",        0x17, IEex_ReadType.BYTE   },
			{ "frameUnpressed",   0x18, IEex_ReadType.BYTE   },
			{ "textAnchorLeft",   0x19, IEex_ReadType.BYTE   },
			{ "framePressed",     0x1A, IEex_ReadType.BYTE   },
			{ "textAnchorRight",  0x1B, IEex_ReadType.BYTE   },
			{ "frameSelected",    0x1C, IEex_ReadType.BYTE   },
			{ "textAnchorTop",    0x1D, IEex_ReadType.BYTE   },
			{ "frameDisabled",    0x1E, IEex_ReadType.BYTE   },
			{ "textAnchorBottom", 0x1F, IEex_ReadType.BYTE   },
		})
	elseif type == IEex_ControlStructType.LABEL then
		IEex_FillArgs(toReturn, UI_Control_st, {
			{ "initialTextStrref", 0xE,  IEex_ReadType.DWORD  },
			{ "fontBam",           0x12, IEex_ReadType.RESREF },
			{ "fontColor1",        0x1A, IEex_ReadType.DWORD  },
			{ "fontColor2",        0x1E, IEex_ReadType.DWORD  },
			{ "textFlags",         0x22, IEex_ReadType.WORD   },
		})
	elseif type == IEex_ControlStructType.TEXT_AREA then
		IEex_FillArgs(toReturn, UI_Control_st, {
			{ "fontBam",         0xE,  IEex_ReadType.RESREF },
			{ "fontBamInitials", 0x16, IEex_ReadType.RESREF },
			{ "fontColor1",      0x1E, IEex_ReadType.DWORD  },
			{ "fontColor2",      0x22, IEex_ReadType.DWORD  },
			{ "fontColor3",      0x26, IEex_ReadType.DWORD  },
			{ "scrollbarID",     0x2A, IEex_ReadType.DWORD  },
		})
	elseif type == IEex_ControlStructType.SCROLL_BAR then
		IEex_FillArgs(toReturn, UI_Control_st, {
			{ "graphicsBam",             0xE  },
			{ "animationNumber",         0x16 },
			{ "upArrowFrameUnpressed",   0x18 },
			{ "upArrowFramePressed",     0x1A },
			{ "downArrowFrameUnpressed", 0x1C },
			{ "downArrowFramePressed",   0x1E },
			{ "troughFrame",             0x20 },
			{ "sliderFrame",             0x22 },
			{ "textAreaID",              0x24 },
		})
	else
		IEex_Error("type unimplemented")
	end

	return toReturn
end

function IEex_AddPanelToEngine(CBaldurEngine, args)

	-- HD UI (2x): same as IEex_AddControlToPanel -- the CUIPanel ctor (0x4D2750) doubles x/y/w/h only when
	-- the engine's manager is double-size (in-world HUD, field_4A2C). Menus use a pre-scaled CHU (manager
	-- NOT double-size), so pre-scale our 1x panel args x2 there to match the 2x layout. World -> skip.
	if IEEX_HD_UI then
		local mgr = IEex_GetUIManagerFromEngine(CBaldurEngine)
		if mgr and mgr ~= 0 and IEex_ReadDword(mgr + 0xAA) == 0 then
			if args.x      then args.x      = args.x      * 2 end
			if args.y      then args.y      = args.y      * 2 end
			if args.width  then args.width  = args.width  * 2 end
			if args.height then args.height = args.height * 2 end
		end
	end

	local UI_PanelHeader_st = IEex_Malloc(0x1C)
	IEex_WriteArgs(UI_PanelHeader_st, args, {
		{ "id",                0x0,  IEex_WriteType.DWORD,  IEex_WriteFailType.ERROR       },
		{ "x",                 0x4,  IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "y",                 0x6,  IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "width",             0x8,  IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "height",            0xA,  IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "hasBackground",     0xC,  IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "numControls",       0xE,  IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "backgroundImage",   0x10, IEex_WriteType.RESREF, IEex_WriteFailType.DEFAULT, "" },
		{ "firstControlIndex", 0x18, IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
		{ "flags",             0x1A, IEex_WriteType.WORD,   IEex_WriteFailType.DEFAULT, 0  },
	})

	local CUIPanel = IEex_Malloc(0x12A)
	local uiManager = IEex_GetUIManagerFromEngine(CBaldurEngine)
	IEex_Call(0x4D2750, {UI_PanelHeader_st, uiManager}, CUIPanel, 0x0) -- CUIPanel_Construct()
	IEex_Call(0x7FBE4E, {CUIPanel}, uiManager + 0xAE, 0x0) -- CPtrList_AddTail()

	IEex_Free(UI_PanelHeader_st)
	return CUIPanel
end

----------------------------------------
-- General Custom UI Control Handlers --
----------------------------------------

------------------
-- Thread: Sync --
------------------

-- Static controlID -> {portraitI, indicatorI} map for the action indicator panel
-- (control i*3 + slot). Built once so the per-frame render callback allocates
-- nothing.
IEex_ActionIndicators_RenderMap = {}
for _aiControlID = 0, 17 do
	IEex_ActionIndicators_RenderMap[_aiControlID] = { math.floor(_aiControlID / 3), _aiControlID % 3 }
end

-- Thread: Sync (render thread). The engine calls this for EVERY IEex_UI_Button
-- control EVERY frame; the world action-indicator panel alone has 18 of them.
-- The previous version rebuilt an 18-closure dispatch table + 2 wrapper tables on
-- every single call -- ~20 allocations x (18 indicator controls + every other
-- IEex_UI_Button in the UI) x frame-rate -> a GC storm on the render thread that
-- cost ~40% fps while the panel was shown (measured 118 -> 70 fps walking a party).
-- Now: index a precomputed map, and only the drawn (active) controls allocate the
-- single icon list they actually render. Non-indicator controls fall straight
-- through to the engine renderer exactly as before.
function IEex_Extern_UI_ButtonRender(CUIControlButton, bForceRender)

	IEex_AssertThread(IEex_Thread.Sync, true)

	local panel = IEex_GetControlPanel(CUIControlButton)
	local resref = IEex_GetCHUResrefFromPanel(panel)
	local panelID = IEex_GetPanelID(panel)
	local controlID = IEex_GetControlID(CUIControlButton)

	local indicator = (panelID == IEex_ActionIndicatorsPanelID and (resref == "GUIW08" or resref == "GUIW10"))
		and IEex_ActionIndicators_RenderMap[controlID]
		or nil

	if indicator
		and IEex_IsControlActiveForRender(CUIControlButton)
		and IEex_ShouldControlButtonRender(CUIControlButton, bForceRender)
	then
		IEex_Helper_DecrementButtonDoRender(CUIControlButton)
		local portraitI = indicator[1]
		local sprite = IEex_GetActorShare(IEex_GetActorIDPortrait(portraitI))
		if IEex_IsObjectSprite(sprite) then
			local iconsDataBridge = IEex_Helper_GetBridge("IEex_ActionIndicators", portraitI, indicator[2])
			if iconsDataBridge ~= nil then
				local iconsData = IEex_Helper_ReadDataFromBridge(iconsDataBridge)
				-- HD UI (2x): explicit icon dims/offsets are 1x, but the control (m_size) is already 2x,
				-- so a 1x bounding box centers a tiny icon in the 2x slot. Scale the explicit values so the
				-- icon fills the slot; the controlW/controlH fallback is already 2x -> leave it.
				local hiScale = (IEEX_HD_UI and IEex_ReadDword(IEex_GetUIManagerFromPanel(panel) + 0xAA) ~= 0) and 2 or 1
				local _, _, controlW, controlH = IEex_GetControlArea(CUIControlButton)
				for _, iconData in ipairs(iconsData) do
					IEex_Helper_RenderButtonIcon(CUIControlButton, iconData[1], iconData[2], iconData[3],
						iconData[4] and iconData[4] * hiScale or controlW,
						iconData[5] and iconData[5] * hiScale or controlH,
						(iconData[6] or 0) * hiScale, (iconData[7] or 0) * hiScale)
				end
			end
		end
		return
	end

	IEex_Call(0x4D5070, {bForceRender}, CUIControlButton, 0x0) -- CUIControlButton_Render()
end

-------------------
-- Thread: Async --
-------------------

function IEex_Extern_UI_ButtonLClick(CUIControlButton)

	IEex_AssertThread(IEex_Thread.Async, true)

	local panel = IEex_GetControlPanel(CUIControlButton)
	local resref = IEex_GetCHUResrefFromPanel(panel)
	local panelID = IEex_GetPanelID(panel)
	local controlID = IEex_GetControlID(CUIControlButton)

	local trySetPanelEnabled = function(panel, enabled)
		if panel ~= 0x0 then
			IEex_SetPanelEnabled(panel, enabled)
		end
	end

	local setCommonPanelsEnabled = function(engine, enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -2), enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -3), enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -4), enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -5), enabled)
		IEex_SetPanelEnabled(IEex_GetPanelFromEngine(engine, 0), enabled)
		IEex_SetPanelEnabled(IEex_GetPanelFromEngine(engine, 1), enabled)
		IEex_SetPanelEnabled(IEex_GetPanelFromEngine(engine, 2), enabled)
	end

	-- Open/close the IEex options panel (14) over its parent (the in-game main options panel 2, or the
	-- main-menu options popup 13). Shared so both "IEex Options" buttons behave identically; the parent
	-- is remembered in IEex_OptionsParentPanelID so Done/Cancel restore the right one.
	local openIEexOptions = function(parentPanelID)
		IEex_OptionsParentPanelID = parentPanelID
		IEex_InitOptionButtons()
		-- Copy current options to working temp
		IEex_Helper_SetBridge("IEex_Options", "workingOptions", IEex_Helper_GetBridge("IEex_Options", "options"))

		local screenOptions = IEex_GetEngineOptions()
		local parentPanel = IEex_GetPanelFromEngine(screenOptions, parentPanelID)
		local newOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 14)

		-- Add to popup stack
		IEex_Call(0x7FBE4E, {newOptionsPanel}, screenOptions + 0x434, 0x0) -- CPtrList_AddTail()

		local parentX, parentY, _, _ = IEex_GetPanelArea(parentPanel)
		setCommonPanelsEnabled(screenOptions, false)
		IEex_SetPanelEnabled(parentPanel, false)
		IEex_SetPanelXY(newOptionsPanel, parentX, parentY)
		IEex_SetPanelActive(newOptionsPanel, true)
		IEex_SetEngineScrollbarFocus(screenOptions, IEex_GetControlFromPanel(newOptionsPanel, 4))
		IEex_PanelInvalidate(newOptionsPanel)
	end

	local closeIEexOptions = function()
		local screenOptions = IEex_GetEngineOptions()
		local parentPanel = IEex_GetPanelFromEngine(screenOptions, IEex_OptionsParentPanelID)
		local newOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 14)

		-- Remove from popup stack
		IEex_Call(0x7FB343, {}, screenOptions + 0x434, 0x0) -- CPtrList_RemoveTail()

		IEex_SetPanelActive(newOptionsPanel, false)
		setCommonPanelsEnabled(screenOptions, true)
		IEex_SetPanelEnabled(parentPanel, true)
	end

	local worldHandler = {
		[0] = {
			[15] = IEex_CScreenWorld_OnQuicklootButtonLClick,
			[16] = IEex_Refonte_CycleLogHeight,   -- invisible full-width strip on the log's top border
			[17] = IEex_Refonte_CycleLogHeight,   -- the VISIBLE tab on the same border (same action)
		},
--[[
		[22] = {
			[15] = IEex_CScreenWorld_OnQuicklootButtonLClick,
		},
--]]
		[IEex_WorldScreenSpellInfoPanelID] = {
			[5] = IEex_StopWorldScreenSpellInfo,
		},
		[IEex_WorldScreenItemInfoPanelID] = {
			[5] = IEex_StopWorldScreenSpellInfo,   -- shared closer: hides whichever info panel is open
		}
	}

	local handlers = {
		["GUICG"] = {
			[4] = {
				[37] = function()
					IEex_Chargen_Reroll()
				end,
				[38] = function()
					local chargenData = IEex_GetEngineCreateChar()
					local share = IEex_GetActorShare(IEex_ReadDword(chargenData + 0x4E2))
					recordedAbilityScores = currentAbilityScores
					recordedUnallocatedAbilityScores = unallocatedAbilityScores
					if ex_new_ability_score_system == 2 then
						ex_recorded_remaining_points = IEex_ReadDword(chargenData + 0x4EA)
					end
					IEex_Chargen_UpdateAbilityScores(chargenData, share)
				end,
				[39] = function()
					local chargenData = IEex_GetEngineCreateChar()
					local share = IEex_GetActorShare(IEex_ReadDword(chargenData + 0x4E2))
					if (recordedAbilityScores[1] > 0 or #recordedUnallocatedAbilityScores > 0) then
						currentAbilityScores = recordedAbilityScores
						unallocatedAbilityScores = recordedUnallocatedAbilityScores
						for i = 1, 6, 1 do
							IEex_WriteByte(share + ex_base_ability_score_cre_offset[i], currentAbilityScores[i])
						end
						if ex_new_ability_score_system == 2 then
							ex_current_remaining_points = ex_recorded_remaining_points
							IEex_WriteDword(chargenData + 0x4EA, ex_current_remaining_points)
						end
					end
					IEex_Chargen_UpdateAbilityScores(chargenData, share)
				end,
				[40] = function()
					local chargenData = IEex_GetEngineCreateChar()
					local share = IEex_GetActorShare(IEex_ReadDword(chargenData + 0x4E2))
					if ex_new_ability_score_system == 1 then
						for i = 1, 6, 1 do
							if currentAbilityScores[i] > 0 then
								table.insert(unallocatedAbilityScores, currentAbilityScores[i] - racialAbilityBonuses[i])
								IEex_WriteByte(share + ex_base_ability_score_cre_offset[i], 0)
--								currentAbilityScores[i] = 0
							end
							table.sort(unallocatedAbilityScores)
						end
					end
					IEex_Chargen_UpdateAbilityScores(chargenData, share)
				end,
			},
		},
		["GUIOPT"] = {
			[2] = {
				-- "IEex Options" Button (in-game main options panel)
				[15] = function() openIEexOptions(2) end,
			},
			[13] = {
				-- "IEex Options" Button (main-menu options popup)
				[15] = function() openIEexOptions(13) end,
			},
			[14] = {
				-- "Done" Button
				[1] = function()

					-- Save (copy) working temp back to options. This invalidates IEex_FogTypePtr,
					-- as the original "options->transparentFogOfWar" is replaced during the copy.
					-- Lock access to this ptr, update it, and unlock to maintain valid state.
					IEex_Helper_LockGlobal("IEex_Options")
					IEex_Helper_SetBridge("IEex_Options", "options", IEex_Helper_GetBridge("IEex_Options", "workingOptions"))
					IEex_WriteDword(IEex_FogTypePtr, IEex_Helper_GetBridgePtr("IEex_Options", "options", "transparentFogOfWar"))
					IEex_Helper_UnlockGlobal("IEex_Options")

					if not IEex_Helper_GetBridge("IEex_Options", "options", "actionIndicators") then
						IEex_ActionIndicators_Hide()
					end

					IEex_WriteOptions()

					-- Marker colour/thickness live-apply: the helper caches its [IEex Options]
					-- keys on first use, so drop the cache now that the ini has been rewritten.
					-- Also picks up the ini-only marker keys (thickness, portrait rings, colour
					-- slot, brightness floor) on the next open/close of this panel.
					if IEex_Helper_SetMarkerStyle then IEex_Helper_SetMarkerStyle() end

					closeIEexOptions()
				end,
				-- "Cancel" Button
				[2] = function()
					closeIEexOptions()
				end,
				-- "Transparent Fog of War" Toggle
				[6] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "transparentFogOfWar") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "transparentFogOfWar", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "transparentFogOfWar", true)
					end
				end,
				-- "Action Indicators" Toggle
				[8] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "actionIndicators") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "actionIndicators", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "actionIndicators", true)
					end
				end,
				-- "Highlight Empty Containers in Gray" Toggle
				[10] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "highlightEmptyContainersInGray") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "highlightEmptyContainersInGray", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "highlightEmptyContainersInGray", true)
					end
				end,
				-- "Prevent Equipping Armor During Combat" Toggle
				[12] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "preventEquippingArmorDuringCombat") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "preventEquippingArmorDuringCombat", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "preventEquippingArmorDuringCombat", true)
					end
				end,
				-- "Stretch UI to Screen" Toggle
				[14] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "stretchUI") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "stretchUI", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "stretchUI", true)
					end
				end,
				-- "Pixel-Perfect Zoom" Toggle
				[30] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "integerZoom") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "integerZoom", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "integerZoom", true)
					end
				end,
				-- "Show FPS" Toggle
				[16] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "showFps") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "showFps", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "showFps", true)
					end
				end,
				-- "Vsync" Toggle
				[18] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "vsync") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "vsync", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "vsync", true)
					end
				end,
				-- "UI Borders" Toggle
				[20] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "uiBorders") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "uiBorders", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "uiBorders", true)
					end
				end,
				-- "Improved Pathfinding" Toggle
				[22] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "improvedPathfinding") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "improvedPathfinding", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "improvedPathfinding", true)
					end
				end,
				-- "Colored Portrait Frames" Toggle
				[24] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "coloredPortraitFrames") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "coloredPortraitFrames", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "coloredPortraitFrames", true)
						-- The frame tint DEPENDS on the circle tint, and structurally so: the engine
						-- reads the marker colour for the frame only while a portrait is hovered, so
						-- with the circles off the frame would be tinted at rest and vanilla green
						-- under the cursor. Both ship off, so turning this on alone would otherwise
						-- do visibly nothing -- switch the circles on with it, and repaint their
						-- toggle so the panel doesn't lie about what just changed.
						if not IEex_Helper_GetBridge(workingOptions, "coloredCircles") then
							IEex_Helper_SetBridge(workingOptions, "coloredCircles", true)
							local circlesToggle = IEex_GetControlFromPanel(
								IEex_GetPanelFromEngine(IEex_GetEngineOptions(), 14), 28)
							if circlesToggle then IEex_SetControlButtonFrameUpForce(circlesToggle, 3) end
						end
					end
				end,
				-- "Colored Selection Circles" Toggle
				[28] = function()
					local workingOptions = IEex_Helper_GetBridge("IEex_Options", "workingOptions")
					if IEex_Helper_GetBridge(workingOptions, "coloredCircles") then
						IEex_SetControlButtonFrameUp(CUIControlButton, 1)
						IEex_Helper_SetBridge(workingOptions, "coloredCircles", false)
					else
						IEex_SetControlButtonFrameUp(CUIControlButton, 3)
						IEex_Helper_SetBridge(workingOptions, "coloredCircles", true)
					end
				end,
			},
		},
		["GUIREC"] = {
			[2] = {
				[38] = function()
					if ex_current_record_actorID ~= IEex_GetActorIDCharacter(0) and ex_current_record_actorID ~= 0 then
						IEex_WriteWord(IEex_GetActorShare(ex_current_record_actorID) + 0x476, 21)
					end
				end,
			},
			[58] = {
				[32] = function()
					local screenCharacter = IEex_GetEngineCharacter()
					local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
					for buttonID = 0, 29, 1 do
						local thisButton = IEex_GetControlFromPanel(newWizardSpellsPanel, buttonID)
						IEex_SetControlButtonFrameUpForce(thisButton, 1)
					end
					ex_menu_sorcerer_spells_replaced = {}
					for spellRES, justTaken in pairs(ex_menu_wizard_spells_learned) do
						if justTaken then
							ex_menu_wizard_spells_learned[spellRES] = nil
							ex_menu_num_wizard_spells_remaining = ex_menu_num_wizard_spells_remaining + 1
						end
					end
					ex_menu_num_learned_spells_per_level = {0, 0, 0, 0, 0, 0, 0, 0, 0}
					IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 34), tostring(ex_menu_num_wizard_spells_remaining))
					ex_menu_in_second_replacement_step = false
					IEex_DisplayWizardSpellsToLearn(ex_current_menu_spell_level)
					IEex_NewWizardSpellsPanelDoneButtonUpdate()
					IEex_PanelInvalidate(newWizardSpellsPanel)
				end,
				[35] = function()
					if IEex_NewWizardSpellsPanelDoneButtonClickable() then
						local screenCharacter = IEex_GetEngineCharacter()
						local characterRecordPanel = IEex_GetPanelFromEngine(screenCharacter, 2)
						local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
						local actorID = IEex_ReadDword(screenCharacter + 0x136)
						if not IEex_IsSprite(actorID, false) then return end

						-- Remove from popup stack
						IEex_Call(0x7FB343, {}, screenCharacter + 0x62A, 0x0) -- CPtrList_RemoveTail()

						IEex_SetPanelActive(newWizardSpellsPanel, false)
						setCommonPanelsEnabled(screenCharacter, true)
						IEex_SetPanelEnabled(characterRecordPanel, true)
						if ex_alternate_spell_menu_class == 11 then
							for spellRES, justTaken in pairs(ex_menu_wizard_spells_learned) do
								if justTaken then
									IEex_ApplyEffectToActor(actorID, {
["opcode"] = 147,
["target"] = 2,
["timing"] = 1,
["resource"] = spellRES,
["source_id"] = actorID
})
								end
							end
						elseif ex_alternate_spell_menu_class == 2 or ex_alternate_spell_menu_class == 10 then
							local share = IEex_GetActorShare(actorID)
							local casterType = IEex_CasterClassToType[ex_alternate_spell_menu_class]
							local currentLevelBase = share + 0x4284 + (casterType - 1) * 0x100
							for level = 1, ex_menu_max_castable_level, 1 do
								local currentEntryBase = IEex_ReadDword(currentLevelBase + 0x4)
								local pEndEntry = IEex_ReadDword(currentLevelBase + 0x8)
								while currentEntryBase ~= pEndEntry do
									local spellRES = IEex_LISTSPLL[IEex_ReadDword(currentEntryBase)]
									if ex_menu_sorcerer_spells_replaced[spellRES] then
										IEex_WriteDword(currentEntryBase,IEex_LISTSPLL_Reverse[ex_menu_sorcerer_spells_replaced[spellRES]])
										for i = 0x360C, 0x37EC, 0x3C do
											if IEex_ReadLString(share + i + 0x20, 8) == spellRES and IEex_ReadByte(share + i + 0x36, 0x0) == ex_alternate_spell_menu_class then
												IEex_WriteLString(share + i, string.sub(ex_menu_sorcerer_spells_replaced[spellRES], 1, 7) .. "B", 8)
												IEex_WriteLString(share + i + 0x20, ex_menu_sorcerer_spells_replaced[spellRES], 8)
											end
										end
									end
									currentEntryBase = currentEntryBase + 0x10
								end
								currentLevelBase = currentLevelBase + 0x1C
							end
						end
					end
				end,
				[36] = function()
					local screenCharacter = IEex_GetEngineCharacter()
					local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
					if ex_current_menu_spell_level > 1 and not ex_menu_in_second_replacement_step then
						ex_current_menu_spell_level = ex_current_menu_spell_level - 1
						IEex_DisplayWizardSpellsToLearn(ex_current_menu_spell_level)
						if ex_alternate_spell_menu_class == 11 then
							for buttonID = 0, 29, 1 do
								local thisButton = IEex_GetControlFromPanel(newWizardSpellsPanel, buttonID)
								local spellResref = ex_menu_available_wizard_spells[ex_current_menu_spell_level][buttonID + 1]
								if not ex_menu_wizard_spells_learned[spellResref] then
									IEex_SetControlButtonFrameUpForce(thisButton, 1)
								else
									IEex_SetControlButtonFrameUpForce(thisButton, 0)
								end
							end
						end
					end
					IEex_PanelInvalidate(newWizardSpellsPanel)
				end,
				[37] = function()
					local screenCharacter = IEex_GetEngineCharacter()
					local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
					local actorID = IEex_ReadDword(screenCharacter + 0x136)
					if not IEex_IsSprite(actorID, false) then return end
					if ex_current_menu_spell_level < ex_menu_max_castable_level and not ex_menu_in_second_replacement_step then
						ex_current_menu_spell_level = ex_current_menu_spell_level + 1
						IEex_DisplayWizardSpellsToLearn(ex_current_menu_spell_level)
						if ex_alternate_spell_menu_class == 11 then
							for buttonID = 0, 29, 1 do
								local thisButton = IEex_GetControlFromPanel(newWizardSpellsPanel, buttonID)
								local spellResref = ex_menu_available_wizard_spells[ex_current_menu_spell_level][buttonID + 1]
								if not ex_menu_wizard_spells_learned[spellResref] then
									IEex_SetControlButtonFrameUpForce(thisButton, 1)
								else
									IEex_SetControlButtonFrameUpForce(thisButton, 0)
								end
							end
						end
					end
--					local thisButton = IEex_GetControlFromPanel(newWizardSpellsPanel, 0)
--					IEex_SetControlButtonFrameUpForce(thisButton, 2)
--[[
					-- Remove from popup stack
					IEex_Call(0x7FB343, {}, screenCharacter + 0x62A, 0x0) -- CPtrList_RemoveTail()

					-- Add to popup stack
					IEex_Call(0x7FBE4E, {newWizardSpellsPanel}, screenCharacter + 0x62A, 0x0) -- CPtrList_AddTail()
--]]
					IEex_PanelInvalidate(newWizardSpellsPanel)
				end,
			},
		},
		["GUIW08"] = worldHandler,
		["GUIW10"] = worldHandler,
	}

	for buttonID = 0, 29, 1 do
		handlers["GUIREC"][58][buttonID] = function()
			local screenCharacter = IEex_GetEngineCharacter()
			local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
			local thisButton = IEex_GetControlFromPanel(newWizardSpellsPanel, buttonID)
			local spellResref = ""
			if ex_alternate_spell_menu_class == 11 then
				spellResref = ex_menu_available_wizard_spells[ex_current_menu_spell_level][buttonID + 1]
			elseif ex_alternate_spell_menu_class == 2 or ex_alternate_spell_menu_class == 10 then
				if not ex_menu_in_second_replacement_step then
					local i = 0
					for spellRES, isKnown in pairs(ex_menu_known_wizard_spells[ex_current_menu_spell_level]) do
						if i == buttonID then
							if not ex_menu_sorcerer_spells_replaced[spellRES] then
								spellResref = spellRES
							else
								spellResref = ex_menu_sorcerer_spells_replaced[spellRES]
							end
						end
						i = i + 1
					end
				else
					spellResref = ex_menu_available_wizard_spells[ex_current_menu_spell_level][buttonID + 1]
					if ex_menu_wizard_spells_learned[spellResref] then
						spellResref = ""
					end
				end
			end
			if not spellResref then return end
			local spellWrapper = IEex_DemandRes(spellResref, "SPL")
			if not spellWrapper:isValid() then
				spellWrapper:free()
				return
			end
			local descTextDisplay = IEex_GetControlFromPanel(newWizardSpellsPanel, 30)
			if ex_alternate_spell_menu_class == 11 then
				if not ex_menu_wizard_spells_learned[spellResref] then
					if (ex_menu_num_known_spells_per_level[ex_current_menu_spell_level] + ex_menu_num_learned_spells_per_level[ex_current_menu_spell_level] + 1) > 24 then
						IEex_SetControlTextDisplay(descTextDisplay, IEex_FetchString(ex_tra_55771))
						spellWrapper:free()
						return
					elseif ex_menu_num_wizard_spells_remaining > 0 then
						ex_menu_wizard_spells_learned[spellResref] = true
						ex_menu_num_learned_spells_per_level[ex_current_menu_spell_level] = ex_menu_num_learned_spells_per_level[ex_current_menu_spell_level] + 1
						ex_menu_num_wizard_spells_remaining = ex_menu_num_wizard_spells_remaining - 1
						IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 34), tostring(ex_menu_num_wizard_spells_remaining))
						IEex_SetControlButtonFrameUp(thisButton, 0)
					end
				else
					ex_menu_wizard_spells_learned[spellResref] = nil
					ex_menu_num_learned_spells_per_level[ex_current_menu_spell_level] = ex_menu_num_learned_spells_per_level[ex_current_menu_spell_level] - 1
					ex_menu_num_wizard_spells_remaining = ex_menu_num_wizard_spells_remaining + 1
					IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 34), tostring(ex_menu_num_wizard_spells_remaining))
					IEex_SetControlButtonFrameUp(thisButton, 1)
				end
			elseif ex_alternate_spell_menu_class == 2 or ex_alternate_spell_menu_class == 10 then
				if not ex_menu_in_second_replacement_step then
					if not ex_menu_wizard_spells_learned[spellResref] then
						if ex_menu_num_wizard_spells_remaining > 0 then
							ex_menu_sorcerer_spell_to_replace = spellResref
							ex_menu_in_second_replacement_step = true
							IEex_DisplayWizardSpellsToLearn(ex_current_menu_spell_level)
						end
					else
						for spellRES, replacementRES in pairs(ex_menu_sorcerer_spells_replaced) do
							if replacementRES == spellResref then
								ex_menu_sorcerer_spells_replaced[spellRES] = nil
								ex_menu_wizard_spells_learned[spellResref] = nil
							end
						end
						ex_menu_num_wizard_spells_remaining = ex_menu_num_wizard_spells_remaining + 1
						IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 34), tostring(ex_menu_num_wizard_spells_remaining))
						IEex_SetControlButtonFrameUp(thisButton, 1)
						IEex_DisplayWizardSpellsToLearn(ex_current_menu_spell_level)
					end
				else
					ex_menu_wizard_spells_learned[spellResref] = true
					ex_menu_sorcerer_spells_replaced[ex_menu_sorcerer_spell_to_replace] = spellResref
					ex_menu_sorcerer_spell_to_replace = ""
					ex_menu_num_wizard_spells_remaining = ex_menu_num_wizard_spells_remaining - 1
					IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 34), tostring(ex_menu_num_wizard_spells_remaining))
					ex_menu_in_second_replacement_step = false
					IEex_DisplayWizardSpellsToLearn(ex_current_menu_spell_level)
				end
			end
--[[
			if IEex_GetControlButtonFrameUp(thisButton) == 0 then
				IEex_SetControlButtonFrameUp(thisButton, 1)
			else
				IEex_SetControlButtonFrameUp(thisButton, 0)
			end
--]]
			local spellData = spellWrapper:getData()
--			local spellName = IEex_FetchString(IEex_ReadDword(spellData + 0x8))
			local spellDesc = IEex_FetchString(IEex_ReadDword(spellData + 0x50))
			spellWrapper:free()

			IEex_SetControlTextDisplay(descTextDisplay, spellDesc)
			IEex_NewWizardSpellsPanelDoneButtonUpdate()
			IEex_PanelInvalidate(newWizardSpellsPanel)
		end
	end

	local resrefHandler = handlers[resref]
	if not resrefHandler then return end
	local panelHandler = resrefHandler[panelID]
	if not panelHandler then return end
	local controlHandler = panelHandler[controlID]
	if controlHandler then
		controlHandler()
	end

	-- Also show the option's description when its TOGGLE is pressed (not only when the label text is
	-- clicked) -- toggle id N maps to label id N-1. No-op for non-option buttons (Done/Cancel -> ids
	-- 0/1, absent from the table) and other screens. Ensures players see descriptions just by toggling.
	if resref == "GUIOPT" and panelID == 14 then
		IEex_SetOptionDescription(controlID - 1)
	end
end

-- Shared option-description lookup -> renders into the IEex Options description area (panel 14,
-- control 3). Keyed by LABEL id (= toggle id - 1). Called from BOTH the label-click handler
-- (IEex_Extern_UI_LabelLDown) and each toggle handler, so the description shows whether the player
-- clicks the option's text OR flips its toggle (most players never discover the click-the-label UX).
-- A number value is a TRA strref (resolved via IEex_FetchString); a string is used inline.
function IEex_SetOptionDescription(labelId)
	local descriptions = {
		[5]  = ex_tra_55903,
		[7]  = ex_tra_55906,
		[9]  = ex_tra_55908,
		[11] = ex_tra_55932,
		[13] = IEex_OptionText(ex_tra_56080, "Stretches the interface to fill the entire screen. When off, the UI renders at its native size with letterboxed black borders (crisper); when on, it is scaled up to fill the display (larger, but slightly softer)."),
		[15] = IEex_OptionText(ex_tra_56082, "Displays an on-screen counter showing the render framerate, the AI (game-logic) update rate, and the VRAM pool usage."),
		[17] = IEex_OptionText(ex_tra_56084, "Synchronizes frame presentation with your monitor's refresh rate to eliminate screen tearing."),
		[19] = IEex_OptionText(ex_tra_56086, "Adds decorative stone borders around the interface: the frame around the in-game HUD (command bar, world map, containers) plus the panels filling the empty margins at the screen edges (for example on widescreen displays). When off, the world shows through those margins. Requires a restart to take effect."),
		[21] = IEex_OptionText(ex_tra_56088, "GemRB-inspired pathfinding improvements: characters wait for walkers instead of shuffling, stop cleanly next to occupied destinations, no longer stop short of their goal, and enemies unclog doorways by shoving their own allies (never party members). Chasing a moving target keeps its path while the new one is computed, instead of standing still for the whole search -- that is what made a run to melee stop and start. Idle non-hostile NPCs can be shoved aside instead of walling off a corridor. Fine-tuning keys (IP *) live in icewind2.ini under [IEex Options]. Requires a restart to fully take effect."),
		[23] = IEex_OptionText(ex_tra_56078, "Tints the selection frame around each party portrait with that character's own secondary (minor clothing) color, matching the circle under their feet. Off by default, since BG2EE colors the ground circles and not the portrait frames. Requires \"Colored selection circles\" and switches it on with this option. The frame is a 1-pixel hairline unless \"Portrait Frame Thickness\" under [IEex Options] in Icewind2.ini says otherwise (1 to 4 pixels, or 0 to follow the selection circles); it never covers the portrait itself."),
		[27] = IEex_OptionText(ex_tra_56076, "Tints each party member's selection circle and move-destination marker with that character's own secondary (minor clothing) color instead of the vanilla green, the way BG2EE colors its party circles. On by default. Enemies stay red and neutrals cyan; a character who is talking stays white and a panicking one stays yellow. The party portraits keep their vanilla green frame unless \"Colored portrait frames\" is also on. Stroke widths are set under [IEex Options] in Icewind2.ini with \"Selection Circle Thickness\" (0 = automatic by resolution, the default, or 1 to 4 pixels) and \"Destination Marker Thickness\" (0 = one step lighter than the circles, the default); OpenGL only."),
		[29] = IEex_OptionText(ex_tra_56092, "Restricts the mouse-wheel zoom to whole-number levels (1x, 2x, 3x...), where every map pixel becomes an exact square block of screen pixels and the artwork stays as sharp as the original game. In between those levels the map is enlarged by a fraction, so some pixels are stretched wider than others and the image shimmers slightly while the camera moves. Fully zoomed out is always 1x, the original 1:1 presentation. The trade-off is coarser steps: with this on the wheel jumps straight from one whole level to the next instead of easing through the range. OpenGL only."),
	}
	local d = descriptions[labelId]
	if d == nil then return end
	IEex_SetTextAreaToString(IEex_GetEngineOptions(), 14, 3, type(d) == "number" and IEex_FetchString(d) or d)
end

function IEex_Extern_UI_LabelLDown(CUIControlLabel)

	IEex_AssertThread(IEex_Thread.Async, true)

	local panel = IEex_GetControlPanel(CUIControlLabel)
	local resref = IEex_GetCHUResrefFromPanel(panel)
	local panelID = IEex_GetPanelID(panel)
	local controlID = IEex_GetControlID(CUIControlLabel)

	local handlers = {
		["GUIOPT"] = {
			[14] = {
				[5]  = function() IEex_SetOptionDescription(5)  end,
				[7]  = function() IEex_SetOptionDescription(7)  end,
				[9]  = function() IEex_SetOptionDescription(9)  end,
				[11] = function() IEex_SetOptionDescription(11) end,
				[13] = function() IEex_SetOptionDescription(13) end,
				[15] = function() IEex_SetOptionDescription(15) end,
				[17] = function() IEex_SetOptionDescription(17) end,
				[19] = function() IEex_SetOptionDescription(19) end,
				[21] = function() IEex_SetOptionDescription(21) end,
				[23] = function() IEex_SetOptionDescription(23) end,
				[27] = function() IEex_SetOptionDescription(27) end,
				[29] = function() IEex_SetOptionDescription(29) end,
			},
		},
	}

	local resrefHandler = handlers[resref]
	if not resrefHandler then return end
	local panelHandler = resrefHandler[panelID]
	if not panelHandler then return end
	local controlHandler = panelHandler[controlID]
	if controlHandler then
		controlHandler()
	end
end

---------------------
-- Quickloot Hooks --
---------------------

-------------------
-- Thread: Async --
-------------------

function IEex_Extern_CScreenWorld_AsynchronousUpdate()

	IEex_AssertThread(IEex_Thread.Async, true)
	-- For some reason the main menu's options screen ticks this function
	if IEex_GetActiveEngine() ~= IEex_GetEngineWorld() then return end

	IEex_Quickloot_UpdateItems()
	IEex_ActionIndicators_Update()
end

function IEex_Extern_Quickloot_ScrollLeft()
	IEex_AssertThread(IEex_Thread.Async, true)
	IEex_Helper_SynchronizedBridgeOperation("IEex_Quickloot", function()
		local itemsAccessIndex = IEex_Helper_GetBridgeNL("IEex_Quickloot", "itemsAccessIndex")
		IEex_Helper_SetBridgeNL("IEex_Quickloot", "itemsAccessIndex", math.max(1, itemsAccessIndex - 10))
	end)
end

function IEex_Extern_Quickloot_ScrollRight()
	IEex_AssertThread(IEex_Thread.Async, true)
	IEex_Helper_SynchronizedBridgeOperation("IEex_Quickloot", function()
		local itemsAccessIndex = IEex_Helper_GetBridgeNL("IEex_Quickloot", "itemsAccessIndex")
		local maxIndex = math.max(1, IEex_Helper_GetBridgeNumIntsNL("IEex_Quickloot", "items") - 10 + 1)
		IEex_Helper_SetBridgeNL("IEex_Quickloot", "itemsAccessIndex", math.min(itemsAccessIndex + 10, maxIndex))
	end)
end

function IEex_Extern_CScreenWorld_OnInventoryButtonRClick()
	if true then return end
	IEex_AssertThread(IEex_Thread.Async, true)
	if IEex_Helper_GetBridge("IEex_Quickloot", "on") then
		IEex_Quickloot_Stop()
	else
		IEex_Quickloot_Start()
	end
end

function IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_Done(control)
	IEex_AssertThread(IEex_Thread.Async, true)
	IEex_Helper_SynchronizedBridgeOperation("IEex_Quickloot", function()
		local pendingItemsAccessChange = IEex_Helper_GetBridgeNL("IEex_Quickloot", "pendingItemsAccessChange") - 1
		IEex_Helper_SetBridgeNL("IEex_Quickloot", "pendingItemsAccessChange", pendingItemsAccessChange)
	end)
end

function IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot(control)
	IEex_AssertThread(IEex_Thread.Async, true)
	return IEex_Quickloot_IsControlOnPanel(control)
end

------------------
-- Thread: Both --
------------------

function IEex_Extern_GetHighlightContainerID()
	IEex_AssertThread(IEex_Thread.Both, true)
	return IEex_Helper_GetBridge("IEex_Quickloot", "highlightContainerID")
end

-- (Render->Sync, OnLClick->Async)
function IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerID(control)
	IEex_AssertThread(IEex_Thread.Both, true)
	if IEex_Quickloot_IsControlOnPanel(control) then
		return IEex_Quickloot_GetSlotData(IEex_GetControlID(control)).containerID
	else
		return -1
	end
end

-- (Render->Sync, OnLClick->Async)
function IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerSpriteID(control)
	IEex_AssertThread(IEex_Thread.Both, true)
	if IEex_Quickloot_IsControlOnPanel(control) then
		return IEex_Quickloot_GetValidPartyMember()
	else
		return -1
	end
end

-- (Render->Sync, OnLClick->Async)
function IEex_Extern_CUIControlButtonWorldContainerSlot_GetContainerItemIndex(control)
	IEex_AssertThread(IEex_Thread.Both, true)
	if IEex_Quickloot_IsControlOnPanel(control) then
		return IEex_Quickloot_GetSlotData(IEex_GetControlID(control)).slotIndex
	else
		return -1
	end
end

-- Right-click a loot slot -> show the item's description instead of picking it up. The stock
-- container window and the quickloot bar are both built out of this control class, so the slot
-- -> item mapping branches the same way the engine's own render / left-click path does.
function IEex_Extern_CUIControlButtonWorldContainerSlot_OnRButtonClick(control)

	IEex_AssertThread(IEex_Thread.Async, true)

	local controlID = IEex_GetControlID(control)
	local CItem = 0x0

	if IEex_Quickloot_IsControlOnPanel(control) then

		local slotData = IEex_Quickloot_GetSlotData(controlID)
		if slotData.isFallback then return end -- the trailing "drop here" slot
		CItem = IEex_GetContainerIDItem(slotData.containerID, slotData.slotIndex)

	elseif controlID <= 9 then

		-- Ground side of the loot window: 5 columns, scrolled by m_nTopContainerRow.
		local containerID = IEex_ReadDword(IEex_GetGameData() + 0x1BA2) -- CInfGame.m_iContainer
		local topRow = IEex_ReadDword(IEex_GetEngineWorld() + 0xF3C)    -- CScreenWorld.m_nTopContainerRow
		CItem = IEex_GetContainerIDItem(containerID, topRow * 5 + controlID)

	elseif controlID <= 13 then

		-- Personal side: the looter's own backpack, 2 columns starting at equipment slot 18.
		local spriteID = IEex_ReadDword(IEex_GetGameData() + 0x1BA6) -- CInfGame.m_iContainerSprite
		local share = IEex_GetActorShare(spriteID)
		if share == 0x0 then return end
		local topRow = IEex_ReadDword(IEex_GetEngineWorld() + 0xF40) -- CScreenWorld.m_nTopGroupRow
		CItem = IEex_ReadDword(share + 0x4AD8 + (topRow * 2 + controlID + 8) * 0x4)
		IEex_UndoActorShare(spriteID)
	end

	IEex_LaunchWorldScreenItemInfo(CItem)
end

----------------------------
-- Define Custom Controls --
----------------------------

-- This runs before the engine has been initialized, it /CANNOT/ access UI structures. It should only
-- be used to define custom control types via IEex_DefineCustomControl(), and potentially define type
-- overrides for specific MENU->PANEL->CONTROL ids via IEex_AddControlOverride().

IEex_AbsoluteOnce("IEex_CustomControls", function()

	if IEex_Vanilla then return end

	---------------
	-- Quickloot --
	---------------

	-------------------------------
	-- IEex_Quickloot_ScrollLeft --
	-------------------------------

	IEex_DefineCustomControl("IEex_Quickloot_ScrollLeft", IEex_ControlStructType.BUTTON, {
		["OnLButtonClick"] = IEex_WriteAssemblyAuto(IEex_FlattenTable({
			{"!push_all_registers_iwd2"},
			IEex_GenLuaCall("IEex_Extern_Quickloot_ScrollLeft", {
				["args"] = {
					{"!push(ecx)"},
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
				!ret_word 08 00
			]]}
		})),
		["OnLButtonDoubleClick"] = 0x4D4D70, -- CUIControlButton_OnLButtonDown; prevents double-click cooldown.
	})

	IEex_AddControlOverride("GUIW08", 23, 10, "IEex_Quickloot_ScrollLeft")
	IEex_AddControlOverride("GUIW10", 23, 10, "IEex_Quickloot_ScrollLeft")

	--------------------------------
	-- IEex_Quickloot_ScrollRight --
	--------------------------------

	IEex_DefineCustomControl("IEex_Quickloot_ScrollRight", IEex_ControlStructType.BUTTON, {
		["OnLButtonClick"] = IEex_WriteAssemblyAuto(IEex_FlattenTable({
			{"!push_all_registers_iwd2"},
			IEex_GenLuaCall("IEex_Extern_Quickloot_ScrollRight", {
				["args"] = {
					{"!push(ecx)"},
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
				!ret_word 08 00
			]]}
		})),
		["OnLButtonDoubleClick"] = 0x4D4D70, -- CUIControlButton_OnLButtonDown; prevents double-click cooldown.
	})

	IEex_AddControlOverride("GUIW08", 23, 11, "IEex_Quickloot_ScrollRight")
	IEex_AddControlOverride("GUIW10", 23, 11, "IEex_Quickloot_ScrollRight")

	--------------------------------
	-- General Custom UI Controls --
	--------------------------------

	IEex_DefineCustomControl("IEex_UI_Button", IEex_ControlStructType.BUTTON, {
		["Render"] = IEex_WriteAssemblyAuto(IEex_FlattenTable({
			{[[
				!mark_esp
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_UI_ButtonRender", {
				["args"] = {
					{"!push(ecx)"},
					{"!marked_esp !push([esp+4])"},
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
				!ret_word 04 00
			]]}
		})),
		["OnLButtonClick"] = IEex_WriteAssemblyAuto(IEex_FlattenTable({
			{"!push_all_registers_iwd2"},
			IEex_GenLuaCall("IEex_Extern_UI_ButtonLClick", {
				["args"] = {
					{"!push(ecx)"},
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
				!ret_word 08 00
			]]}
		})),
		["OnLButtonDoubleClick"] = 0x4D4D70, -- CUIControlButton_OnLButtonDown; prevents double-click cooldown.
	})

	IEex_DefineCustomControl("IEex_UI_Label", IEex_ControlStructType.LABEL, {
		["OnLButtonDown"] = IEex_WriteAssemblyAuto(IEex_FlattenTable({
			{"!push_all_registers_iwd2"},
			IEex_GenLuaCall("IEex_Extern_UI_LabelLDown", {
				["args"] = {
					{"!push(ecx)"},
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
				!ret_word 08 00
			]]}
		})),
	})

	IEex_DefineCustomControl("IEex_UI_TextArea", IEex_ControlStructType.TEXT_AREA, {})
	IEex_DefineCustomControl("IEex_UI_Scrollbar", IEex_ControlStructType.SCROLL_BAR, {})
end)

-- PROTOTYPE (Phase A of the PoE/BG2EE world-HUD refonte): relocate the 6 party portraits to a
-- bottom-right 6x1 row, KEEPING them as panel-1 controls (ids 0-5).
--
-- Why in-place and not a new panel: the engine hardcodes panel 1 for portrait hover -> spell-target
-- (sets m_iPicked in CScreenWorld::AsynchronousUpdate @0x68C3D0, which iterates GetPanel(1)'s
-- controls 0..NumChars under the cursor), plus portrait tooltips and invalidation. A separate panel
-- breaks all of it -- first symptom: you can't pick a cast target by clicking a portrait. So move
-- the controls IN PLACE and WIDEN panel 1's rect so its IsOver test still covers the relocated row.
-- Panel 1 also composites REPLACE in the HUD layer, so the portraits stay opaque (no garbage-alpha
-- blend that turned the new-panel version transparent).
function IEex_InstallPortraitGrid(chuResref)

	-- Refonte hard requirements -- unmet: leave the stock HUD and flip the flag so every
	-- other refonte site (tick handler, dialog hide, ctrl 15/16 creation) sees it off.
	--   * OpenGL renderer: the refonte draws through the DLL's GL HUD layer (content-rects
	--     composite, blended buttons, MOS skip) -- none of it exists in software mode.
	--     m_bIs3dAccelerated = chitin+0x91C, set by the IEex_Render_Patch ctor byte-patch
	--     (retail hardcodes it FALSE and ignores the "3D Acceleration" ini key).
	--   * GUIW10: the layout is authored for the 1024-wide world CHU (the engine's 2x tier
	--     doubles that same CHU); GUIW08 (800x600) has neither the room nor the controls.
	local chitin = IEex_ReadDword(0x8CF6D8)
	if chuResref ~= "GUIW10" or chitin == 0x0 or IEex_ReadDword(chitin + 0x91C) == 0x0 then
		IEex_PortraitGridEnabled = false
		return
	end

	-- The bust row is designed around the BG-style red HP fill ("Old Portrait Health").
	-- Seed the ini default ONCE if the player never set the key, and poke the loaded
	-- option so it applies this session -- the engine caches [Game Options] at boot
	-- (CInfGame options load; m_cOptions.m_nOldPortraitHealth = game+0x44C0). An
	-- explicit player 0 in the ini is respected.
	if IEex_GetPrivateProfileInt("Game Options", "Old Portrait Health", -1, ".\\Icewind2.ini") == -1 then
		IEex_WritePrivateProfileInt("Game Options", "Old Portrait Health", 1, ".\\Icewind2.ini")
		local game = IEex_GetGameData()
		if game ~= 0x0 then
			IEex_WriteDword(game + 0x44C0, 1)
		end
	end

	local worldScreen = IEex_GetEngineWorld()
	local mgr = IEex_GetUIManagerFromEngine(worldScreen)
	-- Engine 2x tier (HD UI) stores control/panel geometry at 2x device px; SetControlArea /
	-- SetPanelArea write raw device px, so scale the 1x-authored sizes by the manager double factor.
	local s = (mgr ~= 0 and IEex_ReadDword(mgr + 0xAA) ~= 0) and 2 or 1
	local resW, resH = IEex_GetResolution()

	-- Virtual layout WIDTH (horizontal anchoring only). At 2x, lay the HUD out on a reference-width
	-- canvas (default 4K) -- the width where the full spread fits (log bottom-left FULL, bars centre,
	-- portraits bottom-right) -- and the DLL (Export_UIScale*, bottom-LEFT pivot) scales it to the
	-- real screen. So a narrower 2x screen shows the 4K layout SIZED DOWN: big correct-shape log,
	-- no compaction. At/above the reference, or without the 2x UI (s==1), layoutW == resW (native).
	-- Must match the DLL's "Floating HUD Ref Width" (same key + default). Vertical stays resH-based
	-- (the DLL scale pivots on the bottom edge, so bottom-anchoring is preserved automatically).
	local layoutW = resW
	if s == 2 then
		local refW = IEex_GetPrivateProfileInt("IEex Options", "Floating HUD Ref Width", 3840, ".\\Icewind2.ini")
		if refW < 2560 then refW = 2560 end
		if refW > 7680 then refW = 7680 end
		layoutW = math.max(resW, refW)
	end

	local panel1 = IEex_GetPanelFromEngine(worldScreen, 1)
	local x1, y1, w1, h1 = IEex_GetPanelArea(panel1)

	-- 58x88 slot = 54x84 BG-style bust image (+2px margin each side, engine geometry
	-- derives from the control: image = slot-4, ring = slot-2). The DLL redirects the
	-- portrait resref _S -> _B for rectangular slots (Export_RenderPortraitRect).
	local slotW, slotH, gap, inset = 58 * s, 88 * s, 4 * s, 12 * s
	local rowW = 6 * slotW + 5 * gap

	-- 6x1 row anchored to the (virtual) bottom-right; control coords are panel-1-relative device px.
	local rowLeft = layoutW - rowW - inset
	local rowTop  = resH - slotH - inset
	for i = 0, 5 do
		local ctrl = IEex_GetControlFromPanel(panel1, i)
		IEex_SetControlArea(ctrl, (rowLeft - x1) + i * (slotW + gap), rowTop - y1, slotW, slotH)
	end

	-- Hide the stock HP-bar strips (ctrl 50-55 = CUIControlButtonPortraitHealthBar, the 45x4 bars
	-- the CHU parks under the stock portraits) so they don't orphan over the new bar block.
	--
	-- Clearing m_active alone did NOT hold -- the bars came back. Their Render gate is
	-- `if (!m_active && !m_bInactiveRender) return` (0x77DE10), an OR, so kill BOTH flags. And
	-- because something outside the decompiled source evidently flips one back on, ALSO zero the
	-- size: CUIPanel::Render intersects the dirty rect with the control rect and only calls
	-- Render() on a non-empty result, so a 0x0 control can never draw whatever the flags say.
	-- Geometry is safe to own -- the bars' async update only writes their fill width (+0x666)
	-- and BAM sequence, never m_size. Leave m_position alone (negative panel-relative coords
	-- wrap 16-bit -- see the panel-0 origin note below).
	for i = 50, 55 do
		local strip = IEex_GetControlFromPanel(panel1, i)
		if strip ~= 0x0 then
			IEex_SetControlActive(strip, false)
			IEex_SetControlInactiveRender(strip, false)
			IEex_SetControlArea(strip, nil, nil, 0, 0)
		end
	end

	-- Bottom-centre bar block = user art IEEXBARB.BMP (572x107): a plain top band (the
	-- action bar), a dark recessed command band below it, and a STATUE at the right that
	-- holds the pause orb. Action bar = 12 stock buttons (38px, pitch 41) on the top band;
	-- command band = 9 stock screen buttons + quickloot(id 15, created later in
	-- OnCHUInitialized -- reads IEex_Refonte_CmdSlots[10] then) in a 10-slot grid (47x40,
	-- pitch 49.7) on the dark band; pause (ctrl 10 = CGEAR orb) + party AI (ctrl 14)
	-- leave the row and sit on the statue instead.
	local btnW, btnH, btnGap = 38 * s, 38 * s, 3 * s
	local blockW, blockH = 572 * s, 107 * s
	-- Bottom row on the VIRTUAL canvas (layoutW): log bottom-left, bar block centred, portrait row
	-- bottom-right. On the reference-width canvas everything fits at full 2x -> FULL-width log, no
	-- compaction; the DLL then scales the whole HUD to the real screen (bottom-left pivot). The
	-- clamps are safety only (keep the block clear of the portraits / leave the log a minimum) --
	-- at the default 4K ref width they never bite. rowLeft = portrait row left edge (above).
	local logX, logGap = 8 * s, 8 * s
	local blockLeft = math.floor((layoutW - blockW) / 2)
	blockLeft = math.min(blockLeft, rowLeft - blockW - gap)
	blockLeft = math.max(blockLeft, logX + 200 * s + logGap)
	local logW = math.max(200 * s, math.min(551 * s, blockLeft - logX - logGap))
	local blockTop = resH - blockH   -- flush to screen bottom (no world strip below)
	local abW = 12 * btnW + 11 * btnGap
	local abLeft = blockLeft + 8 * s
	-- abTop: the buttons sat too high in the plain top band (art band interior ~y9..50 @1x);
	-- +11*s centres the 38*s button in it instead of hugging the top trim.
	local abTop = blockTop + 11 * s
	local cmdTop = blockTop + 61 * s
	-- Exposed for IEex_Refonte_RepositionQuickloot (panel 23 re-anchors above this block).
	IEex_Refonte_BarBlock = { ["left"] = blockLeft, ["top"] = blockTop, ["w"] = blockW, ["h"] = blockH }

	-- Action bar (ctrl 6-17, panel 1, in-place like the portraits).
	for i = 6, 17 do
		local ctrl = IEex_GetControlFromPanel(panel1, i)
		IEex_SetControlArea(ctrl, (abLeft - x1) + (i - 6) * (btnW + btnGap), abTop - y1, btnW, btnH)
	end

	-- Combat log: bottom-left box skinned with IEEXLOGB.BMP (user art, 551x107: thin
	-- ~6px uniform frame, near-flat dark centre, NO baked scrollbar; the DLL composites
	-- it opaque under the blended log text, id -2 rect, vertical 3-slice -> ANY box
	-- height works, the flat centre hides the stretch). Height = 3 presets cycled by
	-- clicking the box's TOP BORDER (invisible IEEXNULB button, ctrl 16), persisted in
	-- the ini. Box width now sized above (logW) to avoid the centred-block overlap;
	-- interior controls scale to logW in ApplyLogHeight.
	--
	-- Ctrl 17 (IEEXRSZB) is the VISIBLE half of that: a small chevron tab centred on the
	-- same border. The strip alone was undiscoverable -- a community poll came back
	-- unanimously "didn't know the log resizes" -- so the tab advertises it and both
	-- controls run the same cycle. It has to be a BAM control, NOT paint baked into
	-- IEEXLOGB: the bezel is drawn as a 3-slice whose caps scale with the box WIDTH and
	-- whose middle band stretches, so baked art would squash per resolution and per
	-- preset, while a BAM frame renders at NATIVE px (CVidCell: anchored at the control
	-- corner, clipped, never scaled) -- identical at all three heights.
	IEex_Refonte_Scale = s
	-- Tab footprint, 1x-authored (x2 at the engine's 2x tier, matching the 76x24 BAM the
	-- 2x asset set ships, 76x26). Must equal the BAM frame size -- the control rect only CLIPS the
	-- frame, so a smaller rect silently crops the art rather than erroring.
	-- The tab is taller than the bezel's 12px top cap because it casts a real offset drop
	-- shadow (down+right) onto the log interior; IEex_Refonte_LogTextTop below hands it that
	-- strip so the shadow never lands on a log line.
	IEex_Refonte_LogTabW, IEex_Refonte_LogTabH = 38 * s, 13 * s
	IEex_Refonte_LogTextTop = 16 * s   -- text/scrollbar top inset: tab (13) + 3 clear
	IEex_Refonte_LogHeights = { 128 * s, 192 * s, 256 * s }
	IEex_Refonte_LogHeightIdx = math.max(1, math.min(#IEex_Refonte_LogHeights,
		IEex_GetPrivateProfileInt("IEex Options", "Refonte Log Height", 1, ".\\Icewind2.ini")))
	local logMaxH = IEex_Refonte_LogHeights[#IEex_Refonte_LogHeights]

	-- Panel 0 reposition: origin = top-left of ALL its content (log box at its MAX
	-- height + command row) so every control keeps POSITIVE panel-relative coords.
	-- (The engine centers the 1024-wide band at 4K -- the old origin sat RIGHT of the
	-- log target, the negative relative coords wrapped 16-bit and the log rendered
	-- top-left, smeared.)
	local panel0 = IEex_GetPanelFromEngine(worldScreen, 0)
	local o0x = math.min(logX, abLeft - 2 * s)
	local o0y = math.min(resH - 8 * s - logMaxH, cmdTop - 2 * s)
	IEex_SetPanelArea(panel0, o0x, o0y, layoutW - o0x, resH - o0y)
	IEex_Refonte_P0Origin = { ["x"] = o0x, ["y"] = o0y }
	IEex_Refonte_LogGeom = { ["x"] = logX, ["w"] = logW }

	-- Command band: the dark recessed strip (art x4..~500, ~497 wide) holds the 9 stock
	-- screen buttons + the quickloot toggle (slot 10) in a 10-slot grid. Box 47x40 (matches
	-- the GCOMMBTN cell), pitch 49.7, left inset 10 (band x4 + 6px in-band nudge; the row
	-- also sits 1px below the band top -- cmdTop 61 -- both user-tuned in-game). Pause (10)
	-- and party AI (14) are NOT in the row -- they sit on the statue (below).
	local cmdOrder = {4, 5, 6, 7, 8, 9, 11, 12, 13}   -- 9 stock; quickloot(15) = slot 10
	local cmdBoxW, cmdBoxH, cmdPitch, cmdInset = 47 * s, 40 * s, 49.7 * s, 10 * s
	IEex_Refonte_CmdSlots = {}   -- panel-relative to the NEW origin
	for slot = 1, 10 do
		IEex_Refonte_CmdSlots[slot] = {
			["x"] = (blockLeft - o0x) + cmdInset + math.floor((slot - 1) * cmdPitch),
			["y"] = cmdTop - o0y,
			["w"] = cmdBoxW,
			["h"] = cmdBoxH,
		}
	end
	for slot, id in ipairs(cmdOrder) do
		local ctrl = IEex_GetControlFromPanel(panel0, id)
		if ctrl ~= 0x0 then
			local sl = IEex_Refonte_CmdSlots[slot]
			IEex_SetControlArea(ctrl, sl.x, sl.y, sl.w, sl.h)
		end
	end

	-- Retarget the command buttons to the APPENDED refonte cycles (11-19 -> frame pairs
	-- 22/23..38/39). GCOMMBTN is shared with the sub-screen nav cluster (inventory/
	-- record/...); its stock cycles 0-10 stay intact so those screens keep their look --
	-- only these world buttons switch their vidcell SEQUENCE (see cmdbtn_pack_refonte.py).
	-- Sequence, not frames: button frame indices resolve WITHIN the current cycle and
	-- clamp to its frame count (CVidCell::GetFrame) -- forcing global frame numbers
	-- (22-39) into the 2-frame stock cycles just clamped back to the stock art.
	-- ctrl 14 (party AI) keeps its stock face.
	local cmdSeqs = {[4]=11,[5]=12,[6]=13,[7]=14,[8]=15,[9]=16,[11]=17,[12]=18,[13]=19}
	for id, seq in pairs(cmdSeqs) do
		local ctrl = IEex_GetControlFromPanel(panel0, id)
		if ctrl ~= 0x0 then
			IEex_SetControlButtonSequence(ctrl, seq)
			IEex_SetControlButtonFrameUpForce(ctrl, 0)
			IEex_SetControlButtonFrameDown(ctrl, 1)
			-- m_nDisabledFrame: the stock CHU value can exceed the new 2-frame cycle;
			-- clamp-by-hand to the normal frame so SetEnabled(FALSE) shows the up art.
			IEex_WriteWord(ctrl + 0x130, 0)
		end
	end

	-- Statue buttons (block right, art x~500..572): Pause = ctrl 10 (CGEAR orb) pinned
	-- over the baked orb; Party AI = ctrl 14 over the statue's baked head. The art was
	-- composed with the ORIGINAL button frames pasted in (orb frame at art 512,47; face
	-- frame 18 at art 524,1 -- template-matched), so the live frames overlay them exactly.
	-- CVidCell renders at (ctrl - frame.center) and CLIPS to the control rect
	-- (CVidCell.cpp Render3d): CGEAR center = (-9,-4) -> frame lands at ax+9/ay+4, so
	-- ax/ay = paste - (9,4) and w/h = frame + (9,4) or the right/bottom edges clip.
	-- The face frame (26x45) has center (0,0) -> control = the paste rect verbatim.
	-- Coords are art-relative (to the block top-left); rebased to the panel origin.
	-- Both fall inside the id -3 block rect, so they composite as blended buttons.
	local statueBtns = {
		[10] = { ["ax"] = 503 * s, ["ay"] = 43 * s, ["w"] = 61 * s, ["h"] = 55 * s },  -- pause / orb 52x51 @512,47
		[14] = { ["ax"] = 524 * s, ["ay"] = 1 * s, ["w"] = 26 * s, ["h"] = 45 * s },   -- party AI / face 26x45 @524,1
	}
	for id, g in pairs(statueBtns) do
		local ctrl = IEex_GetControlFromPanel(panel0, id)
		if ctrl ~= 0x0 then
			IEex_SetControlArea(ctrl, (blockLeft - o0x) + g.ax, (blockTop - o0y) + g.ay, g.w, g.h)
		end
	end

	-- Static composite rects (everything but the log, which IEex_Refonte_ApplyLogHeight
	-- re-registers on every height change). The portrait slots are derived from this row
	-- geometry for the CURRENT party size -- see IEex_Refonte_RebuildStaticRects.
	--
	-- Bar block: ONE id -3 rect = IEEXBARB art + blended buttons (both rows). The
	-- degenerate id 0 rect keeps panel 0 in content-rects mode (composite + MOS skip)
	-- without drawing anything.
	IEex_Refonte_PortraitRow = {left = rowLeft, top = rowTop, w = slotW, h = slotH, gap = gap}
	IEex_Refonte_BarRect = {x = blockLeft, y = blockTop, w = blockW, h = blockH}
	IEex_Refonte_RebuildStaticRects()

	-- Log controls + rects at the saved height (ctrl 16 = the click strip, created
	-- later alongside the quickloot button -- its placement no-ops until then).
	IEex_Refonte_ApplyLogHeight(IEex_Refonte_LogHeightIdx)

	-- Widen panel 1's rect so IsOver (portrait hover / targeting) still covers the relocated row.
	-- Origin unchanged -> viewport floor (panel-1 top) unchanged; only extend down/right.
	IEex_SetPanelArea(panel1, x1, y1, math.max(w1, layoutW - inset - x1), math.max(h1, resH - inset - y1))

	-- Register panel 1's REAL content sub-rects for the HUD-layer composite so the widened rect's
	-- transparent gap shows the world instead of opaque black (the composite REPLACEs a MOS panel's
	-- whole rect). No GACTN bezel rect anymore: portraits AND action bar both left the stock band,
	-- so the band simply is not composited -- the world shows there (PoE-style floating HUD).
	-- No-op without the HUD layer / on an older DLL that lacks the export.

	-- Panel 23 (quickloot bar) was built by IEex_InstallQuickloot BEFORE this relocation
	-- ran, so it sits at panel 1's stock origin (old-HUD spot). Re-anchor it to the refonte.
	IEex_Refonte_RepositionQuickloot()
end

-- Will slot i actually DRAW? Mirrors CInfGame::RenderPortrait (0x5AF770): it renders only when
-- GetCharacterId(i) (0x452FE0 -- `i < m_nCharacters ? m_characterPortraits[i] : INVALID_INDEX`)
-- resolves to a live sprite through GetShare. Anything else leaves the slot blank.
--
-- m_nCharacters (game+0x3846) is no usable slot count on its own, twice over: it reads 0 while the
-- world CHU is being built (the save populates the party only afterwards -- hence the full-row
-- fallback below), and it does NOT drop when a reform removes a member. It stayed 6 for a 5-PC
-- party while m_characterPortraits[5] kept an object id GetShare can no longer resolve -- and that
-- stale slot is exactly the one that rendered nothing and composited as an opaque black box. So key
-- on the GetShare test (what the renderer does) and keep the count only as a cheap upper bound.
function IEex_Refonte_SlotOccupied(i)
	local game = IEex_GetGameData()
	if game == 0x0 then return false end
	if i >= IEex_ReadSignedWord(game + 0x3846, 0x0) then return false end   -- m_nCharacters
	local id = IEex_GetActorIDPortrait(i)                                   -- m_characterPortraits[i]
	return id ~= nil and id >= 0 and IEex_IsSprite(id, true)
end

-- Bitmask of the slots that will draw. Zero (party not loaded yet -- the world CHU is built
-- before the save populates it) falls back to the FULL row: a panel 1 owning NO id-1 content
-- rect fails the composite's ownership test, and its whole widened bounding box would then
-- REPLACE opaque black over the world.
function IEex_Refonte_SlotMask()
	local mask = 0
	for i = 0, 5 do
		if IEex_Refonte_SlotOccupied(i) then mask = mask + bit.lshift(1, i) end
	end
	if mask == 0 then return 0x3F end
	return mask
end

-- Rebuild the static composite-rect set for the slots that currently draw. An EMPTY slot must
-- not keep a rect: the composite REPLACEs every registered rect opaque (blending is off -- the
-- layer's legacy blit alpha is garbage), so a slot the renderer skips composites the
-- scissor-cleared transparent black as an opaque BLACK BOX over the world, and still reads as UI
-- for clicks/wheel. Party membership changes at runtime (reform), so IEex_Extern_BeforeWorldRender
-- re-runs this whenever the mask moves.
function IEex_Refonte_RebuildStaticRects()
	local row, bar = IEex_Refonte_PortraitRow, IEex_Refonte_BarRect
	if not row or not bar then return end
	local mask = IEex_Refonte_SlotMask()
	IEex_Refonte_LastSlotMask = mask
	IEex_Refonte_StaticRects = {}
	for i = 0, 5 do
		if bit.band(mask, bit.lshift(1, i)) ~= 0 then
			table.insert(IEex_Refonte_StaticRects, {1, row.left + i * (row.w + row.gap), row.top, row.w, row.h})
		end
	end
	table.insert(IEex_Refonte_StaticRects, {-3, bar.x, bar.y, bar.w, bar.h})
	table.insert(IEex_Refonte_StaticRects, {0, 0, 0, 0, 0})
	local game = IEex_GetGameData()
	print(string.format("[REFONTE] portrait slots: mask=0x%02X m_nCharacters=%d", mask,
		game ~= 0x0 and IEex_ReadSignedWord(game + 0x3846, 0x0) or -1))
end

-- Re-register the full refonte composite-rect set: statics (portrait slots id 1,
-- action-bar rect id 1, command-row rect id 0) + the log box (id -2, bezel pass).
function IEex_Refonte_RegisterRects()
	if not IEex_Helper_HudClearPanelContentRects then return end
	IEex_Helper_HudClearPanelContentRects()
	for _, r in ipairs(IEex_Refonte_StaticRects) do
		IEex_Helper_HudAddPanelContentRect(r[1], r[2], r[3], r[4], r[5])
	end
	local lr = IEex_Refonte_LogRect
	if lr then
		IEex_Helper_HudAddPanelContentRect(-2, lr.x, lr.y, lr.w, lr.h)
	end
end

-- Apply a log-box height preset: bottom-anchored box, controls reflowed inside
-- (12px caps + pads), rects re-registered, panel invalidated. Ctrl 16 = the
-- invisible top-border click strip (cycles presets; created with the quickloot
-- button, placement no-ops before that).
function IEex_Refonte_ApplyLogHeight(idx)
	local s = IEex_Refonte_Scale
	local g = IEex_Refonte_LogGeom
	local o = IEex_Refonte_P0Origin
	local worldScreen = IEex_GetEngineWorld()
	local panel0 = IEex_GetPanelFromEngine(worldScreen, 0)
	local resW, resH = IEex_GetResolution()
	local h = IEex_Refonte_LogHeights[idx]
	IEex_Refonte_LogHeightIdx = idx
	local logY = resH - 8 * s - h
	-- Interior for the user bg (thin ~6px frame, NO baked scrollbar): 8px bottom inset,
	-- live scrollbar (ctrl 2) in the right margin, text fills the rest. Widths derive from
	-- g.w (the box width, now variable to dodge the centred-block overlap) so the scrollbar
	-- stays pinned to the right frame and the text/input wrap to fit -- at the full 551*s
	-- these reduce to 517 / 530 / 523. The scrollbar's right inset is 21, not the frame's
	-- ~6: the bezel's inner bevel needs clear air to its right or the thumb reads as if it
	-- were sitting on the frame.
	--
	-- The TOP inset is textTop, not the old flat 8*s: the resize tab (ctrl 17) overhangs the
	-- bezel's top cap and casts a drop shadow below itself, so the text starts under the whole
	-- tab footprint instead of the tab being squeezed into the cap. Costs ~half a line.
	local tabW, tabH = IEex_Refonte_LogTabW or 38 * s, IEex_Refonte_LogTabH or 13 * s
	local textTop = IEex_Refonte_LogTextTop or (tabH + 3 * s)
	local textH = h - textTop - 8 * s
	local place = {
		[1]  = { g.x + 8 * s,        logY + textTop,    g.w - 34 * s, textH },
		[2]  = { g.x + g.w - 21 * s, logY + textTop,    12 * s,       textH },
		[3]  = { g.x + 8 * s,        logY + h - 26 * s, g.w - 28 * s, 20 * s },
		[16] = { g.x,                logY,              g.w,          12 * s },
		-- Visible resize tab: CONSTANT size at every preset (the BAM frame is drawn at its
		-- native px and only clipped by this rect) -- only its y follows logY, so it stays
		-- glued to the border without ever changing shape as the box grows.
		[17] = { g.x + math.floor((g.w - tabW) / 2), logY, tabW, tabH },
	}
	for id, r in pairs(place) do
		local c = IEex_GetControlFromPanel(panel0, id)
		if c ~= 0x0 then
			IEex_SetControlArea(c, r[1] - o.x, r[2] - o.y, r[3], r[4])
		end
	end

	-- Reflow the text display (ctrl 1). m_nVisibleLines (+0xA6C) is derived from the box
	-- height ONLY at CHU-init (CUIControlTextDisplay: m_nVisibleLines = m_size.cy / m_nFontHeight).
	-- SetControlArea above rewrote m_size.cy but NOT m_nVisibleLines, so a taller box would keep
	-- the original line count and the text would stay in the old band (the enlargement was inert).
	-- Recompute it from the new height + font height (+0xA60), then ScrollToBottom (0x4E3D60) so
	-- the enlarged box immediately reveals more scrollback.
	local textCtrl = IEex_GetControlFromPanel(panel0, 1)
	if textCtrl ~= 0x0 then
		local fontH = IEex_ReadWord(textCtrl + 0xA60)
		if fontH > 0 then
			-- m_nVisibleLines is at +0xA6A (disasm 0x4E1D32 `mov [esi+0xa6a], ax`); the RE
			-- header mislabels it 0xA6C, which is field_A6C -- a per-line counter DisplayString
			-- increments, so writing there both left the real line count stale AND corrupted the
			-- counter -> hang when NPC dialogue appended log lines.
			IEex_WriteWord(textCtrl + 0xA6A, math.floor(textH / fontH))
			IEex_Call(0x4E3D60, {}, textCtrl, 0x0)
		end
	end

	-- Resize the scrollbar's cached track. field_140 (+0x140 = track px) and field_142
	-- (+0x142 = thumb range) are frozen at CTOR from the CHU height; the render derives
	-- the down arrow (pt+upH+field_140), track and thumb from them -- so SetControlArea
	-- alone leaves the arrow floating mid-box while the frame grows. Recompute from the
	-- new height: track = m_size.cy - upBtnH - downBtnH; range = track - thumbH (thumbH
	-- recovered from the old track-range delta). Buttons: +0x138 up, +0x13C down.
	local sbCtrl = IEex_GetControlFromPanel(panel0, 2)
	if sbCtrl ~= 0x0 then
		local upBtn = IEex_ReadDword(sbCtrl + 0x138)
		local downBtn = IEex_ReadDword(sbCtrl + 0x13C)
		if upBtn ~= 0 and downBtn ~= 0 then
			local thumbH = IEex_ReadSignedWord(sbCtrl + 0x140) - IEex_ReadSignedWord(sbCtrl + 0x142)
			local track = textH - IEex_ReadWord(upBtn + 0x1A) - IEex_ReadWord(downBtn + 0x1A)
			if track < 1 then track = 1 end
			local range = track - thumbH
			if range < 1 then range = 1 end
			IEex_WriteWord(sbCtrl + 0x140, track)
			IEex_WriteWord(sbCtrl + 0x142, range)
		end
	end

	IEex_Refonte_LogRect = { ["x"] = g.x, ["y"] = logY, ["w"] = g.w, ["h"] = h }
	IEex_Refonte_RegisterRects()
	IEex_PanelInvalidate(panel0)
end

function IEex_Refonte_CycleLogHeight()
	local idx = (IEex_Refonte_LogHeightIdx % #IEex_Refonte_LogHeights) + 1
	IEex_Refonte_ApplyLogHeight(idx)
	IEex_WritePrivateProfileInt("IEex Options", "Refonte Log Height", idx, ".\\Icewind2.ini")
end

-- Re-anchor the quickloot bar (panel 23) above the refonte bottom-centre bar block.
-- IEex_InstallQuickloot builds the panel from panel 1's stock (centred) origin because it
-- runs BEFORE IEex_InstallPortraitGrid relocates the action bar -- so it lands at the old
-- world-HUD spot. The bar's internal controls are panel-relative, so moving the panel
-- origin carries them; centre it horizontally on the block and sit it just above the top.
function IEex_Refonte_RepositionQuickloot()
	local blk = IEex_Refonte_BarBlock
	if not blk then return end
	local panel23 = IEex_GetPanelFromEngine(IEex_GetEngineWorld(), 23)
	if panel23 == 0x0 then return end
	local s = IEex_Refonte_Scale or 1
	local _, _, qw, qh = IEex_GetPanelArea(panel23)
	local qx = blk.left + math.floor((blk.w - qw) / 2)
	-- Sit just ABOVE the block art with a small gap: flush (qy = blk.top - qh) made the
	-- quickloot bar art bottom edge touch the block frame top edge, which read as overlapping
	-- the action bar. qGap lifts it clear (scaled; tunable). NB the LIVE placement is the
	-- per-tick handler (~line 1758); this CHU-setup value only sets the pre-show position.
	local qGap = 3 * s
	local qy = blk.top - qh - qGap
	IEex_SetPanelArea(panel23, qx, qy, qw, qh, true)
end

function IEex_InstallActionIndicators()

	local worldScreen = IEex_GetEngineWorld()
	local chuResref = IEex_GetCHUResrefFromEngine(worldScreen)
	local panel1 = IEex_GetPanelFromEngine(worldScreen, 1)
	local x1, y1, w1, h1 = IEex_GetPanelArea(panel1)

	-- HD UI (2x): x1/y1/w1 + referenceControlX below are read from the engine action bar, which
	-- field_4A2C already returns at 2x. This panel is added to the WORLD engine (double-size manager),
	-- so the CUIPanel/control ctors DOUBLE them AGAIN -> 4x off-screen. Pre-divide the engine-derived
	-- coords so the ctor lands them at the true 2x reference (mirrors IEex_InstallQuickloot). The
	-- PanelHeight/slot-size/offset constants are 1x-authored -> leave them (the ctor doubles them).
	-- 1x install -> div=1, unchanged.
	local div = (IEEX_HD_UI and IEex_ReadDword(IEex_GetUIManagerFromEngine(worldScreen) + 0xAA) ~= 0) and 2 or 1

	-- Panel rect = the controls' real span, not the full bar width: the panel is
	-- composited/cleared by its RECT under the HUD layer, and a full-width rect
	-- overlaps the quickloot bar on the same row (showed as a black band over it).
	local indMinX, indMaxX = math.huge, -math.huge
	for refI = 0, 5 do
		local refX = IEex_GetControlArea(IEex_GetControlFromPanel(panel1, refI))
		local base = math.floor(refX / div)
		indMinX = math.min(indMinX,
			base + IEex_ActionIndicators_PrimarySlotOffsetX,
			base + IEex_ActionIndicators_SecondarySlotOffsetX,
			base + IEex_ActionIndicators_TertiarySlotOffsetX)
		indMaxX = math.max(indMaxX,
			base + IEex_ActionIndicators_PrimarySlotOffsetX + IEex_ActionIndicators_PrimarySlotSize,
			base + IEex_ActionIndicators_SecondarySlotOffsetX + IEex_ActionIndicators_SecondarySlotSize,
			base + IEex_ActionIndicators_TertiarySlotOffsetX + IEex_ActionIndicators_TertiarySlotSize)
	end

	local actionIndicatorsPanel = IEex_AddPanelToEngine(worldScreen, {
		["id"]     = IEex_ActionIndicatorsPanelID,
		["x"]      = math.floor(x1 / div) + indMinX,
		["y"]      = math.floor(y1 / div) - IEex_ActionIndicators_PanelHeight,
		["width"]  = indMaxX - indMinX,
		["height"] = IEex_ActionIndicators_PanelHeight,
	})

	for refI = 0, 5 do

		local i = refI * 3
		local referenceControl = IEex_GetControlFromPanel(panel1, refI)
		local referenceControlX, _, referenceControlW = IEex_GetControlArea(referenceControl)

		IEex_AddControlOverride(chuResref, IEex_ActionIndicatorsPanelID, i, "IEex_UI_Button")
		IEex_AddControlToPanel(actionIndicatorsPanel, {
			["id"]     = i,
			["x"]      = math.floor(referenceControlX / div) + IEex_ActionIndicators_PrimarySlotOffsetX - indMinX,
			["y"]      = IEex_ActionIndicators_PanelHeight + IEex_ActionIndicators_PrimarySlotOffsetY,
			["width"]  = IEex_ActionIndicators_PrimarySlotSize,
			["height"] = IEex_ActionIndicators_PrimarySlotSize,
			["type"]   = IEex_ControlStructType.BUTTON,
			["bam"]    = IEex_GetControlButtonBAM(referenceControl),
		})
		IEex_SetControlButtonPlayLButtonDownSound(IEex_GetControlFromPanel(actionIndicatorsPanel, i), false)

		IEex_AddControlOverride(chuResref, IEex_ActionIndicatorsPanelID, i + 1, "IEex_UI_Button")
		IEex_AddControlToPanel(actionIndicatorsPanel, {
			["id"]     = i + 1,
			["x"]      = math.floor(referenceControlX / div) + IEex_ActionIndicators_SecondarySlotOffsetX - indMinX,
			["y"]      = IEex_ActionIndicators_PanelHeight + IEex_ActionIndicators_SecondarySlotOffsetY,
			["width"]  = IEex_ActionIndicators_SecondarySlotSize,
			["height"] = IEex_ActionIndicators_SecondarySlotSize,
			["type"]   = IEex_ControlStructType.BUTTON,
			["bam"]    = IEex_GetControlButtonBAM(referenceControl),
		})
		IEex_SetControlButtonPlayLButtonDownSound(IEex_GetControlFromPanel(actionIndicatorsPanel, i + 1), false)

		IEex_AddControlOverride(chuResref, IEex_ActionIndicatorsPanelID, i + 2, "IEex_UI_Button")
		IEex_AddControlToPanel(actionIndicatorsPanel, {
			["id"]     = i + 2,
			["x"]      = math.floor(referenceControlX / div) + IEex_ActionIndicators_TertiarySlotOffsetX - indMinX,
			["y"]      = math.max(0, IEex_ActionIndicators_PanelHeight + IEex_ActionIndicators_TertiarySlotOffsetY),
			["width"]  = IEex_ActionIndicators_TertiarySlotSize,
			["height"] = IEex_ActionIndicators_TertiarySlotSize,
			["type"]   = IEex_ControlStructType.BUTTON,
			["bam"]    = IEex_GetControlButtonBAM(referenceControl),
		})
		IEex_SetControlButtonPlayLButtonDownSound(IEex_GetControlFromPanel(actionIndicatorsPanel, i + 2), false)
	end
end

function IEex_InstallQuickloot(chuResref)

	local worldScreen = IEex_GetEngineWorld()

	local panel1Memory = IEex_GetPanelFromEngine(worldScreen, 1)
	local panel8Memory = IEex_GetPanelFromEngine(worldScreen, 8)

	-- HD UI (2x): every coord here is copied from LIVE engine panels/controls (panel 1 = action bar,
	-- panel 8), which field_4A2C already returns at 2x. But this quickloot panel is added to the WORLD
	-- engine (double-size manager), so the CUIPanel/control ctors DOUBLE these coords AGAIN -> 4x. Pre-
	-- divide the engine-derived coords by the ctor's doubling factor so it lands them back at the true 2x
	-- reference (and the quickloot stays aligned to the action bar). 1x install -> div=1, unchanged.
	local div = (IEEX_HD_UI and IEex_ReadDword(IEex_GetUIManagerFromEngine(worldScreen) + 0xAA) ~= 0) and 2 or 1

	local x1, y1, w1, h1 = IEex_GetPanelArea(panel1Memory)

	-- Refonte (Floating HUD) or the stock HUD? The two need DIFFERENT quickloot geometry, and
	-- the flag alone is not the answer here: IEex_InstallPortraitGrid owns the runtime veto but
	-- runs AFTER this function, so IEex_PortraitGridEnabled is still optimistically true when
	-- the refonte is about to bail. Re-test its hard requirements (GUIW10 + the GL renderer,
	-- chitin+0x91C) so a vetoed refonte gets the stock layout, not the refonte one.
	local chitin = IEex_ReadDword(0x8CF6D8)
	local refonte = IEex_PortraitGridEnabled and chuResref == "GUIW10"
		and chitin ~= 0x0 and IEex_ReadDword(chitin + 0x91C) ~= 0x0

	-- Panel rect (pre-div where the ctor doubles), background resref + panel-local control rects,
	-- filled per branch: slotRects[1..10] = the item slots, arrowRects[1] = left scroll, [2] = right.
	local panelY, panelW, panelH, bgResref
	local slotRects, arrowRects = {}, {}

	if refonte then

		-- B3QKLOOM = the user's bar art (quickloot.png, 505x51 == the IEEXBARB block width).
		-- Lay the action bar's grid inside it: 12 buttons, btnW 38, pitch 41, left inset 8
		-- (489 centred in 505, exactly like the action row in the block) -- [0] left arrow,
		-- [1..10] item slots, [11] right arrow. Sizes 1x-authored (the ctor doubles for HD).
		local gBtn, gPitch, gInset = 38, 41, 8
		-- Sit the buttons low in the bar (art top trim is thick; centring pushes them up into
		-- it). Bar 51 - btn 38 = 13 max; 12 leaves a 1px bottom margin.
		local slotY = 12

		-- Always the minimal resref: the refonte's own B3QKLOOM is fully opaque at 505x51 (it is
		-- its own cover, the IEEXBARB analogue), and the refonte HUD carries no stone frame to
		-- match, so the "UI Borders" state is irrelevant here.
		bgResref = "B3QKLOOM"
		panelW, panelH = 505, 51
		panelY = math.floor(y1 / div) - panelH
		for i = 1, 10 do
			slotRects[i] = {gInset + i * gPitch, slotY, gBtn, gBtn}
		end
		arrowRects[1] = {gInset, slotY, gBtn, gBtn}
		arrowRects[2] = {gInset + 11 * gPitch, slotY, gBtn, gBtn}

	else

		-- Stock HUD: the bar owns no art -- it borrows the command bar's MOS, whose decorative
		-- frame insets the functional strip (112px each side at 1024). So EVERY coord must come
		-- from the LIVE action bar (panel 1 controls 6..17) -- the slots then sit exactly above
		-- the buttons and the panel spans the same strip. The refonte's fixed grid above is
		-- authored for its own 505-wide art, which starts at the panel origin: applied here it
		-- lands the whole bar 112px left of the command bar below it.
		--
		-- Ask for the DECORATED art and let the "UI Borders" toggle decide, exactly like every
		-- other world-HUD panel: IEex_Gui_Patch's CDimm::GetResObject redirect swaps B3QKLOOT ->
		-- B3QKLOOM at load time when borders are off, and the DLL's HUD-layer composite knows to
		-- skip a minimal panel's keyed margins. Hardcoding B3QKLOOM instead (the refonte's choice)
		-- bypasses both: with borders ON its 112px colour-key margin has nothing handling it and
		-- the world HUD's REPLACE composite renders it as a solid black block.
		bgResref = "B3QKLOOT"
		-- Panel height: the historical h1 (full action-bar height) leaves a ~2/3 tail of
		-- colorkey-transparent MOS BELOW the item row, overlapping the action-indicator
		-- row -- under the HUD layer that region composites as a solid band (REPLACE
		-- ignores colorkey). Measure the real content: bottom of the deepest control
		-- (slots + arrows share panel-local Y offsets) + a small pad, so the panel rect
		-- matches what is actually drawn. Width likewise: the slots + arrows only span the
		-- LEFT part of the action bar, the rest of the MOS is unused stone -- clip it via the
		-- panel rect (the MOS renders clipped, no asset edit) so the shorter bar no longer
		-- overlaps the action indicators horizontally and both can share the row above the HUD.
		local contentBottom = 0
		local contentRight = 0
		for i = 7, 16 do
			local refX, refY = IEex_GetControlArea(IEex_GetControlFromPanel(panel1Memory, i))
			local _, _, copyW, copyH = IEex_GetControlArea(IEex_GetControlFromPanel(panel8Memory, i - 7))
			contentBottom = math.max(contentBottom, refY + 1 + copyH)
			contentRight = math.max(contentRight, refX + 1 + copyW)
			slotRects[i - 6] = {math.floor((refX + 1) / div), math.floor((refY + 1) / div),
				math.floor(copyW / div), math.floor(copyH / div)}
		end
		for k, arrowID in ipairs({6, 17}) do
			local arrowX, arrowY, arrowW, arrowH = IEex_GetControlArea(IEex_GetControlFromPanel(panel1Memory, arrowID))
			contentBottom = math.max(contentBottom, arrowY + arrowH)
			contentRight = math.max(contentRight, arrowX + arrowW)
			arrowRects[k] = {math.floor(arrowX / div), math.floor(arrowY / div),
				math.floor(arrowW / div), math.floor(arrowH / div)}
		end

		local quicklootHeight = math.min(h1, contentBottom + 4)
		panelW = math.floor(math.min(w1, contentRight + 4) / div)
		panelH = math.floor(quicklootHeight / div)
		panelY = math.floor((y1 - quicklootHeight) / div)

	end

	local quicklootPanel = IEex_AddPanelToEngine(worldScreen, {
		["id"]              = 23,
		["x"]               = math.floor(x1 / div),
		["y"]               = panelY,
		["width"]           = panelW,
		["height"]          = panelH,
		["hasBackground"]   = 1,
		["backgroundImage"] = bgResref
	})

	-- Ten item slots: panel 8 controls 0-9 supply the id + button BAM, slotRects the geometry.
	for i = 7, 16 do
		local copyControl = IEex_GetControlFromPanel(panel8Memory, i - 7)
		local r = slotRects[i - 6]
		IEex_AddControlToPanel(quicklootPanel, {
			["id"]     = IEex_GetControlID(copyControl),
			["x"]      = r[1],
			["y"]      = r[2],
			["width"]  = r[3],
			["height"] = r[4],
			["type"]   = IEex_ControlStructType.BUTTON,
			["bam"]    = IEex_GetControlButtonBAM(copyControl),
		})
	end

	-- Scroll arrows: {control id, GUIBTACT unpressed frame, pressed frame}.
	for k, arrow in ipairs({{10, 48, 49}, {11, 52, 53}}) do
		local r = arrowRects[k]
		IEex_AddControlToPanel(quicklootPanel, {
			["id"]             = arrow[1],
			["x"]              = r[1],
			["y"]              = r[2],
			["width"]          = r[3],
			["height"]         = r[4],
			["type"]           = IEex_ControlStructType.BUTTON,
			["bam"]            = "GUIBTACT",
			["frameUnpressed"] = arrow[2],
			["framePressed"]   = arrow[3],
		})
	end
end

function IEex_InstallIEexOptions()

	local screenOptions = IEex_GetEngineOptions()

	local worldOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 2)

	-- Move the normal "Return" button over to make room
	IEex_SetControlXY(IEex_GetControlFromPanel(worldOptionsPanel, 11), 612, 338)

	IEex_AddControlOverride("GUIOPT", 2, 15, "IEex_UI_Button")
	IEex_AddControlToPanel(worldOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 15,
		["x"] = 497,
		["y"] = 338,
		["width"] = 117,
		["height"] = 25,
		["bam"] = "GBTNSTD",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
		["frameDisabled"] = 3,
	})
	IEex_SetControlButtonText(IEex_GetControlFromPanel(worldOptionsPanel, 15), IEex_FetchString(ex_tra_55901)) -- "IEex Options"

	-- Duplicate "IEex Options" button on the MAIN-MENU options popup (panel 13). The engine hides the
	-- in-game main options panel (2) and summons popup 13 pre-game (CScreenOptions::EngineActivated when
	-- m_bFromMainMenu), so the panel-2 button never shows there. Same bottom-row layout: shift the popup's
	-- "Return" (id 11) over and drop the button beside it. Click -> openIEexOptions(13).
	local mainMenuOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 13)
	IEex_SetControlXY(IEex_GetControlFromPanel(mainMenuOptionsPanel, 11), 612, 338)
	IEex_AddControlOverride("GUIOPT", 13, 15, "IEex_UI_Button")
	IEex_AddControlToPanel(mainMenuOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 15,
		["x"] = 497,
		["y"] = 338,
		["width"] = 117,
		["height"] = 25,
		["bam"] = "GBTNSTD",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
		["frameDisabled"] = 3,
	})
	IEex_SetControlButtonText(IEex_GetControlFromPanel(mainMenuOptionsPanel, 15), IEex_FetchString(ex_tra_55901)) -- "IEex Options"

	-- IEex Options panel - ID 14
	local newOptionsPanel = IEex_AddPanelToEngine(screenOptions, {
		["id"] = 14,
		["width"] = 800,
		["height"] = 433,
		["hasBackground"] = 1,
		["backgroundImage"] = "GOPPAUB",
	})

	-- "IEex Options" Label - ID 0
	IEex_AddControlOverride("GUIOPT", 14, 0, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 0,
		["x"] = 279,
		["y"] = 23,
		["width"] = 242,
		["height"] = 30,
		["fontBam"] = "STONEBIG",
		["textFlags"] = 0x44, -- Center justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 0), IEex_FetchString(ex_tra_55901)) -- "IEex Options"

	-- "Done" Button - ID 1
	IEex_AddControlOverride("GUIOPT", 14, 1, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 1,
		["x"] = 614,
		["y"] = 375,
		["width"] = 117,
		["height"] = 25,
		["bam"] = "GBTNSTD",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
		["frameDisabled"] = 3,
	})
	IEex_SetControlButtonText(IEex_GetControlFromPanel(newOptionsPanel, 1), IEex_FetchString(11973)) -- "Done"

	-- "Cancel" Button - ID 2
	IEex_AddControlOverride("GUIOPT", 14, 2, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 2,
		["x"] = 491,
		["y"] = 375,
		["width"] = 117,
		["height"] = 25,
		["bam"] = "GBTNSTD",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
		["frameDisabled"] = 3,
	})
	IEex_SetControlButtonText(IEex_GetControlFromPanel(newOptionsPanel, 2), IEex_FetchString(13727)) -- "Cancel"

	-- Description Area - ID 3
	IEex_AddControlOverride("GUIOPT", 14, 3, "IEex_UI_TextArea")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.TEXT_AREA,
		["id"] = 3,
		["x"] = 438,
		["y"] = 71,
		["width"] = 270,
		["height"] = 253,
		["fontBam"] = "NORMAL",
		["scrollbarID"] = 4,
	})

	-- Description Area Scrollbar - ID 4
	IEex_AddControlOverride("GUIOPT", 14, 4, "IEex_UI_Scrollbar")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.SCROLL_BAR,
		["id"] = 4,
		["x"] = 717,
		["y"] = 69,
		["width"] = 12,
		["height"] = 257,
		["graphicsBam"] = "GBTNSCRL",
		["animationNumber"] = 0,
		["upArrowFrameUnpressed"] = 0,
		["upArrowFramePressed"] = 1,
		["downArrowFrameUnpressed"] = 2,
		["downArrowFramePressed"] = 3,
		["troughFrame"] = 4,
		["sliderFrame"] = 5,
		["textAreaID"] = 3,
	})

	-- "Transparent Fog of War" Label + Toggle - ID 5 / 6. Software-only (Export_RenderFoW early-returns
	-- in GL), so IEex_OptionRowVisible(5) hides it under GL. IEex_InitOptionButtons guards control 6 to match.
	if IEex_OptionRowVisible(5) then

	-- "Transparent Fog of War" Label - ID 5
	IEex_AddControlOverride("GUIOPT", 14, 5, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 5,
		["x"] = 24,
		["y"] = IEex_OptionRowY(5),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 5), IEex_FetchString(ex_tra_55902)) -- "Transparent Fog of War"

	-- "Transparent Fog of War" Toggle - ID 6
	IEex_AddControlOverride("GUIOPT", 14, 6, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 6,
		["x"] = 394,
		["y"] = IEex_OptionRowY(5) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	-- "Action Indicators" Label - ID 7
	IEex_AddControlOverride("GUIOPT", 14, 7, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 7,
		["x"] = 24,
		["y"] = IEex_OptionRowY(7),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 7), IEex_FetchString(ex_tra_55905)) -- "Action Indicators"

	-- "Action Indicators" Toggle - ID 8
	IEex_AddControlOverride("GUIOPT", 14, 8, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 8,
		["x"] = 394,
		["y"] = IEex_OptionRowY(7) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	-- "Highlight Empty Containers in Gray" Label - ID 9
	IEex_AddControlOverride("GUIOPT", 14, 9, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 9,
		["x"] = 24,
		["y"] = IEex_OptionRowY(9),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 9), IEex_FetchString(ex_tra_55907)) -- "Highlight Empty Containers in Gray"

	-- "Highlight Empty Containers in Gray" Toggle - ID 10
	IEex_AddControlOverride("GUIOPT", 14, 10, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 10,
		["x"] = 394,
		["y"] = IEex_OptionRowY(9) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	-- "Prevent Equipping Armor During Combat" Label - ID 11
	IEex_AddControlOverride("GUIOPT", 14, 11, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 11,
		["x"] = 24,
		["y"] = IEex_OptionRowY(11),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 11), IEex_FetchString(ex_tra_55931)) -- "Prevent Equipping Armor During Combat"

	-- "Prevent Equipping Armor During Combat" Toggle - ID 12
	IEex_AddControlOverride("GUIOPT", 14, 12, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 12,
		["x"] = 394,
		["y"] = IEex_OptionRowY(11) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	if IEex_OptionRowVisible(13) then

	-- "Stretch UI to Screen" Label - ID 13
	IEex_AddControlOverride("GUIOPT", 14, 13, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 13,
		["x"] = 24,
		["y"] = IEex_OptionRowY(13),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 13),
		IEex_OptionText(ex_tra_56079, "Stretch UI to Screen"))

	-- "Stretch UI to Screen" Toggle - ID 14
	IEex_AddControlOverride("GUIOPT", 14, 14, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 14,
		["x"] = 394,
		["y"] = IEex_OptionRowY(13) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	-- "Pixel-Perfect Zoom" Label + Toggle - ID 29 / 30. GL-only (the camera zoom is a GL matrix;
	-- the software renderer stays at 1.0), so IEex_OptionRowVisible(29) hides it in software.
	-- IEex_InitOptionButtons guards control 30 to match.
	if IEex_OptionRowVisible(29) then

	-- "Pixel-Perfect Zoom" Label - ID 29
	IEex_AddControlOverride("GUIOPT", 14, 29, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 29,
		["x"] = 24,
		["y"] = IEex_OptionRowY(29),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 29),
		IEex_OptionText(ex_tra_56091, "Pixel-perfect zoom"))

	-- "Pixel-Perfect Zoom" Toggle - ID 30
	IEex_AddControlOverride("GUIOPT", 14, 30, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 30,
		["x"] = 394,
		["y"] = IEex_OptionRowY(29) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	-- "Show FPS" Label - ID 15
	IEex_AddControlOverride("GUIOPT", 14, 15, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 15,
		["x"] = 24,
		["y"] = IEex_OptionRowY(15),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 15),
		IEex_OptionText(ex_tra_56081, "Show FPS"))

	-- "Show FPS" Toggle - ID 16
	IEex_AddControlOverride("GUIOPT", 14, 16, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 16,
		["x"] = 394,
		["y"] = IEex_OptionRowY(15) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	if IEex_OptionRowVisible(17) then

	-- "Vsync" Label - ID 17
	IEex_AddControlOverride("GUIOPT", 14, 17, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 17,
		["x"] = 24,
		["y"] = IEex_OptionRowY(17),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 17),
		IEex_OptionText(ex_tra_56083, "Vsync"))

	-- "Vsync" Toggle - ID 18
	IEex_AddControlOverride("GUIOPT", 14, 18, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 18,
		["x"] = 394,
		["y"] = IEex_OptionRowY(17) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	-- "UI Borders" Label - ID 19
	IEex_AddControlOverride("GUIOPT", 14, 19, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 19,
		["x"] = 24,
		["y"] = IEex_OptionRowY(19),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 19),
		IEex_OptionText(ex_tra_56085, "Decorative UI & HUD Borders (restart required)"))

	-- "UI Borders" Toggle - ID 20
	IEex_AddControlOverride("GUIOPT", 14, 20, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 20,
		["x"] = 394,
		["y"] = IEex_OptionRowY(19) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	if IEex_OptionRowVisible(21) then

	-- "Improved Pathfinding" Label - ID 21
	IEex_AddControlOverride("GUIOPT", 14, 21, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 21,
		["x"] = 24,
		["y"] = IEex_OptionRowY(21),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 21),
		IEex_OptionText(ex_tra_56087, "Improved Pathfinding (restart required)"))

	-- "Improved Pathfinding" Toggle - ID 22
	IEex_AddControlOverride("GUIOPT", 14, 22, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 22,
		["x"] = 394,
		["y"] = IEex_OptionRowY(21) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	if IEex_OptionRowVisible(23) then

	-- "Colored Portrait Frames" Label - ID 23
	IEex_AddControlOverride("GUIOPT", 14, 23, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 23,
		["x"] = 24,
		["y"] = IEex_OptionRowY(23),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 23),
		IEex_OptionText(ex_tra_56077, "Colored portrait frames"))

	-- "Colored Portrait Frames" Toggle - ID 24
	IEex_AddControlOverride("GUIOPT", 14, 24, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 24,
		["x"] = 394,
		["y"] = IEex_OptionRowY(23) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	-- (Row 25/26 was 'Cap FPS to Display Refresh', now hardwired via its ini key only: the cap needs
	-- a restart to take effect anyway, so [IEex Options] "Max FPS" in Icewind2.ini is enough and the
	-- slot goes to an option that applies live.)

	if IEex_OptionRowVisible(27) then

	-- "Colored Selection Circles" Label - ID 27
	IEex_AddControlOverride("GUIOPT", 14, 27, "IEex_UI_Label")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.LABEL,
		["id"] = 27,
		["x"] = 24,
		["y"] = IEex_OptionRowY(27),
		["width"] = 358,
		["height"] = 18,
		["fontBam"] = "NORMAL",
		["textFlags"] = 0x51, -- Use color(0) | Right justify(4) | Middle justify(6)
	})
	IEex_SetControlLabelText(IEex_GetControlFromPanel(newOptionsPanel, 27),
		IEex_OptionText(ex_tra_56075, "Colored selection circles"))

	-- "Colored Selection Circles" Toggle - ID 28
	IEex_AddControlOverride("GUIOPT", 14, 28, "IEex_UI_Button")
	IEex_AddControlToPanel(newOptionsPanel, {
		["type"] = IEex_ControlStructType.BUTTON,
		["id"] = 28,
		["x"] = 394,
		["y"] = IEex_OptionRowY(27) - 3,
		["width"] = 23,
		["height"] = 24,
		["bam"] = "GBTNOPT3",
		["frameUnpressed"] = 1,
		["framePressed"] = 2,
	})

	end

	IEex_SetPanelActive(newOptionsPanel, false)
end

-- Use this function to modify existing panels / controls. The engine has been semi-initialized at this point, and the
-- passed `chuResref` signifies that the given .CHU has been fully created, and that its UI structures can be accessed.

function IEex_OnCHUInitialized(chuResref)

	if chuResref == "GUIW08" or chuResref == "GUIW10" then

		local worldScreen = IEex_GetEngineWorld()

		----------------------------------------
		-- Fix incorrect vanilla press-frames --
		----------------------------------------

		local panel8Memory = IEex_GetPanelFromEngine(worldScreen, 8)
		for i = 6, 9 do
			local fixControl = IEex_GetControlFromPanel(panel8Memory, i)
			IEex_SetControlButtonFrameDown(fixControl, 0)
		end

		----------------------------
		-- Widescreen Adjustments --
		----------------------------

		local resW, resH = IEex_GetResolution()

		local panel0Memory = IEex_GetPanelFromEngine(worldScreen, 0)
		local panel1Memory = IEex_GetPanelFromEngine(worldScreen, 1)
		local panel6Memory = IEex_GetPanelFromEngine(worldScreen, 6)
		local panel7Memory = IEex_GetPanelFromEngine(worldScreen, 7)
		local panel8Memory = IEex_GetPanelFromEngine(worldScreen, 8)
		local panel9Memory = IEex_GetPanelFromEngine(worldScreen, 9)
		local panel17Memory = IEex_GetPanelFromEngine(worldScreen, 17)

		local control_9_0_Memory = IEex_GetControlFromPanel(panel9Memory, 0)

		local x0, y0, w0, h0 = IEex_GetPanelArea(panel0Memory)
		local x1, y1, w1, h1 = IEex_GetPanelArea(panel1Memory)
		local x6, y6, w6, h6 = IEex_GetPanelArea(panel6Memory)
		local x7, y7, w7, h7 = IEex_GetPanelArea(panel7Memory)
		local x8, y8, w8, h8 = IEex_GetPanelArea(panel8Memory)
		local x9, y9, w9, h9 = IEex_GetPanelArea(panel7Memory)
		local x17, y17, w17, h17 = IEex_GetPanelArea(panel17Memory)

		local x_9_0, y_9_0, w_9_0, h_9_0 = IEex_GetControlArea(control_9_0_Memory)

		local toolbarBottom = resH - h0

		IEex_SetPanelXY(panel0Memory, (resW - w0) / 2, toolbarBottom)
		IEex_SetPanelXY(panel1Memory, (resW - w1) / 2, toolbarBottom - h1, true)

		-- Horizontal centring width for the dialog-family panels below (6 console / 7 SP-dialog /
		-- 8 container / 9 button / 17 death). Under the Floating HUD (refonte) the DLL's Stage-2 GL
		-- transform scales the whole world HUD about the bottom-LEFT (Export_UIScaleRenderBegin, cx=0)
		-- over a virtual reference-width canvas Wv = max(resW, "Floating HUD Ref Width"), so a panel
		-- centred on the PHYSICAL width lands at screen-x = ((resW-w)/2)*s -- left-of-centre and
		-- undersized whenever resW < RefWidth (identity only at the author's 4K == RefWidth). Centre
		-- these on the SAME canvas the refonte lays its own panels on: (centerW - w)/2 maps back to a
		-- true screen-centre of resW/2. Gate = IEex_InstallPortraitGrid's own hard requirements
		-- (GUIW10 + GL) so the stock/classic HUD (bottom-CENTRE pivot, where resW-centred is correct)
		-- is untouched; and the canvas only diverges from resW under the engine 2x tier (m_bUseNewGui
		-- @0x8CF6DC+0x4A28, == the DLL's UIMult) -- at 1x GetRefonteHudRefWidth returns resW, so
		-- centerW == resW and nothing changes. (MP dialog = panel 21, never re-centred here: separate.)
		local centerW = resW
		local refonteChitin = IEex_ReadDword(0x8CF6D8)
		if not IEex_Vanilla and IEex_PortraitGridEnabled and chuResref == "GUIW10"
			and refonteChitin ~= 0x0 and IEex_ReadDword(refonteChitin + 0x91C) ~= 0x0
			and IEex_ReadByte(IEex_ReadDword(0x8CF6DC) + 0x4A28, 0) ~= 0
		then
			local refW = IEex_GetPrivateProfileInt("IEex Options", "Floating HUD Ref Width", 3840, ".\\Icewind2.ini")
			if refW < 2560 then refW = 2560 end
			if refW > 7680 then refW = 7680 end
			centerW = math.max(resW, refW)
		end

		-- Debug console (cheat bar, panel 6): every other panel here re-centres with its
		-- OWN width read back from the panel -- already doubled by fInit under the 2x UI
		-- (m_bUseNewGui) -- but this one hardcodes the CHU design width 800. Under 2x the
		-- art/font render 1600px wide into an 800px panel: the bar showed only its left
		-- half (~47 chars of a paste), mosaic cut mid-pattern. Scale the literal by the
		-- UI multiplier; identity at 1x / software, so vanilla placement is unchanged.
		local consoleW = 800 * (IEex_ReadByte(IEex_ReadDword(0x8CF6DC) + 0x4A28, 0) == 1 and 2 or 1)
		IEex_SetPanelArea(panel6Memory, (centerW - consoleW) / 2, resH - h6, consoleW)
		IEex_SetPanelXY(panel7Memory, (centerW - w7) / 2, resH - h7)
		IEex_SetPanelXY(panel8Memory, (centerW - w8) / 2, resH - h8)
		IEex_SetPanelArea(panel9Memory, (centerW - w_9_0) / 2, resH - h_9_0 - 4, w_9_0, h_9_0)
		IEex_SetPanelXY(panel17Memory, (centerW - w17) / 2, resH - h17)

		IEex_SetControlXY(control_9_0_Memory, 0, 0)

		---------------
		-- Quickloot --
		---------------

		if not IEex_Vanilla then
			IEex_InstallQuickloot(chuResref)
		end

		if not IEex_Vanilla and IEex_PortraitGridEnabled then
			IEex_InstallPortraitGrid(chuResref)
		end

		-----------------------
		-- Action Indicators --
		-----------------------

		if not IEex_Vanilla then
			IEex_InstallActionIndicators()
		end

		----------------------------------
		-- Worldscreen Spell Info Popup --
		----------------------------------

		if not IEex_Vanilla then

			-- IEex Spell Info - Panel ID <IEex_WorldScreenSpellInfoPanelID>
			local newSpellInfoPanel = IEex_AddPanelToEngine(worldScreen, {
				["id"] = IEex_WorldScreenSpellInfoPanelID,
				["width"] = 429,
				["height"] = 446,
				["hasBackground"] = 1,
				["backgroundImage"] = "GUISPLHB",
			})

			-- "Spell information" label - Control ID 0
			IEex_AddControlOverride(chuResref, IEex_WorldScreenSpellInfoPanelID, 0, "IEex_UI_Label")
			IEex_AddControlToPanel(newSpellInfoPanel, {
				["type"] = IEex_ControlStructType.LABEL,
				["id"] = 0,
				["x"] = 22,
				["y"] = 22,
				["width"] = 343,
				["height"] = 20,
				["initialTextStrref"] = 16189, -- "Spell Information"
				["fontBam"] = "NORMAL",
				["fontColor1"] = 0xFFFFFF,
				["textFlags"] = 0x45, -- Use color(0) | Center justify(4) | Middle justify(6)
			})

			-- Spell name label - Control ID 1
			IEex_AddControlOverride(chuResref, IEex_WorldScreenSpellInfoPanelID, 1, "IEex_UI_Label")
			IEex_AddControlToPanel(newSpellInfoPanel, {
				["type"] = IEex_ControlStructType.LABEL,
				["id"] = 1,
				["x"] = 22,
				["y"] = 52,
				["width"] = 343,
				["height"] = 20,
				["fontBam"] = "NORMAL",
				["fontColor1"] = 0xFFFFFF,
				["textFlags"] = 0x45, -- Use color(0) | Center justify(4) | Middle justify(6)
			})

			-- Spell icon - Control ID 2
			IEex_AddControlOverride(chuResref, IEex_WorldScreenSpellInfoPanelID, 2, "ButtonMageSpellInfoIcon")
			IEex_AddControlToPanel(newSpellInfoPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 2,
				["x"] = 375,
				["y"] = 22,
				["bam"] = "",
				["width"] = 32,
				["height"] = 32,
			})

			-- Spell description area - Control ID 3
			IEex_AddControlOverride(chuResref, IEex_WorldScreenSpellInfoPanelID, 3, "IEex_UI_TextArea")
			IEex_AddControlToPanel(newSpellInfoPanel, {
				["type"] = IEex_ControlStructType.TEXT_AREA,
				["id"] = 3,
				["x"] = 23,
				["y"] = 83,
				["width"] = 363,
				["height"] = 312,
				["fontBam"] = "NORMAL",
				["scrollbarID"] = 4,
			})

			-- Spell description area scrollbar - Control ID 4
			IEex_AddControlOverride(chuResref, IEex_WorldScreenSpellInfoPanelID, 4, "IEex_UI_Scrollbar")
			IEex_AddControlToPanel(newSpellInfoPanel, {
				["type"] = IEex_ControlStructType.SCROLL_BAR,
				["id"] = 4,
				["x"] = 396,
				["y"] = 82,
				["width"] = 12,
				["height"] = 313,
				["graphicsBam"] = "GBTNSCRL",
				["animationNumber"] = 0,
				["upArrowFrameUnpressed"] = 0,
				["upArrowFramePressed"] = 1,
				["downArrowFrameUnpressed"] = 2,
				["downArrowFramePressed"] = 3,
				["troughFrame"] = 4,
				["sliderFrame"] = 5,
				["textAreaID"] = 3,
			})

			-- "Done" - Control ID 5
			IEex_AddControlOverride(chuResref, IEex_WorldScreenSpellInfoPanelID, 5, "IEex_UI_Button")
			IEex_AddControlToPanel(newSpellInfoPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 5,
				["x"] = 135,
				["y"] = 402,
				["width"] = 156,
				["height"] = 24,
				["bam"] = "GBTNMED",
				["frameUnpressed"] = 1,
				["framePressed"] = 2,
				["frameDisabled"] = 3,
			})
			IEex_SetControlButtonText(IEex_GetControlFromPanel(newSpellInfoPanel, 5), IEex_FetchString(11973))

			IEex_SetPanelActive(newSpellInfoPanel, false)

			---------------------------------
			-- Worldscreen Item Info Popup --
			---------------------------------

			-- Items get a dedicated panel modelled on the stock inventory "Item" popup (GUIINV panel 5):
			-- static "Item" title, item name in yellow above the description, full-size 64x64 icon.
			-- No def x/y (like the spell-info panel): the popup is centred every frame by SetPanelXY in
			-- the worldscreen position pass, which moves the panel m_ptOrigin so the engine
			-- MageSpellInfoIcon (rendered at m_pPanel->m_ptOrigin + m_ptOrigin) stays in the frame.
			local newItemInfoPanel = IEex_AddPanelToEngine(worldScreen, {
				["id"] = IEex_WorldScreenItemInfoPanelID,
				["width"] = 513,
				["height"] = 481,
				["hasBackground"] = 1,
				["backgroundImage"] = "GIITMH08",
			})

			-- "Item" title label - Control ID 0 (static text)
			IEex_AddControlOverride(chuResref, IEex_WorldScreenItemInfoPanelID, 0, "IEex_UI_Label")
			IEex_AddControlToPanel(newItemInfoPanel, {
				["type"] = IEex_ControlStructType.LABEL,
				["id"] = 0,
				["x"] = 36,
				["y"] = 37,
				["width"] = 357,
				["height"] = 30,
				["initialTextStrref"] = 15120, -- "Item"
				["fontBam"] = "STONEBIG",
				["fontColor1"] = 0xFFFFF6,
				["textFlags"] = 0x46, -- Use color(0) | Center justify(4) | Middle justify(6)
			})

			-- Item name label (yellow) - Control ID 1
			IEex_AddControlOverride(chuResref, IEex_WorldScreenItemInfoPanelID, 1, "IEex_UI_Label")
			IEex_AddControlToPanel(newItemInfoPanel, {
				["type"] = IEex_ControlStructType.LABEL,
				["id"] = 1,
				["x"] = 26,
				["y"] = 111,
				["width"] = 290,
				["height"] = 18,
				["fontBam"] = "NORMAL",
				["fontColor1"] = 0xC8C8, -- RGB(200,200,0) yellow, as the inventory item name
				["textFlags"] = 0x49,
			})

			-- Item icon - Control ID 2 (64x64 cell, sized for item icons like the inventory). Uses the
			-- inventory's own item-icon control (InventoryHistoryIcon) rather than the spell-icon control:
			-- its Render adds the item BAM's centre-point offset, so the icon sits in the frame slot.
			IEex_AddControlOverride(chuResref, IEex_WorldScreenItemInfoPanelID, 2, "InventoryHistoryIcon")
			IEex_AddControlToPanel(newItemInfoPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 2,
				["x"] = 429,
				["y"] = 20,
				["bam"] = "",
				["width"] = 64,
				["height"] = 64,
			})

			-- Item description area - Control ID 3
			IEex_AddControlOverride(chuResref, IEex_WorldScreenItemInfoPanelID, 3, "IEex_UI_TextArea")
			IEex_AddControlToPanel(newItemInfoPanel, {
				["type"] = IEex_ControlStructType.TEXT_AREA,
				["id"] = 3,
				["x"] = 23,
				["y"] = 132,
				["width"] = 445,
				["height"] = 286,
				["fontBam"] = "NORMAL",
				["scrollbarID"] = 4,
			})

			-- Item description area scrollbar - Control ID 4
			IEex_AddControlOverride(chuResref, IEex_WorldScreenItemInfoPanelID, 4, "IEex_UI_Scrollbar")
			IEex_AddControlToPanel(newItemInfoPanel, {
				["type"] = IEex_ControlStructType.SCROLL_BAR,
				["id"] = 4,
				["x"] = 480,
				["y"] = 131,
				["width"] = 12,
				["height"] = 287,
				["graphicsBam"] = "GBTNSCRL",
				["animationNumber"] = 0,
				["upArrowFrameUnpressed"] = 0,
				["upArrowFramePressed"] = 1,
				["downArrowFrameUnpressed"] = 2,
				["downArrowFramePressed"] = 3,
				["troughFrame"] = 4,
				["sliderFrame"] = 5,
				["textAreaID"] = 3,
			})

			-- "Done" - Control ID 5
			IEex_AddControlOverride(chuResref, IEex_WorldScreenItemInfoPanelID, 5, "IEex_UI_Button")
			IEex_AddControlToPanel(newItemInfoPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 5,
				["x"] = 178,
				["y"] = 445,
				["width"] = 156,
				["height"] = 24,
				["bam"] = "GBTNMED",
				["frameUnpressed"] = 1,
				["framePressed"] = 2,
				["frameDisabled"] = 3,
			})
			IEex_SetControlButtonText(IEex_GetControlFromPanel(newItemInfoPanel, 5), IEex_FetchString(11973))

			IEex_SetPanelActive(newItemInfoPanel, false)

			local commandsPanel = IEex_GetPanelFromEngine(worldScreen, 0)
			local quicklootButtonX = 705
			local quicklootButtonY = 73
			if chuResref == "GUIW10" then
				quicklootButtonX = 817
			end
			-- Refonte: the quickloot toggle takes slot 10 of the command band. Its art is now
			-- a bare 47x40 cell icon (like the other command buttons) that fills the slot --
			-- no centering. Slots are DEVICE px; this control is added through the ctor path
			-- which re-doubles 1x-authored coords at the 2x tier -- pre-divide like
			-- IEex_InstallQuickloot does.
			if IEex_PortraitGridEnabled and IEex_Refonte_CmdSlots then
				local sl = IEex_Refonte_CmdSlots[10]
				local mgrQL = IEex_GetUIManagerFromEngine(worldScreen)
				local divQL = (mgrQL ~= 0 and IEex_ReadDword(mgrQL + 0xAA) ~= 0) and 2 or 1
				quicklootButtonX = math.floor(sl.x / divQL)
				quicklootButtonY = math.floor(sl.y / divQL)
			end
			local commandsPanelMultiplayer = IEex_GetPanelFromEngine(worldScreen, 22)
			IEex_AddControlOverride(chuResref, 0, 15, "IEex_UI_Button")
			IEex_AddControlToPanel(commandsPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 15,
				["x"] = quicklootButtonX,
				["y"] = quicklootButtonY,
				["width"] = 47,
				["height"] = 40,
				["bam"] = "USGBTNQL",
				["sequence"] = 0,
				["frameUnpressed"] = 0,
				["framePressed"] = 1,
				["frameDisabled"] = 0,
				["tooltipStrref"] = ex_tra_55927,
				["customHotkeyHintIndex"] = IEex_Hotkeys_CustomBinding.TOGGLE_QUICKLOOT,
			})

			IEex_AddControlOverride(chuResref, 22, 15, "IEex_UI_Button")
			IEex_AddControlToPanel(commandsPanelMultiplayer, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 15,
				["x"] = quicklootButtonX,
				["y"] = 73,
				["width"] = 47,
				["height"] = 40,
				["bam"] = "USGBTNQL",
				["sequence"] = 0,
				["frameUnpressed"] = 0,
				["framePressed"] = 1,
				["frameDisabled"] = 0,
				["tooltipStrref"] = ex_tra_55927,
				["customHotkeyHintIndex"] = IEex_Hotkeys_CustomBinding.TOGGLE_QUICKLOOT,
			})

			-- Refonte: the log box's TOP BORDER is the resize control, in two halves --
			--   ctrl 16 = the invisible full-width click strip (transparent IEEXNULB), so the
			--             whole border stays clickable as it always has been;
			--   ctrl 17 = the visible chevron tab (IEEXRSZB) centred on it, which is what
			--             actually tells the player the border is interactive.
			-- Both cycle the height presets, and both carry the tooltip so hovering ANYWHERE
			-- on the border explains the feature -- not just the tab itself.
			-- ORDER MATTERS, don't swap the two blocks: the rects overlap, and CUIPanel walks
			-- its control list TAIL-first for input (OnLButtonDown 0x4D2D80) but HEAD-first
			-- for render (0x4D3100). Adding 17 last therefore gives it both the click (tab shows
			-- its pressed frame instead of the strip silently eating the press) and the top
			-- of the draw order.
			if IEex_PortraitGridEnabled and IEex_Refonte_LogRect then
				local mgrLS = IEex_GetUIManagerFromEngine(worldScreen)
				local divLS = (mgrLS ~= 0 and IEex_ReadDword(mgrLS + 0xAA) ~= 0) and 2 or 1
				local lr = IEex_Refonte_LogRect
				local oR = IEex_Refonte_P0Origin
				local tabW = IEex_Refonte_LogTabW or 38 * IEex_Refonte_Scale
				local tabH = IEex_Refonte_LogTabH or 13 * IEex_Refonte_Scale
				IEex_AddControlOverride(chuResref, 0, 16, "IEex_UI_Button")
				IEex_AddControlToPanel(commandsPanel, {
					["type"] = IEex_ControlStructType.BUTTON,
					["id"] = 16,
					["x"] = math.floor((lr.x - oR.x) / divLS),
					["y"] = math.floor((lr.y - oR.y) / divLS),
					["width"] = math.floor(lr.w / divLS),
					["height"] = math.floor((12 * IEex_Refonte_Scale) / divLS),
					["bam"] = "IEEXNULB",
					["sequence"] = 0,
					["frameUnpressed"] = 0,
					["framePressed"] = 0,
					["frameDisabled"] = 0,
					["tooltipStrref"] = ex_tra_55933,
				})
				IEex_SetControlButtonPlayLButtonDownSound(IEex_GetControlFromPanel(commandsPanel, 16), false)

				IEex_AddControlOverride(chuResref, 0, 17, "IEex_UI_Button")
				IEex_AddControlToPanel(commandsPanel, {
					["type"] = IEex_ControlStructType.BUTTON,
					["id"] = 17,
					["x"] = math.floor((lr.x + math.floor((lr.w - tabW) / 2) - oR.x) / divLS),
					["y"] = math.floor((lr.y - oR.y) / divLS),
					["width"] = math.floor(tabW / divLS),
					["height"] = math.floor(tabH / divLS),
					["bam"] = "IEEXRSZB",
					["sequence"] = 0,
					["frameUnpressed"] = 0,
					["framePressed"] = 1,
					["frameDisabled"] = 0,
					["tooltipStrref"] = ex_tra_55933,
				})

				-- Both controls exist now: re-run the placer so their rects come from the
				-- one function that owns log geometry, instead of the divLS arithmetic above
				-- (which only exists because the control CTOR doubles world-manager coords).
				IEex_Refonte_ApplyLogHeight(IEex_Refonte_LogHeightIdx)
			end
		end

	elseif chuResref == "GUIREC" then

		if not IEex_Vanilla then

			local screenCharacter = IEex_GetEngineCharacter()
			local newWizardSpellsPanel = IEex_AddPanelToEngine(screenCharacter, {
				["id"] = 58,
				["x"] = 245,
				["width"] = 555,
				["height"] = 433,
				["hasBackground"] = 1,
				["backgroundImage"] = "GUIRLVL5",
				["flags"] = 0x1,
			})
			local buttonID = 0

			for i = 0, 4, 1 do
				for j = 0, 5, 1 do
					IEex_AddControlOverride("GUIREC", 58, buttonID, "IEex_UI_Button")
					IEex_AddControlToPanel(newWizardSpellsPanel, {
						["type"] = IEex_ControlStructType.BUTTON,
						["id"] = buttonID,
						["x"] = 14 + 43 * j,
						["y"] = 76 + 43 * i,
						["width"] = 40,
						["height"] = 39,
						["bam"] = "SPLBUT",
						["frameUnpressed"] = 1,
						["framePressed"] = 2,
						["frameDisabled"] = 3,
					})
					IEex_AddControlOverride("GUIREC", 58, (buttonID + 100), "ButtonMageSpellInfoIcon")
					IEex_AddControlToPanel(newWizardSpellsPanel, {
						["type"] = IEex_ControlStructType.BUTTON,
						["id"] = (buttonID + 100),
						["x"] = 18 + 43 * j,
						["y"] = 79 + 43 * i,
						["bam"] = "",
						["width"] = 32,
						["height"] = 32,
					})
					buttonID = buttonID + 1
				end
			end

			IEex_AddControlOverride("GUIREC", 58, 30, "IEex_UI_TextArea")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.TEXT_AREA,
				["id"] = 30,
				["x"] = 305,
				["y"] = 26,
				["width"] = 207,
				["height"] = 339,
				["fontBam"] = "NORMAL",
				["scrollbarID"] = 31,
			})

			IEex_AddControlOverride("GUIREC", 58, 31, "IEex_UI_Scrollbar")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.SCROLL_BAR,
				["id"] = 31,
				["x"] = 523,
				["y"] = 23,
				["width"] = 12,
				["height"] = 348,
				["graphicsBam"] = "GBTNSCRL",
				["animationNumber"] = 0,
				["upArrowFrameUnpressed"] = 0,
				["upArrowFramePressed"] = 1,
				["downArrowFrameUnpressed"] = 2,
				["downArrowFramePressed"] = 3,
				["troughFrame"] = 4,
				["sliderFrame"] = 5,
				["textAreaID"] = 30,
			})

			IEex_AddControlOverride("GUIREC", 58, 32, "IEex_UI_Button")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 32,
				["x"] = 298,
				["y"] = 382,
				["width"] = 117,
				["height"] = 25,
				["bam"] = "GBTNSTD",
				["sequence"] = 0,
				["frameUnpressed"] = 1,
				["framePressed"] = 2,
				["frameDisabled"] = 3,
			})
			IEex_SetControlButtonText(IEex_GetControlFromPanel(newWizardSpellsPanel, 32), IEex_FetchString(ex_tra_55770))

			IEex_AddControlOverride("GUIREC", 58, 33, "IEex_UI_Label")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.LABEL,
				["id"] = 33,
				["x"] = 10,
				["y"] = 23,
				["width"] = 205,
				["height"] = 28,
				["fontBam"] = "NORMAL",
				["fontColor1"] = 0xFFFFF6,
				["textFlags"] = 0x45, -- Use color(0) | Center justify(4) | Middle justify(6)
			})

			IEex_AddControlOverride("GUIREC", 58, 34, "IEex_UI_Label")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.LABEL,
				["id"] = 34,
				["x"] = 226,
				["y"] = 23,
				["width"] = 50,
				["height"] = 28,
				["fontBam"] = "NORMAL",
				["fontColor1"] = 0xFFFF,
				["textFlags"] = 0x45, -- Use color(0) | Center justify(4) | Middle justify(6)
			})

			IEex_AddControlOverride("GUIREC", 58, 35, "IEex_UI_Button")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 35,
				["x"] = 419,
				["y"] = 382,
				["width"] = 117,
				["height"] = 25,
				["bam"] = "GBTNSTD",
				["sequence"] = 1,
				["frameUnpressed"] = 1,
				["framePressed"] = 2,
				["frameDisabled"] = 3,
			})
			IEex_SetControlButtonText(IEex_GetControlFromPanel(newWizardSpellsPanel, 35), IEex_FetchString(11973))

			IEex_AddControlOverride("GUIREC", 58, 36, "IEex_UI_Button")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 36,
				["x"] = 14,
				["y"] = 300,
				["width"] = 47,
				["height"] = 39,
				["bam"] = "GBTNJBTN",
				["sequence"] = 0,
				["frameUnpressed"] = 1,
				["framePressed"] = 2,
				["frameDisabled"] = 3,
			})

			IEex_AddControlOverride("GUIREC", 58, 37, "IEex_UI_Button")
			IEex_AddControlToPanel(newWizardSpellsPanel, {
				["type"] = IEex_ControlStructType.BUTTON,
				["id"] = 37,
				["x"] = 222,
				["y"] = 300,
				["width"] = 47,
				["height"] = 39,
				["bam"] = "GBTNJBTN",
				["sequence"] = 1,
				["frameUnpressed"] = 1,
				["framePressed"] = 2,
				["frameDisabled"] = 3,
			})

			IEex_SetPanelActive(newWizardSpellsPanel, false)
		end

	elseif chuResref == "GUIOPT" then

		------------------
		-- IEex Options --
		------------------

		if not IEex_Vanilla then
			IEex_InstallIEexOptions()
		end

	elseif chuResref == "GUIKEYS" then

		-----------------------
		-- GUIKEYS Expansion --
		-----------------------

		if not IEex_Vanilla then

			local screenKeys = IEex_GetEngineKeys()

			local panel0 = IEex_GetPanelFromEngine(screenKeys, 0)
			IEex_SetPanelMosaicResref(panel0, "B3KEYS")

			local curNameControlId = 0x10000005 + 60
			local curValueControlId = 0x10000005

			for columnI = 0, 2 do

				local firstValueControlOfColumn = IEex_GetControlFromPanel(panel0, curValueControlId)
				local firstValueControlOfColumnX, firstValueControlOfColumnY, firstValueControlOfColumnW = IEex_GetControlArea(firstValueControlOfColumn)

				-- Divider placement under HD UI (2x): this menu's UI manager is in double-size mode
				-- (mgrDbl == 1), so the control ctor inside IEex_AddControlToPanel DOUBLES x/y/w/h.
				-- The coords we read via IEex_GetControlArea are already in that final 2x space, so
				-- passing one straight back stores it at 2x the intended spot -- the divider lands a
				-- whole column to the right and slices the names there (that was the "cut text" bug,
				-- NOT name overflow -- the names fit). So: let the ctor double width/height (the 5x399
				-- bars fill the resulting 10x798 rect and span the full list), then overwrite x/y with
				-- IEex_SetControlArea, which writes m_ptOrigin DIRECTLY (no doubling) -- placing each
				-- divider exactly where the stock layout wants it (left bar between name and key, right
				-- bar just past the key), matching the stock keyboard screen.

				-- Install left divider for column (between the name and key)
				local lDividerId = 6 + columnI * 2
				IEex_AddControlOverride("GUIKEYS", 0, lDividerId, "IEex_UI_Button")
				IEex_AddControlToPanel(panel0, {
					["type"] = IEex_ControlStructType.BUTTON,
					["id"] = lDividerId,
					["x"] = 0,
					["y"] = 0,
					["width"] = 5,
					["height"] = 399,
					["bam"] = "B3LDVIDR",
					["sequence"] = columnI % 3,
					["playLButtonDownSound"] = false,
				})
				IEex_SetControlArea(IEex_GetControlFromPanel(panel0, lDividerId),
					firstValueControlOfColumnX - IEex_Hotkeys_ValueControlExpansion - 5, firstValueControlOfColumnY - 1)

				-- Install right divider for column (just past the key)
				local rDividerId = 7 + columnI * 2
				IEex_AddControlOverride("GUIKEYS", 0, rDividerId, "IEex_UI_Button")
				IEex_AddControlToPanel(panel0, {
					["type"] = IEex_ControlStructType.BUTTON,
					["id"] = rDividerId,
					["x"] = 0,
					["y"] = 0,
					["width"] = 5,
					["height"] = 399,
					["bam"] = "B3RDVIDR",
					["sequence"] = columnI % 2,
					["playLButtonDownSound"] = false,
				})
				IEex_SetControlArea(IEex_GetControlFromPanel(panel0, rDividerId),
					firstValueControlOfColumnX + firstValueControlOfColumnW, firstValueControlOfColumnY - 1)

				-- Increase keybind mapping widths (taken from name labels)
				for i = 1, 20 do

					local nameControl = IEex_GetControlFromPanel(panel0, curNameControlId)
					local valueControl = IEex_GetControlFromPanel(panel0, curValueControlId)

					local nameX, _, nameW = IEex_GetControlArea(nameControl)
					local valueX, _, valueW = IEex_GetControlArea(valueControl)

					IEex_SetControlArea(nameControl, nameX, nil, nameW - IEex_Hotkeys_ValueControlExpansion)
					IEex_SetControlArea(valueControl, valueX - IEex_Hotkeys_ValueControlExpansion, nil, valueW + IEex_Hotkeys_ValueControlExpansion)

					curNameControlId = curNameControlId + 1
					curValueControlId = curValueControlId + 1
				end
			end
		end
	end
end

------------------
-- IEex Options --
------------------

IEex_Helper_InitBridgeFromTable("IEex_Options", {
	["options"] = {
		["actionIndicators"] = false,
		["transparentFogOfWar"] = false,
	},
	["workingOptions"] = {},
	["fogTypePtr"] = 0x0,
})

IEex_AbsoluteOnce("IEex_InitFogTypePtr", function()
	IEex_FogTypePtr = IEex_Malloc(0x4)
	IEex_WriteDword(IEex_FogTypePtr, IEex_Helper_GetBridgePtr("IEex_Options", "options", "transparentFogOfWar"))
	IEex_Helper_SetBridge("IEex_Options", "fogTypePtr", IEex_FogTypePtr)
end)
IEex_FogTypePtr = IEex_FogTypePtr or IEex_Helper_GetBridge("IEex_Options", "fogTypePtr")

function IEex_LoadOptions()

	local options = IEex_Helper_GetBridge("IEex_Options", "options")

	IEex_Helper_SetBridge(options, "transparentFogOfWar",
		IEex_GetPrivateProfileInt("IEex Options", "Transparent Fog of War", 0, ".\\Icewind2.ini") ~= 0 and true or false)

	-- IEex_FogTypePtr points at this byte; in GL force it 0 so the FoW asm hooks (RenderFoWSolid /
	-- RenderFoW / sprite-interlace / ground-pile) stay inert even if the ini still holds 1 from a
	-- prior software-mode session. The ini value is left untouched (IEex_WriteOptions skips the key
	-- in GL), so software mode keeps the user's preference.
	if IEEX_GL_ACTIVE then
		IEex_Helper_SetBridge(options, "transparentFogOfWar", false)
	end

	IEex_Helper_SetBridge(options, "actionIndicators",
		IEex_GetPrivateProfileInt("IEex Options", "Action Indicators", 1, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "highlightEmptyContainersInGray",
		IEex_GetPrivateProfileInt("IEex Options", "Highlight Empty Containers in Gray", 1, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "preventEquippingArmorDuringCombat",
		IEex_GetPrivateProfileInt("IEex Options", "Prevent Equipping Armor During Combat", 0, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "stretchUI",
		IEex_GetPrivateProfileInt("IEex Options", "Stretch UI to Screen", 0, ".\\Icewind2.ini") ~= 0 and true or false)

	-- Consumed by the DLL (ZoomApplyTicks re-reads the ini on each wheel event), not through the
	-- bridge -- the bridge copy exists only to drive the menu row.
	IEex_Helper_SetBridge(options, "integerZoom",
		IEex_GetPrivateProfileInt("IEex Options", "Integer Zoom", 0, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "showFps",
		IEex_GetPrivateProfileInt("IEex Options", "Show FPS", 0, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "vsync",
		IEex_GetPrivateProfileInt("IEex Options", "Vsync", 1, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "uiBorders",
		IEex_GetPrivateProfileInt("IEex Options", "UI Borders", 1, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "improvedPathfinding",
		IEex_GetPrivateProfileInt("IEex Options", "Improved Pathfinding", 1, ".\\Icewind2.ini") ~= 0 and true or false)

	IEex_Helper_SetBridge(options, "coloredPortraitFrames",
		IEex_GetPrivateProfileInt("IEex Options", "Colored Portrait Frames", 0, ".\\Icewind2.ini") ~= 0 and true or false)

	-- ("Max FPS" has no bridge entry: the frame cap is read straight from the ini by the DLL
	-- (thread_hooks.cpp) and needs a restart anyway, so it has no menu row to drive.)

	-- No bridge entry for keys that lost their row (Tile Atlas, Smooth Cursor): the bridge is
	-- only the panel's edit buffer, and IEex_WriteOptions rewrites every key it holds on each
	-- "Done" -- so a UI-less key would silently normalise (and clobber) a hand-edited value.
	-- Their consumers read the ini directly: IEex_HDTiles_Patch.lua for Tile Atlas, the
	-- RenderPointer3d prologue in IEexHelper for Smooth Cursor.
	IEex_Helper_SetBridge(options, "coloredCircles",
		IEex_GetPrivateProfileInt("IEex Options", "Colored Selection Circles", 0, ".\\Icewind2.ini") ~= 0 and true or false)
end

function IEex_WriteOptions()

	local options = IEex_Helper_GetBridge("IEex_Options", "options")

	-- In GL the runtime value is force-false (see IEex_LoadOptions); skip the write so we don't
	-- clobber the player's software-mode preference stored in the ini.
	if not IEEX_GL_ACTIVE then
		IEex_WritePrivateProfileString("IEex Options", "Transparent Fog of War",
			IEex_Helper_GetBridge(options, "transparentFogOfWar") and "1" or "0", ".\\Icewind2.ini")
	end

	IEex_WritePrivateProfileString("IEex Options", "Action Indicators",
		IEex_Helper_GetBridge(options, "actionIndicators") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Highlight Empty Containers in Gray",
		IEex_Helper_GetBridge(options, "highlightEmptyContainersInGray") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Prevent Equipping Armor During Combat",
		IEex_Helper_GetBridge(options, "preventEquippingArmorDuringCombat") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Stretch UI to Screen",
		IEex_Helper_GetBridge(options, "stretchUI") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Integer Zoom",
		IEex_Helper_GetBridge(options, "integerZoom") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Show FPS",
		IEex_Helper_GetBridge(options, "showFps") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Vsync",
		IEex_Helper_GetBridge(options, "vsync") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "UI Borders",
		IEex_Helper_GetBridge(options, "uiBorders") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Improved Pathfinding",
		IEex_Helper_GetBridge(options, "improvedPathfinding") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Colored Selection Circles",
		IEex_Helper_GetBridge(options, "coloredCircles") and "1" or "0", ".\\Icewind2.ini")

	IEex_WritePrivateProfileString("IEex Options", "Colored Portrait Frames",
		IEex_Helper_GetBridge(options, "coloredPortraitFrames") and "1" or "0", ".\\Icewind2.ini")
end

function IEex_InitOptionButtons()

	local screenOptions = IEex_GetEngineOptions()
	local newOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 14)
	local options = IEex_Helper_GetBridge("IEex_Options", "options")

	IEex_SetTextAreaToString(screenOptions, 14, 3, "")

	if IEex_OptionRowVisible(5) then -- control 6 ("Transparent Fog of War"): software-only
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 6),
			IEex_Helper_GetBridge(options, "transparentFogOfWar") and 3 or 1)
	end

	IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 8),
		IEex_Helper_GetBridge(options, "actionIndicators") and 3 or 1)

	IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 10),
		IEex_Helper_GetBridge(options, "highlightEmptyContainersInGray") and 3 or 1)

	IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 12),
		IEex_Helper_GetBridge(options, "preventEquippingArmorDuringCombat") and 3 or 1)

	if IEex_OptionRowVisible(13) then
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 14),
			IEex_Helper_GetBridge(options, "stretchUI") and 3 or 1)
	end

	if IEex_OptionRowVisible(29) then -- control 30 ("Pixel-Perfect Zoom"): GL-only
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 30),
			IEex_Helper_GetBridge(options, "integerZoom") and 3 or 1)
	end

	IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 16),
		IEex_Helper_GetBridge(options, "showFps") and 3 or 1)

	if IEex_OptionRowVisible(17) then
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 18),
			IEex_Helper_GetBridge(options, "vsync") and 3 or 1)
	end

	IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 20),
		IEex_Helper_GetBridge(options, "uiBorders") and 3 or 1)

	if IEex_OptionRowVisible(21) then
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 22),
			IEex_Helper_GetBridge(options, "improvedPathfinding") and 3 or 1)
	end

	if IEex_OptionRowVisible(23) then
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 24),
			IEex_Helper_GetBridge(options, "coloredPortraitFrames") and 3 or 1)
	end

	if IEex_OptionRowVisible(27) then
		IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newOptionsPanel, 28),
			IEex_Helper_GetBridge(options, "coloredCircles") and 3 or 1)
	end
end

-- Ship the option documentation INTO the ini. The [IEex Options] section is written at runtime (the
-- engine/IEex write keys via WritePrivateProfileStringA, which never emits comments), so there is no
-- template to ship -- instead inject "; ..." lines once, by raw file edit. INSERT-ONLY: never removes
-- or reorders a line, so no key/value is ever lost; a comment is added only above a known key that does
-- not already have one. Runs every launch but only rewrites when it actually added something, so newly
-- written keys get documented on a later launch. CRLF preserved. WritePrivateProfileStringA preserves
-- the comments on subsequent saves (Wine reloads on mtime change), and the post-write API read below
-- syncs Wine's in-memory copy to our edit so an exit-flush can't clobber it.
function IEex_InjectOptionIniComments()

	local path = "Icewind2.ini"
	local rf = io.open(path, "rb")
	if not rf then return end
	local content = rf:read("*a")
	rf:close()
	if not content or content == "" then return end

	local SENTINEL = "; These keys mirror the in-game IEex Options menu -- click or toggle an option there for its description."

	local comments = {
		["Present Thread"]                        = "OpenGL: present frames on a dedicated thread for smoother pacing; auto-falls back to inline present on any error. 1 = on.",
		["HUD Layer"]                             = "OpenGL: composite the HUD on its own cached layer, re-blitting only when it changes. 1 = on; software / no-FBO uses the stock path.",
		["UI Scale"]                              = "UI size as a percent of fill: 100 = fill (default), lower shrinks the UI within the screen. Render scale only. OpenGL.",
		["SFX Audible Percent"]                   = "Sound-effect audible radius as a percent of screen width: ~96 = vanilla, 60 = hear-what-you-see (default), 50 = silent at the edge. Clamped 5-300.",
		["Loop Sleep Ms"]                         = "Milliseconds to sleep per main-loop iteration. 0 = Sleep(0) yield (default); 1-2 eases a weak CPU when running uncapped.",
		["IP Behavior Flags"]                     = "Improved Pathfinding behavior bitmask, default 15 = all on (1 stall-fix, 2 wait-for-mover, 4 arrived-stop, 8 lookahead). Advanced.",
		["IP Enemy Bumping"]                      = "Improved Pathfinding: let moving enemies bump/shove each other, not just allies. 1 = on.",
		["IP Directed Adjust"]                    = "Improved Pathfinding: nudge a blocked step toward the intended target instead of stalling. 1 = on.",
		["AutoLoadSlot"]                          = "Dev/testing: auto-load this save slot on startup (>=0 auto-clicks Load Game); -1 or absent = off (default).",
		["Improved Pathfinding"]                  = "Master toggle for the GemRB-inspired pathfinding improvements: retry/backoff, unstucking, ally soft-block, chase re-searches that keep the current path instead of standing still for the whole search, and shovable idle NPCs. 1 = on (default). The other IP * keys are its sub-options.",
		["IP Pursuit Repath"]                     = "Improved Pathfinding: AI ticks between re-paths while chasing a moving target (vanilla 8, min 2, max 16). Each re-path THROWS AWAY the current path and the sprite stands still until the async search answers (~2 ticks), so this is the walk/stand duty cycle of a chase: 8 = walk ~6 stand ~2, 4 = walk 2 stand 2 (visible stutter closing to melee). Do not lower it below 8 while the re-search still drops the path.",
		["IP Pursuit Keep Path"]                  = "Improved Pathfinding: keep walking the current path while a chase re-search runs, and swap the fresh route in mid-stride when it lands. Vanilla throws the path away and idles the sprite for the whole search (~2 AI ticks), which is what makes a chase stop-and-go. 1 = on (default). Off = vanilla stop/start.",
		["IP Bump Idle NPCs"]                     = "Improved Pathfinding: let the party shove IDLE non-hostile NPCs aside (a cat asleep in a corridor, a villager in a doorway). Vanilla makes an idle neutral non-bumpable -- a hard wall for pathfinding that no shove can clear -- until its script happens to start walking. Enemies and immobile creatures stay unshovable. 1 = on (default).",
		["IP Ally Queue"]                         = "Improved Pathfinding: when a party member is blocked by ANOTHER party member who is walking somewhere, hold position and step in behind them instead of re-searching. Vanilla waits two short rounds then throws the path away and asks for a new one -- which stands the character still for the whole search and then routes it into the next body, because at a one-cell doorway there is no way around. That churn, per follower, is the stutter at every narrow passage. The party threads a door as a tight queue instead. 1 = on (default).",
		["IP Collision Smoothing"]                = "Improved Pathfinding: keep path smoothing on collision re-searches (vanilla drops it). Prettier post-bump paths, but each one costs the SINGLE shared search thread an extra pass -- and that queue is what every sprite waits on while standing path-less. Default off.",
		["IP Enemy Soft Block"]                   = "Improved Pathfinding sub-option: enemy searches soft-cost through bumpable allies instead of hard-blocking. Default off (enemies may path into the party line and grind).",
		["IP Combat Slide"]                       = "Improved Pathfinding EXPERIMENTAL: melee allies may slide around their target to make room for more attackers instead of jamming corridors single-file. Party-only (enemies keep vanilla rules, so door/tunnel body-blocking gets STRONGER for the player); slides are short interpolated glides, ~2 cells max per burst. Default off.",
		["Tile Atlas"]                            = "OpenGL: batch map tiles into an atlas texture for faster tile rendering. 1 = on. OpenGL only. (No longer in the options menu -- ini only.)",
		["Colored Selection Circles"]             = "Tint each character's selection circle and move-destination marker with that character's own secondary (minor clothing) colour instead of the vanilla green, the way BG2EE colours its party circles. Enemies stay red, neutrals cyan, talking white, morale failure yellow. 0 = vanilla green (default -- the tint is opt-in, so an untouched install looks like the original under either renderer); 1 = tinted. In the options menu. Colour only -- the stroke width is a separate key.",
		["Selection Circle Thickness"]            = "Stroke width, in pixels, of the selection circles under characters. 1 = the vanilla hairline (default); 0 = automatic (2 px, or 3 px above 1920 screen width -- the BG2EE weighting); or force up to 4. Independent of Colored Selection Circles: either can be had without the other. Thickness grows INWARD, so the outer edge -- and the click target -- never moves. OpenGL only.",
		["Destination Marker Thickness"]          = "Stroke width, in pixels, of the move-destination / target reticle. 0 = one step lighter than Selection Circle Thickness, never below 1 (default -- the BG2EE look, where the destination chevrons echo the circle rather than match it; with the default 1 px circles that floor keeps it at the vanilla 1 px), or force 1 to 4. OpenGL only.",
		["Colored Portrait Frames"]               = "Tint the selection frame around each party portrait with that character's colour, matching the circle under their feet. 0 = vanilla green frames (default -- BG2EE colours the ground circles, not the portrait frames); 1 = tinted. In the options menu. Requires Colored Selection Circles = 1, and needs the World HUD Refonte component (that is what installs the portrait renderer this draws through).",
		["Portrait Frame Thickness"]              = "Stroke width, in pixels, of the party portrait selection frames. 1 = the vanilla hairline (default -- the slot is small and its frame sits right on the bust), up to 4, or 0 to follow Selection Circle Thickness. Grows inward but stops at the gap between the frame and the portrait art, so it never covers the face. Under the software renderer, 0 means the vanilla hairline (the circle thickness is an OpenGL-only feature).",
		["Selection Circle Color Slot"]           = "Which creature colour drives the tint: 0 metal, 1 minor clothing (default -- the 'Couleur secondaire' swatch in the inventory), 2 major clothing, 3 skin, 4 leather, 5 armor, 6 hair.",
		["Selection Circle Min Brightness"]       = "Legibility floor (0-255) for tinted circles, so a character in near-black clothing still gets a visible circle. The hue is preserved; only brightness is raised. Default 110; 0 disables.",
		["UI Canvas Scale x10"]                   = "HD UI canvas scale x10: 10 = native 1.0x; >=11 enables the HD UI upscale (e.g. 20 = 2x). Written by the HD/2x UI component.",
		["Windowed"]                              = "1 = run in a window -- a normal titlebar window whose client area is exactly the launch resolution, so pick a custom resolution in the launch dialog to size it (any size is safe there: a windowed run never switches the display mode, on Windows or Wine alike); 0 = fullscreen (default).",
		["Run In Background"]                     = "Keep the game simulating, rendering and playing its audio while another window has the focus (alt-tab). 1 = on (default); 0 = the classic pause, which also mutes the game. Presents are skipped only while the window is minimised. Native Windows + OpenGL; Wine and the software renderer keep the stock behavior.",
		["Last Resolution"]                       = "(internal) last resolution the game ran at. May hold a custom size typed in the launch dialog rather than one of the display's own modes -- it comes back pre-filled and ticked on the next launch.",
		["Transparent Fog of War"]                = "Transparent fog of war instead of the interlaced version. Software renderer only; ignored under OpenGL.",
		["Action Indicators"]                     = "Action indicators above character portraits showing each character's current action(s).",
		["Highlight Empty Containers in Gray"]    = "Highlight already-looted/empty containers in gray instead of green.",
		["Prevent Equipping Armor During Combat"] = "Prevent party members from putting on armor while in combat.",
		["Stretch UI to Screen"]                  = "1 = stretch the UI to fill the screen (larger, softer); 0 = native size, letterboxed (crisper). OpenGL only.",
		["Cutscene Zoom"]                         = "Hold a zoom level for the duration of a cutscene, so scripted shots are framed the way they were composed (they were authored for the 800x600 view: at high resolution the same shot plays inside a window several times too wide and the beats land wrong). 1 = the authored frame (default, as in the Enhanced Editions), matching its HEIGHT so nothing is ever cropped -- only the sides widen (3.6x at 2160p, 2.4x at 1440p, 1.8x at 1080p), and snapped to a whole factor by itself if 'Integer Zoom' is on; 2 = always snapped to a whole factor, so the map stays pixel-exact even with 'Integer Zoom' off (3x at 2160p, 2x at 1440p; below 1200p that is 1x = no zoom); 0 = off, keep whatever zoom the player is using. The player's own zoom is restored when the cutscene ends, and the wheel is ignored while the lock holds. OpenGL only.",
		["Cutscene Log"]                          = "Diagnostic: 1 = append one line per camera change to cutscene_log.txt (view position, viewport, scroll target, area, resolution, zoom). Works under both renderers -- run it in software at 800x600 to capture the framing cutscenes were authored for. Off by default.",
		["Integer Zoom"]                          = "1 = the mouse wheel only stops on whole-number zoom levels (1x, 2x, 3x ...), so one map pixel is always an exact square block of screen pixels; 0 = the default 0.15 steps, which land between whole levels and stretch some pixels wider than others. Fully zoomed out is 1x either way. OpenGL only.",
		["Show FPS"]                              = "On-screen counter: render framerate, AI (game-logic) rate, and VRAM pool usage.",
		["Vsync"]                                 = "Sync frame presentation to the display refresh to remove tearing. OpenGL only.",
		["UI Borders"]                            = "Decorative stone borders: the frame around the in-game HUD (command bar, world map, containers) plus the panels filling the empty screen-edge margins.",
		["UI Single Buffer"]                      = "Single persistent UI buffer to reduce flicker of dynamic elements. OpenGL only.",
		["Smooth Cursor"]                         = "Sample the mouse at the render framerate for smoother cursor motion. OpenGL only. (No longer in the options menu -- ini only.)",
		["Max FPS"]                               = "Frame cap: 0 = auto (just under display refresh), 9999 = uncapped, or an explicit ceiling (e.g. 144). (No longer in the options menu -- ini only.) On a variable-refresh display (G-Sync / FreeSync) the auto cap sits just below the refresh on purpose, so every frame lands inside the adaptive window -- which also means the panel's refresh rate follows each frame. Some VA and OLED panels shift gamma whenever the refresh moves, and that reads as the whole image pulsing in time with the framerate. If you see it, set a cap clearly ABOVE your refresh (144 on a 120Hz panel) and leave Vsync on: the refresh pins to its maximum and stops moving, so there is nothing left for the gamma to follow. The trade is that the game then produces frames faster than the display can show them, so some are held for two refreshes.",
		["Fill Screen"]                           = "OpenGL: 1 = fit the game image to the desktop via an FBO; 0 = raw direct present (native resolution only).",
		["Software Renderer"]                     = "1 = force the stock software (DirectDraw) renderer; 0 = OpenGL (default). [Program Options] '3D Acceleration' is rewritten from this every launch.",
		["Gamma Normalized"]                      = "(internal) 1 = the one-time reset of [Program Options] 'Gamma Correction' to 0 already ran (the GOG-shipped 2 is tuned for the unmodded renderer). Delete this key to run the reset once more.",
	}

	local nl = content:find("\r\n", 1, true) and "\r\n" or "\n"
	local hasSentinel = content:find(SENTINEL, 1, true) ~= nil

	local lines = {}
	local pos = 1
	while true do
		local s, e = content:find(nl, pos, true)
		if not s then lines[#lines + 1] = content:sub(pos); break end
		lines[#lines + 1] = content:sub(pos, s - 1)
		pos = e + 1
	end

	local out = {}
	local inSection = false
	local sawSection = false
	local changed = false
	for _, line in ipairs(lines) do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed:match("^%[.+%]$") then
			inSection = (trimmed:lower() == "[ieex options]")
			out[#out + 1] = line
			if inSection then
				sawSection = true
				if not hasSentinel then
					out[#out + 1] = SENTINEL
					out[#out + 1] = ""   -- blank so the first key still gets its own comment
					changed = true
				end
			end
		else
			if inSection then
				local key = trimmed:match("^([^=;]-)%s*=")
				local prev = out[#out]
				if key and comments[key] and not (prev and prev:match("^%s*;")) then
					out[#out + 1] = "; " .. comments[key]
					changed = true
				end
			end
			out[#out + 1] = line
		end
	end

	if not sawSection or not changed then return end

	local wf = io.open(path, "wb")
	if not wf then return end
	wf:write(table.concat(out, nl))
	wf:close()

	-- Force Wine to reload its cached copy (mtime changed) so a later flush keeps our comments.
	IEex_GetPrivateProfileInt("IEex Options", "Show FPS", 0, ".\\Icewind2.ini")
end

IEex_AbsoluteOnce("IEex_InitOptions", function()
	if not IEex_InAsyncState then return false end
	if IEex_Vanilla then return end
	IEex_LoadOptions()
	pcall(IEex_InjectOptionIniComments)
end)

function IEex_Extern_OnOptionsScreenESC(CScreenOptions)

	local trySetPanelEnabled = function(panel, enabled)
		if panel ~= 0x0 then
			IEex_SetPanelEnabled(panel, enabled)
		end
	end

	local setCommonPanelsEnabled = function(engine, enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -2), enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -3), enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -4), enabled)
		trySetPanelEnabled(IEex_GetPanelFromEngine(engine, -5), enabled)
		IEex_SetPanelEnabled(IEex_GetPanelFromEngine(engine, 0), enabled)
		IEex_SetPanelEnabled(IEex_GetPanelFromEngine(engine, 1), enabled)
		IEex_SetPanelEnabled(IEex_GetPanelFromEngine(engine, 2), enabled)
	end

	local lastPanel = IEex_ReadDword(IEex_ReadDword(CScreenOptions + 0x43C) + 0x8)
	if IEex_GetPanelID(lastPanel) == 14 then
		IEex_Call(0x7FB343, {}, CScreenOptions + 0x434, 0x0) -- CPtrList_RemoveTail()
		local screenOptions = IEex_GetEngineOptions()
		local worldOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 2)
		local newOptionsPanel = IEex_GetPanelFromEngine(screenOptions, 14)
		IEex_SetPanelActive(newOptionsPanel, false)
		setCommonPanelsEnabled(screenOptions, true)
		IEex_SetPanelEnabled(worldOptionsPanel, true)
		return true
	end
	return false
end

function IEex_CScreenWorld_OnQuicklootButtonLClick()
	IEex_AssertThread(IEex_Thread.Async, true)
	if IEex_Helper_GetBridge("IEex_Quickloot", "on") then
		IEex_Quickloot_Stop()
	else
		IEex_Quickloot_Start()
	end
end

-----------------------
-- GUIKEYS Expansion --
-----------------------

IEex_Hotkeys_HardcodedMapDefaults = {
	[00] = "I",
	[01] = "R",
	[02] = "G",
	[03] = "J",
	[04] = "M",
	[05] = "S",
	[06] = "O",
	[07] = "C",
	[08] = nil,
	[09] = nil,
	[10] = nil,
	[11] = nil,
	[12] = nil,
	[13] = "D",
	[14] = nil,
	[15] = nil,
	[16] = nil,
	[17] = nil,
	[18] = nil,
	[19] = "V",
	[20] = nil,
	[21] = nil,
	[22] = "L",
	[23] = "H",
	[24] = "T",
	[25] = "X",
	[26] = "Q",
	[27] = "A",
	[28] = "Y",
	[29] = "Z",
	[30] = ".",
	[31] = "F",
	[32] = "7",
	[33] = "8",
	[34] = "9",
	[35] = "0",
	[36] = "-",
	[37] = "=",
	[38] = nil,
	[39] = nil,
	[40] = nil,
	[41] = nil,
	[42] = nil,
	[43] = nil,
	[44] = nil,
	[45] = nil,
	[46] = nil,
	[47] = nil,
	[48] = nil,
	[49] = nil,
	[50] = nil,
	[51] = nil,
	[52] = nil,
}

IEex_Hotkeys_CustomBinding = {
	TOGGLE_QUICKLOOT        =  0,
	SCROLL_UP               =  1,
	SCROLL_UP_ALT           =  2,
	SCROLL_LEFT             =  3,
	SCROLL_LEFT_ALT         =  4,
	SCROLL_DOWN             =  5,
	SCROLL_DOWN_ALT         =  6,
	SCROLL_RIGHT            =  7,
	SCROLL_RIGHT_ALT        =  8,
	SCROLL_TOP_LEFT         =  9,
	SCROLL_TOP_LEFT_ALT     = 10,
	SCROLL_BOTTOM_LEFT      = 11,
	SCROLL_BOTTOM_LEFT_ALT  = 12,
	SCROLL_BOTTOM_RIGHT     = 13,
	SCROLL_BOTTOM_RIGHT_ALT = 14,
	SCROLL_TOP_RIGHT        = 15,
	SCROLL_TOP_RIGHT_ALT    = 16,
	TOGGLE_BUFF_RECORDING   = 17,
	ERASE_RECORDING         = 18,
	CAST_RECORDED_BUFFS     = 19,
}

IEex_Hotkeys_CustomBindings = {
	[IEex_Hotkeys_CustomBinding.TOGGLE_QUICKLOOT]        = { ["iniSection"] = "IEex", ["iniKey"] = "Toggle Quickloot",          ["default"] = "`"        },
	[IEex_Hotkeys_CustomBinding.SCROLL_UP]               = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Up",                 ["default"] = "Up"       },
	[IEex_Hotkeys_CustomBinding.SCROLL_UP_ALT]           = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Up (Alt)",           ["default"] = "Keypad 8" },
	[IEex_Hotkeys_CustomBinding.SCROLL_LEFT]             = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Left",               ["default"] = "Left"     },
	[IEex_Hotkeys_CustomBinding.SCROLL_LEFT_ALT]         = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Left (Alt)",         ["default"] = "Keypad 4" },
	[IEex_Hotkeys_CustomBinding.SCROLL_DOWN]             = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Down",               ["default"] = "Down"     },
	[IEex_Hotkeys_CustomBinding.SCROLL_DOWN_ALT]         = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Down (Alt)",         ["default"] = "Keypad 2" },
	[IEex_Hotkeys_CustomBinding.SCROLL_RIGHT]            = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Right",              ["default"] = "Right"    },
	[IEex_Hotkeys_CustomBinding.SCROLL_RIGHT_ALT]        = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Right (Alt)",        ["default"] = "Keypad 6" },
	[IEex_Hotkeys_CustomBinding.SCROLL_TOP_LEFT]         = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Top Left",           ["default"] = nil        },
	[IEex_Hotkeys_CustomBinding.SCROLL_TOP_LEFT_ALT]     = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Top Left (Alt)",     ["default"] = "Keypad 7" },
	[IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_LEFT]      = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Bottom Left",        ["default"] = nil        },
	[IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_LEFT_ALT]  = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Bottom Left (Alt)",  ["default"] = "Keypad 1" },
	[IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_RIGHT]     = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Bottom Right",       ["default"] = nil        },
	[IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_RIGHT_ALT] = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Bottom Right (Alt)", ["default"] = "Keypad 3" },
	[IEex_Hotkeys_CustomBinding.SCROLL_TOP_RIGHT]        = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Top Right",          ["default"] = nil        },
	[IEex_Hotkeys_CustomBinding.SCROLL_TOP_RIGHT_ALT]    = { ["iniSection"] = "IEex", ["iniKey"] = "Scroll Top Right (Alt)",    ["default"] = "Keypad 9" },
	[IEex_Hotkeys_CustomBinding.TOGGLE_BUFF_RECORDING]   = { ["iniSection"] = "IEex", ["iniKey"] = "Toggle Buff Recording",     ["default"] = "["        },
	[IEex_Hotkeys_CustomBinding.ERASE_RECORDING]         = { ["iniSection"] = "IEex", ["iniKey"] = "Erase Recording",           ["default"] = "]"        },
	[IEex_Hotkeys_CustomBinding.CAST_RECORDED_BUFFS]     = { ["iniSection"] = "IEex", ["iniKey"] = "Cast Recorded Buffs",       ["default"] = ";"        },
}

IEex_Hotkeys_CustomBindingsHandlers = {
	[IEex_Hotkeys_CustomBinding.TOGGLE_QUICKLOOT] = IEex_CScreenWorld_OnQuicklootButtonLClick,
	[IEex_Hotkeys_CustomBinding.TOGGLE_BUFF_RECORDING] = IEex_ToggleBuffRecording,
	[IEex_Hotkeys_CustomBinding.ERASE_RECORDING] = IEex_EraseRecording,
	[IEex_Hotkeys_CustomBinding.CAST_RECORDED_BUFFS] = IEex_CastRecordedBuffs,
}

IEex_Hotkeys_ValueControlExpansion = 38

IEex_Hotkeys_KeysScreenLayout = {

	------------
	-- Page 1 --
	------------

	-- Column 1
	{ ["hardcodedMapIndex"] = -1, ["strref"] = 33478 },
	{ ["hardcodedMapIndex"] =  0, ["strref"] = 16307 },
	{ ["hardcodedMapIndex"] =  1, ["strref"] = 16306 },
	{ ["hardcodedMapIndex"] =  3, ["strref"] = 16308 },
	{ ["hardcodedMapIndex"] =  4, ["strref"] = 33505 },
	{ ["hardcodedMapIndex"] =  5, ["strref"] = 17384 },
	{ ["hardcodedMapIndex"] =  6, ["strref"] = 13696 },
	{ ["hardcodedMapIndex"] =  7, ["strref"] = 13902 },
	{ ["hardcodedMapIndex"] =  2, ["strref"] = 16313 },
	{ ["hardcodedMapIndex"] = -1, ["strref"] =    -1 },
	{ ["hardcodedMapIndex"] = -1, ["strref"] = 33501 },
	{ ["hardcodedMapIndex"] =  8, ["strref"] = 15925 },
	{ ["hardcodedMapIndex"] =  9, ["strref"] =  4974 },
	{ ["hardcodedMapIndex"] = 10, ["strref"] =  4918 },
	{ ["hardcodedMapIndex"] = 11, ["strref"] =  4688 },
	{ ["hardcodedMapIndex"] = 12, ["strref"] =  4978 },
	{ ["hardcodedMapIndex"] = 13, ["strref"] =  4933 },
	{ ["hardcodedMapIndex"] = 14, ["strref"] =  4971 },
	{ ["hardcodedMapIndex"] = 15, ["strref"] =  4968 },
	{ ["hardcodedMapIndex"] = 16, ["strref"] =  4927 },

	-- Column 2
	{ ["hardcodedMapIndex"] = 17, ["strref"] = 15924 },
	{ ["hardcodedMapIndex"] = 18, ["strref"] =  4666 },
	{ ["hardcodedMapIndex"] = 19, ["strref"] =  4954 },
	{ ["hardcodedMapIndex"] = 20, ["strref"] = 30289 },
	{ ["hardcodedMapIndex"] = 21, ["strref"] = 30290 },
	{ ["hardcodedMapIndex"] = -1, ["strref"] =    -1 },
	{ ["hardcodedMapIndex"] = -1, ["strref"] = 33500 },
	{ ["hardcodedMapIndex"] = 25, ["strref"] = 33506 },
	{ ["hardcodedMapIndex"] = 26, ["strref"] = 33507 },
	{ ["hardcodedMapIndex"] = 22, ["strref"] = 33508 },
	{ ["hardcodedMapIndex"] = 23, ["strref"] = 32050 },
	{ ["hardcodedMapIndex"] = 28, ["strref"] = 40248 },
	{ ["hardcodedMapIndex"] = 24, ["strref"] = 40249 },
	{ ["hardcodedMapIndex"] = 27, ["strref"] = 33509 },
	{ ["hardcodedMapIndex"] = 29, ["strref"] = 11942 },
	{ ["hardcodedMapIndex"] = 30, ["strref"] = 40250 },
	{ ["hardcodedMapIndex"] = 31, ["strref"] = 40251 },
	{ ["hardcodedMapIndex"] = 32, ["strref"] = 40252 },
	{ ["hardcodedMapIndex"] = 33, ["strref"] = 40253 },
	{ ["hardcodedMapIndex"] = 34, ["strref"] = 40254 },

	-- Column 3
	{ ["hardcodedMapIndex"] = 35, ["strref"] = 40255 },
	{ ["hardcodedMapIndex"] = 36, ["strref"] = 40256 },
	{ ["hardcodedMapIndex"] = 37, ["strref"] = 40273 },
	{ ["hardcodedMapIndex"] = -1, ["strref"] =    -1 },
	{ ["hardcodedMapIndex"] = -1, ["strref"] = 40257 },
	{ ["hardcodedMapIndex"] = 41, ["strref"] = 40258 },
	{ ["hardcodedMapIndex"] = 42, ["strref"] = 40259 },
	{ ["hardcodedMapIndex"] = 43, ["strref"] = 40260 },
	{ ["hardcodedMapIndex"] = 44, ["strref"] = 40261 },
	{ ["hardcodedMapIndex"] = 38, ["strref"] = 40262 },
	{ ["hardcodedMapIndex"] = 39, ["strref"] = 40263 },
	{ ["hardcodedMapIndex"] = 40, ["strref"] = 40264 },
	{ ["hardcodedMapIndex"] = 45, ["strref"] = 40265 },
	{ ["hardcodedMapIndex"] = 46, ["strref"] = 40266 },
	{ ["hardcodedMapIndex"] = 47, ["strref"] = 40267 },
	{ ["hardcodedMapIndex"] = 48, ["strref"] = 40268 },
	{ ["hardcodedMapIndex"] = 49, ["strref"] = 40269 },
	{ ["hardcodedMapIndex"] = 50, ["strref"] = 40270 },
	{ ["hardcodedMapIndex"] = 51, ["strref"] = 40271 },
	{ ["hardcodedMapIndex"] = 52, ["strref"] = 40272 },

	------------
	-- Page 2 --
	------------

	-- Column 1
	{                                                                          ["strref"] = ex_tra_55909 }, -- "Scrolling"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_UP,               ["strref"] = ex_tra_55910 }, -- "Scroll Up"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_LEFT,             ["strref"] = ex_tra_55911 }, -- "Scroll Left"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_DOWN,             ["strref"] = ex_tra_55912 }, -- "Scroll Down"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_RIGHT,            ["strref"] = ex_tra_55913 }, -- "Scroll Right"
	{                                                                                                    },
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_UP_ALT,           ["strref"] = ex_tra_55914 }, -- "Scroll Up (Alt)"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_LEFT_ALT,         ["strref"] = ex_tra_55915 }, -- "Scroll Left (Alt)"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_DOWN_ALT,         ["strref"] = ex_tra_55916 }, -- "Scroll Down (Alt)"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_RIGHT_ALT,        ["strref"] = ex_tra_55917 }, -- "Scroll Right (Alt)"
	{                                                                                                    },
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_TOP_LEFT,         ["strref"] = ex_tra_55918 }, -- "Scroll Top Left"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_LEFT,      ["strref"] = ex_tra_55919 }, -- "Scroll Bottom Left"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_RIGHT,     ["strref"] = ex_tra_55920 }, -- "Scroll Bottom Right"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_TOP_RIGHT,        ["strref"] = ex_tra_55921 }, -- "Scroll Top Right"
	{                                                                                                    },
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_TOP_LEFT_ALT,     ["strref"] = ex_tra_55922 }, -- "Scroll Top Left (Alt)"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_LEFT_ALT,  ["strref"] = ex_tra_55923 }, -- "Scroll Bottom Left (Alt)"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_RIGHT_ALT, ["strref"] = ex_tra_55924 }, -- "Scroll Bottom Right (Alt)"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.SCROLL_TOP_RIGHT_ALT,    ["strref"] = ex_tra_55925 }, -- "Scroll Top Right (Alt)"

	-- Column 2
	{                                                                          ["strref"] = ex_tra_55926 }, -- "IEex"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.TOGGLE_QUICKLOOT,        ["strref"] = ex_tra_55927 }, -- "Toggle Quickloot"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.TOGGLE_BUFF_RECORDING,   ["strref"] = ex_tra_55928 }, -- "Toggle Buff Recording"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.ERASE_RECORDING,         ["strref"] = ex_tra_55929 }, -- "Erase Recording"
	{ ["customMapIndex"] = IEex_Hotkeys_CustomBinding.CAST_RECORDED_BUFFS,     ["strref"] = ex_tra_55930 }, -- "Cast Recorded Buffs"
}

function IEex_Extern_GiveEngineKeysScreenLayout()
	return IEex_Hotkeys_KeysScreenLayout
end

IEex_Hotkeys_KeyToCustomMapIndex = {}

-- This function is called by the engine whenever a custom hotkey binding is updated, (this includes initialization).
--     deltaT = {
--         { ["customMapIndex"] = ?, ["oldVirtualKey"] = ?, ["oldVirtualKeyHasCtrl"] = ?, ["newVirtualKey"] = ?, ["newVirtualKeyHasCtrl"] = ? },
--         { ["customMapIndex"] = ?, ["oldVirtualKey"] = ?, ["oldVirtualKeyHasCtrl"] = ?, ["newVirtualKey"] = ?, ["newVirtualKeyHasCtrl"] = ? },
--         ...
--     }
function IEex_Extern_KeysScreenOnCustomBindingsChanged(deltaT)

	IEex_AssertThread(IEex_Thread.Async, true)

	for _, deltaEntry in ipairs(deltaT) do

		local customMapIndex       = deltaEntry.customMapIndex
		local oldVirtualKey        = deltaEntry.oldVirtualKey
		local oldVirtualKeyHasCtrl = deltaEntry.oldVirtualKeyHasCtrl
		local newVirtualKey        = deltaEntry.newVirtualKey
		local newVirtualKeyHasCtrl = deltaEntry.newVirtualKeyHasCtrl

		-- Using 0x100 (outside of VK_ range of 0xFF) to flag ctrl
		if oldVirtualKeyHasCtrl then oldVirtualKey = bit.bor(oldVirtualKey, 0x100) end
		if newVirtualKeyHasCtrl then newVirtualKey = bit.bor(newVirtualKey, 0x100) end

		-- (Potentially) clear old mapping if it hasn't been changed already
		if IEex_Hotkeys_KeyToCustomMapIndex[oldVirtualKey] == customMapIndex then
			IEex_Hotkeys_KeyToCustomMapIndex[oldVirtualKey] = nil
		end

		-- Set new mapping
		IEex_Hotkeys_KeyToCustomMapIndex[newVirtualKey] = newVirtualKey ~= 0 and customMapIndex or nil
	end
end

function IEex_Hotkeys_KeyPressedListener(key)

	if IEex_GetActiveEngine() ~= IEex_GetEngineWorld() or not IEex_IsWorldScreenAcceptingInput() then return end

	if IEex_IsKeyDown(IEex_KeyIDS.LEFT_CTRL) or IEex_IsKeyDown(IEex_KeyIDS.RIGHT_CTRL) then
		key = bit.bor(key, 0x100)
	end

	local customMapIndex = IEex_Hotkeys_KeyToCustomMapIndex[key]
	if customMapIndex == nil then return end

	local func = IEex_Hotkeys_CustomBindingsHandlers[customMapIndex]
	if func ~= nil then func() end
end

function IEex_Hotkeys_GetBoundCustomMapIndex(key)

	if IEex_IsKeyDown(IEex_KeyIDS.LEFT_CTRL) or IEex_IsKeyDown(IEex_KeyIDS.RIGHT_CTRL) then
		key = bit.bor(key, 0x100)
	end

	return IEex_Hotkeys_KeyToCustomMapIndex[key]
end

IEex_Hotkeys_ScrollUpCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_UP, IEex_Hotkeys_CustomBinding.SCROLL_UP_ALT,
}

function IEex_Hotkeys_IsScrollUp(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollUpCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollLeftCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_LEFT, IEex_Hotkeys_CustomBinding.SCROLL_LEFT_ALT,
}

function IEex_Hotkeys_IsScrollLeft(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollLeftCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollDownCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_DOWN, IEex_Hotkeys_CustomBinding.SCROLL_DOWN_ALT,
}

function IEex_Hotkeys_IsScrollDown(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollDownCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollRightCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_RIGHT, IEex_Hotkeys_CustomBinding.SCROLL_RIGHT_ALT,
}

function IEex_Hotkeys_IsScrollRight(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollRightCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollTopLeftCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_TOP_LEFT, IEex_Hotkeys_CustomBinding.SCROLL_TOP_LEFT_ALT,
}

function IEex_Hotkeys_IsScrollTopLeft(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollTopLeftCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollBottomLeftCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_LEFT, IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_LEFT_ALT,
}

function IEex_Hotkeys_IsScrollBottomLeft(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollBottomLeftCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollBottomRightCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_RIGHT, IEex_Hotkeys_CustomBinding.SCROLL_BOTTOM_RIGHT_ALT,
}

function IEex_Hotkeys_IsScrollBottomRight(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollBottomRightCustomMapIndices, customMapIndex) ~= nil
end

IEex_Hotkeys_ScrollTopRightCustomMapIndices = {
	IEex_Hotkeys_CustomBinding.SCROLL_TOP_RIGHT, IEex_Hotkeys_CustomBinding.SCROLL_TOP_RIGHT_ALT,
}

function IEex_Hotkeys_IsScrollTopRight(customMapIndex)
	return customMapIndex ~= nil and IEex_FindInTable(IEex_Hotkeys_ScrollTopRightCustomMapIndices, customMapIndex) ~= nil
end

IEex_AbsoluteOnce("IEex_Hotkeys", function()
	IEex_Helper_RegisterKeysScreenHardcodedMapDefaults(IEex_Hotkeys_HardcodedMapDefaults)
	IEex_Helper_RegisterKeysScreenCustomBindings(IEex_Hotkeys_CustomBindings)
end)

-------------------------------
-- Spontaneous Casting Hooks --
-------------------------------

-- CButtonData:
--   [+0x0]    | m_icon                 | CResRef
--   [+0x8]    | m_name                 | int
--   [+0xC]    | m_launcherIcon         | CResRef
--   [+0x14]   | m_launcherName         | int
--   [+0x18]   | m_count                | short
--   [+0x1A]   | m_abilityId            | CAbilityId
--     [+0x1A] | m_itemType             | short
--     [+0x1C] | m_itemNum              | short
--     [+0x1E] | m_abilityNum           | short
--     [+0x20] | m_res                  | CResRef
--     [+0x28] | m_targetType           | byte
--     [+0x29] | m_targetCount          | byte
--     [+0x2A] | m_toolTip              | int
--     [+0x2E] | nUnknown               | int
--     [+0x32] | m_nTooltipSuffixStrref | int
--     [+0x36] | m_nClass               | byte
--     [+0x37] | m_nSpellLevel          | byte
--     [+0x38] | m_nKitOrdinal          | short
--   [+0x3A]   | m_bDisabled            | byte
--   [+0x3B]   | m_bHasCharges          | byte

-- Return:
--	 true  - Treat button press as a spontaneous cast
--	 false - Handle button press as normal
function IEex_Extern_AttemptSpontaneousCast(sprite, buttonData)

	local spellClass = IEex_ReadByte(buttonData + 0x36)
	local spellKitOrdinal = IEex_ReadWord(buttonData + 0x38)

	if spellClass == 3 and spellKitOrdinal == 0 then
		-- Cleric spell
		return true
	end

	if spellClass == 4 and ex_enable_druid_spontaneous_casting then
	-- 	-- Druid spell
		return true
	end

	return false
end

function IEex_Extern_GetSpontaneousCastColumnAndRow(sprite, buttonData, returnValues)

	-- 0 = first column/row
	local column = -1
	local row = -1

	local spellClass = IEex_ReadByte(buttonData + 0x36)
	local spellLevel = IEex_ReadByte(buttonData + 0x37)

	if spellClass == 3 then
		-- Cleric spell
		column = bit.band(IEex_Call(0x584EB0, {sprite}, nil, 0x4), 0xFF) -- 0 = non-evil, 1 = evil
		row = spellLevel - 1
	elseif spellClass == 4 then
	-- 	-- Druid spell
		column = 2
		row = spellLevel - 1
	end

	-- Pass the values back to the hook
	IEex_WriteDword(returnValues, column)
	IEex_WriteDword(returnValues + 0x4, row + 1)
end

----------------
-- OlvynChuru --
----------------

ex_current_menu_spell_level = 1
ex_menu_in_second_replacement_step = false
function IEex_DisplayWizardSpellsToLearn(level)
	local screenCharacter = IEex_GetEngineCharacter()
	local actorID = IEex_ReadDword(screenCharacter + 0x136)
	if not IEex_IsSprite(actorID, false) then return end
	local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
	if ex_alternate_spell_menu_class == 11 then
		IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 33), IEex_FetchString(ex_spelllevelmenustrrefs[level]))
		for i = 1, 30, 1 do
			if i <= #ex_menu_available_wizard_spells[level] then
				IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, i + 99), ex_menu_available_wizard_spells[level][i])
			else
				IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, i + 99), "")
			end
		end
	elseif ex_alternate_spell_menu_class == 2 or ex_alternate_spell_menu_class == 10 then
		IEex_SetControlLabelText(IEex_GetControlFromPanel(newWizardSpellsPanel, 33), IEex_FetchString(ex_spelllevelreplacementmenustrrefs[level]))
		if not ex_menu_in_second_replacement_step then
			local i = 1
			for spellRES, isKnown in pairs(ex_menu_known_wizard_spells[level]) do
				if isKnown then
					if ex_menu_sorcerer_spells_replaced[spellRES] then
						IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, i + 99), ex_menu_sorcerer_spells_replaced[spellRES])
						IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newWizardSpellsPanel, i - 1), 0)
					else
						IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, i + 99), spellRES)
						IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newWizardSpellsPanel, i - 1), 1)
					end
					i = i + 1
				end
			end
			for j = i, 30, 1 do
				IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, j + 99), "")
				IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newWizardSpellsPanel, j - 1), 1)
			end
		else
			for i = 1, 30, 1 do
				if i <= #ex_menu_available_wizard_spells[level] and not ex_menu_wizard_spells_learned[ex_menu_available_wizard_spells[level][i]] then
					IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, i + 99), ex_menu_available_wizard_spells[level][i])
				else
					IEex_SetControlButtonMageSpellInfoIcon(IEex_GetControlFromPanel(newWizardSpellsPanel, i + 99), "")
				end
				IEex_SetControlButtonFrameUpForce(IEex_GetControlFromPanel(newWizardSpellsPanel, i - 1), 1)
			end
		end
	end
	local leftButton = IEex_GetControlFromPanel(newWizardSpellsPanel, 36)
	local rightButton = IEex_GetControlFromPanel(newWizardSpellsPanel, 37)
	if level <= 1 or ex_menu_in_second_replacement_step then
		IEex_SetControlButtonFrameUpForce(leftButton, 3)
		IEex_SetControlButtonFrameDown(leftButton, 3)
	else
		IEex_SetControlButtonFrameUpForce(leftButton, 1)
		IEex_SetControlButtonFrameDown(leftButton, 2)
	end
	if level >= ex_menu_max_castable_level or ex_menu_in_second_replacement_step then
		IEex_SetControlButtonFrameUpForce(rightButton, 3)
		IEex_SetControlButtonFrameDown(rightButton, 3)
	else
		IEex_SetControlButtonFrameUpForce(rightButton, 1)
		IEex_SetControlButtonFrameDown(rightButton, 2)
	end
end

ex_menu_known_wizard_spells = {{}, {}, {}, {}, {}, {}, {}, {}, {}, }
ex_menu_available_wizard_spells = {{}, {}, {}, {}, {}, {}, {}, {}, {}, }
ex_menu_num_known_spells_per_level = {0, 0, 0, 0, 0, 0, 0, 0, 0}
ex_menu_max_castable_level = 0
function IEex_InitializeWizardLearnList()
	local screenCharacter = IEex_GetEngineCharacter()
	local actorID = IEex_ReadDword(screenCharacter + 0x136)
	if not IEex_IsSprite(actorID, false) then return end
	local kit = IEex_GetActorStat(actorID, 89)
	local specialistBit = 0x40
	local specialistSchool = 0
	for i = 1, 9, 1 do
		if bit.band(kit, specialistBit) > 0 then
			specialistSchool = i
		end
		specialistBit = specialistBit * 2
	end
	if specialistSchool == 0 then
		specialistSchool = 9
	end
	local knownSpellsOfLevel = {}
	local casterType = IEex_CasterClassToType[ex_alternate_spell_menu_class]
	local spells = IEex_FetchSpellInfo(actorID, {casterType})
	local levelList = spells[casterType]
	if ex_alternate_spell_menu_class == 11 then
		ex_menu_max_castable_level = 0
	end
	ex_menu_known_wizard_spells = {{}, {}, {}, {}, {}, {}, {}, {}, {}, }
	ex_menu_available_wizard_spells = {{}, {}, {}, {}, {}, {}, {}, {}, {}, }
	ex_menu_num_known_spells_per_level = {0, 0, 0, 0, 0, 0, 0, 0, 0}
	if levelList ~= nil then
		for level = 1, #levelList, 1 do
			local levelI = levelList[level]
			if levelI ~= nil then
				if levelI[1] > 0 then
					if ex_alternate_spell_menu_class == 11 then
						ex_menu_max_castable_level = ex_menu_max_castable_level + 1
					end
					local levelISpells = levelI[3]
					if #levelISpells > 0 then
						for i, spell in ipairs(levelISpells) do
							ex_menu_known_wizard_spells[level][spell["resref"]] = true
							ex_menu_num_known_spells_per_level[level] = ex_menu_num_known_spells_per_level[level] + 1
						end
					end
				end
			end
		end
	end
	local alignment = IEex_ReadByte(IEex_GetActorShare(actorID) + 0x35, 0x0)
	local listspll = IEex_2DADemand("LISTSPLL")
	local m_nSizeY = IEex_ReadWord(listspll + 0x22, 0x0)
	for i = 0, m_nSizeY - 1, 1 do
		local wizardLevel = tonumber(IEex_2DAGetAt(listspll, casterType - 1, i))
		local spellRES = IEex_2DAGetAt(listspll, 7, i)
		if wizardLevel > 0 and wizardLevel <= ex_menu_max_castable_level and not ex_menu_known_wizard_spells[wizardLevel][spellRES] then
			local scrollWrapper = IEex_DemandRes(spellRES .. "Z", "ITM")
			if scrollWrapper:isValid() then
				local scrollData = scrollWrapper:getData()
				local unusabilityFlags = IEex_ReadDword(scrollData + 0x1E)
				local kitUnusability3 = IEex_ReadByte(scrollData + 0x2D, 0x0)
				local kitUnusability4 = IEex_ReadByte(scrollData + 0x2F, 0x0)
				if (bit.band(unusabilityFlags, 0x1000) == 0 or bit.band(alignment, 0x30) ~= 0x30) and (bit.band(unusabilityFlags, 0x2000) == 0 or bit.band(alignment, 0x3) ~= 0x3) and (bit.band(unusabilityFlags, 0x4000) == 0 or bit.band(alignment, 0x3) ~= 0x1) and (bit.band(unusabilityFlags, 0x8000) == 0 or bit.band(alignment, 0x3) ~= 0x2) and (bit.band(unusabilityFlags, 0x10000) == 0 or bit.band(alignment, 0x30) ~= 0x10) and (bit.band(unusabilityFlags, 0x20000) == 0 or bit.band(alignment, 0x30) ~= 0x20) then
					if ex_alternate_spell_menu_class ~= 11 or (((specialistSchool == 1 or specialistSchool == 2) and bit.band(kitUnusability4, 2 ^ (specialistSchool + 5)) == 0x0) or (specialistSchool >= 3 and bit.band(kitUnusability3, 2 ^ (specialistSchool - 3)) == 0x0)) then
						table.insert(ex_menu_available_wizard_spells[wizardLevel], spellRES)
					end
				end
			else
				table.insert(ex_menu_available_wizard_spells[wizardLevel], spellRES)
			end
			scrollWrapper:free()
		end
	end
	IEex_NewWizardSpellsPanelDoneButtonUpdate()
end

function IEex_NewWizardSpellsPanelDoneButtonClickable()
	if ex_alternate_spell_menu_class == 2 or ex_alternate_spell_menu_class == 10 then
		return (not ex_menu_in_second_replacement_step)
	else
		if ex_menu_num_wizard_spells_remaining == 0 then return true end
		local isClickable = true
		for level = 1, ex_menu_max_castable_level, 1 do
			if ex_menu_num_learned_spells_per_level[level] < #ex_menu_available_wizard_spells[level] and (ex_menu_num_known_spells_per_level[level] + ex_menu_num_learned_spells_per_level[level]) < 24 then
				isClickable = false
			end
		end
		return isClickable
	end
end

function IEex_NewWizardSpellsPanelDoneButtonUpdate()
	local screenCharacter = IEex_GetEngineCharacter()
	local newWizardSpellsPanel = IEex_GetPanelFromEngine(screenCharacter, 58)
	local doneButton = IEex_GetControlFromPanel(newWizardSpellsPanel, 35)
	if not IEex_NewWizardSpellsPanelDoneButtonClickable() then
		IEex_SetControlButtonFrameUpForce(doneButton, 3)
		IEex_SetControlButtonFrameDown(doneButton, 3)
	else
		IEex_SetControlButtonFrameUpForce(doneButton, 1)
		IEex_SetControlButtonFrameDown(doneButton, 2)
	end
end

------------------------------------
-- Record Screen Description Hook --
------------------------------------

------------------
-- Thread: Both --
------------------
ex_class_name_strings = {
{34},
{1083},
{1079, 38097, 38098, 38099, 38100, 38101, 38102, 38103, 38106, 38107},
{1080},
{10174},
{33, 36877, 36878, 36879},
{1078, 36875, 36872, 36873},
{1077},
{1082},
{32, 40352},
{9987, 502, 504, 2012, 2022, 3015, 2862, 12744, 12745},
}
ex_current_record_hand = 1
ex_current_record_actorID = 0
ex_current_record_weapon_die_number = 0
ex_current_record_weapon_die_size = 0
ex_previous_line_was_race = false
ex_checking_bonus_spells = false
ex_current_record_on_weapon_statistics = false
function IEex_Extern_OnUpdateRecordDescription(CScreenCharacter, CGameSprite, CUIControlEditMultiLine, m_plstStrings)
	IEex_AssertThread(IEex_Thread.Both, true)
	local creatureData = CGameSprite
	local targetID = IEex_GetActorIDShare(creatureData)
	ex_current_record_actorID = targetID
	local descPanelNum = IEex_ReadByte(CScreenCharacter + 0x1844, 0)
	local extraFlags = IEex_ReadDword(creatureData + 0x740)
	if bit.band(extraFlags, 0x1000) > 0 then
		IEex_WriteDword(creatureData + 0x740, bit.band(extraFlags, 0xFFFFEFFF))
		local armoredArcanaFeatCount = IEex_ReadByte(creatureData + 0x781, 0x0)
		IEex_WriteByte(creatureData + 0x781, math.floor(armoredArcanaFeatCount / ex_armored_arcana_multiplier))
	end
	local levelString = IEex_FetchString(7192)
	local bonusSpellsString = IEex_FetchString(10344)
	local damageString = IEex_FetchString(39518)
	local damageBonusString = IEex_FetchString(39571)
	local powerAttackString = IEex_FetchString(35794)
	local damagePotentialString = IEex_FetchString(41120)
	local castingFailureString = IEex_FetchString(41390)
	local armoredArcanaString = IEex_FetchString(36352)
	local sneakAttackDamageString = IEex_FetchString(24898)
	local turnUndeadLevelString = IEex_FetchString(12126)
	local wholenessOfBodyString = IEex_FetchString(39768)
	local abilitiesString = IEex_FetchString(33547)
	local expertiseString = IEex_FetchString(39818)
	local genericString = IEex_FetchString(33552)
	local monkWisdomBonusString = ex_str_925
	local mainhandString = IEex_FetchString(734)
	local offhandString = IEex_FetchString(733)
	local strengthString = IEex_FetchString(1145)
	local dexterityString = IEex_FetchString(1151)
	local proficiencyString = IEex_FetchString(32561)
	local raceString = IEex_FetchString(1048)
	local baseString = IEex_FetchString(31353)
	local rangedString = IEex_FetchString(41123)
	local numberOfAttacksString = IEex_FetchString(9458)
	local criticalHitString = IEex_FetchString(41122)
	local favoredClassString = IEex_FetchString(40310)
	local acidString = IEex_FetchString(15578)
	local coldString = IEex_FetchString(15546)
	local electricityString = IEex_FetchString(15577)
	local fireString = IEex_FetchString(15545)
	local magicDamageString = IEex_FetchString(40319)
	local poisonString = IEex_FetchString(5805)
	local slashingString = IEex_FetchString(11768)
	local piercingString = IEex_FetchString(11769)
	local bludgeoningString = IEex_FetchString(11770)
	local missileString = IEex_FetchString(11767)
	local hasDamageImmunity = false
	local damageImmunityList = {[0x0] = 0, [0x1] = 0, [0x2] = 0, [0x4] = 0, [0x8] = 0, [0x10] = 0, [0x20] = 0, [0x40] = 0, [0x80] = 0, [0x100] = 0, }
	IEex_IterateActorEffects(targetID, function(eData)
		local theopcode = IEex_ReadDword(eData + 0x10)
		local theparameter2 = IEex_ReadDword(eData + 0x20)
		if theopcode == 288 and theparameter2 == 214 then
			local theparameter1 = IEex_ReadDword(eData + 0x1C)
			local thesavingthrow = IEex_ReadDword(eData + 0x40)
			if damageImmunityList[theparameter1] then
				hasDamageImmunity = true
				if bit.band(thesavingthrow, 0x10000) > 0 then
					damageImmunityList[theparameter1] = 2
				else
					damageImmunityList[theparameter1] = 1
				end
			end
		end
	end)
	local lookForClassNames = (descPanelNum == 0)
	ex_current_record_on_weapon_statistics = false
	IEex_IterateCPtrListNode(m_plstStrings, function(lineEntry, node)
		local line = IEex_ReadString(IEex_ReadDword(lineEntry + 0x4))

		if string.match(line, mainhandString) or string.match(line, rangedString) then
			ex_current_record_hand = 1
		elseif string.match(line, offhandString) then
			ex_current_record_hand = 2
		end
		if lookForClassNames then
			IEex_IterateActorEffects(targetID, function(eData)
				local theopcode = IEex_ReadDword(eData + 0x10)
				local theresource = IEex_ReadLString(eData + 0x30, 8)
				if theopcode == 500 and theresource == "MECLSNAM" then
					local theparameter1 = IEex_ReadDword(eData + 0x1C)
					local theparameter2 = IEex_ReadDword(eData + 0x20)
					local found_it = false
					for k, v in ipairs(ex_class_name_strings[theparameter2]) do
						local classString = IEex_FetchString(v)
						if not found_it and string.match(line, classString .. ":") then
							found_it = true
							line = string.gsub(line, classString, IEex_FetchString(theparameter1))
						end
					end
				end
			end)
			if string.match(line, favoredClassString) then
				lookForClassNames = false
			end
		elseif ex_previous_line_was_race then
			ex_previous_line_was_race = false
			if IEex_ReadByte(creatureData + 0x7B3, 0x0) > 4 then
				line = line .. IEex_FetchString(ex_tra_55603)
			end
		elseif string.match(line, raceString) then
			ex_previous_line_was_race = true
		elseif string.match(line, sneakAttackDamageString .. ":") then
			local rogueLevel = IEex_GetActorStat(targetID, 104)
			local sneakAttackDiceNumberMainHand = math.floor((rogueLevel + 1) / 2) + IEex_ReadByte(creatureData + 0x744 + ex_feat_name_id["ME_IMPROVED_SNEAK_ATTACK"], 0x0)
			local sneakAttackDiceNumberOffHand = sneakAttackDiceNumberMainHand
			local isLauncher = false
			local numWeapons = 0
			IEex_IterateActorEffects(targetID, function(eData)
				local theopcode = IEex_ReadDword(eData + 0x10)
				local theparameter2 = IEex_ReadDword(eData + 0x20)
				local thespecial = IEex_ReadDword(eData + 0x48)
				if theopcode == 288 and theparameter2 == 192 then
					local theparameter1 = IEex_ReadDword(eData + 0x1C)
					local thesavingthrow = IEex_ReadDword(eData + 0x40)
					local theresource = IEex_ReadLString(eData + 0x30, 8)
					if bit.band(thesavingthrow, 0x30000) == 0 and (bit.band(thesavingthrow, 0x40000) > 0 or rogueLevel > 0) then
						sneakAttackDiceNumberMainHand = sneakAttackDiceNumberMainHand + theparameter1
						sneakAttackDiceNumberOffHand = sneakAttackDiceNumberOffHand + theparameter1
					end
				elseif theopcode == 288 and theparameter2 == 241 then
					if thespecial == 5 then
						numWeapons = numWeapons + 1
					elseif thespecial == 7 then
						isLauncher = true
					end
				end
			end)
			local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
			local weaponHeader = IEex_ReadWord(creatureData + 0x4BA6, 0x0)
			local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
			local weaponRES = ""
			local weaponWrapper = 0
--			local headerType = 1
			local offhandSlotData = 0
			local offhandRES = ""
			if slotData > 0 then
				weaponRES = IEex_ReadLString(slotData + 0xC, 8)
				local weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
				if weaponWrapper:isValid() then
					local weaponData = weaponWrapper:getData()
					local numHeaders = IEex_ReadSignedWord(weaponData + 0x68, 0x0)
					if weaponHeader >= numHeaders then
						weaponHeader = 0
					end
					local numEffects = IEex_ReadWord(weaponData + 0x82 + weaponHeader * 0x38 + 0x1E, 0x0)
					local firstEffectIndex = IEex_ReadWord(weaponData + 0x82 + weaponHeader * 0x38 + 0x20, 0x0)
--					local itemType = IEex_ReadWord(weaponData + 0x1C, 0x0)
--					headerType = IEex_ReadByte(weaponData + 0x82 + weaponHeader * 0x38, 0x0)
					local effectOffset = IEex_ReadDword(weaponData + 0x6A)
					local numGlobalEffects = IEex_ReadWord(weaponData + 0x70, 0x0)
					for i = 0, numGlobalEffects - 1, 1 do
						local offset = weaponData + effectOffset + i * 0x30
						local theopcode = IEex_ReadWord(offset, 0x0)
						local theparameter2 = IEex_ReadDword(offset + 0x8)
						if theopcode == 288 and theparameter2 == 192 then
							local theparameter1 = IEex_ReadDword(offset + 0x4)
							local thesavingthrow = IEex_ReadDword(offset + 0x24)
							if bit.band(thesavingthrow, 0x30000) == 0x10000 and (bit.band(thesavingthrow, 0x40000) > 0 or rogueLevel > 0) then
								sneakAttackDiceNumberMainHand = sneakAttackDiceNumberMainHand + theparameter1
							end
						end
					end
					for i = firstEffectIndex, firstEffectIndex + numEffects - 1, 1 do
						local offset = weaponData + effectOffset + i * 0x30
						local theopcode = IEex_ReadWord(offset, 0x0)
						local theresource = IEex_ReadLString(offset + 0x14, 8)
						if theopcode == 500 and theresource == "EXDAMAGE" then
							local headerExtraSneakAttackDice = IEex_ReadByte(offset + 0x6, 0x0)
							local thesavingthrow = IEex_ReadDword(offset + 0x24)
							if bit.band(thesavingthrow, 0x1800000) == 0x1800000 and sneakAttackDiceNumberMainHand > 0 then
								sneakAttackDiceNumberMainHand = sneakAttackDiceNumberMainHand + headerExtraSneakAttackDice
							end
						end
					end
				end
				weaponWrapper:free()
			end
			if weaponSlot == 42 and numWeapons >= 2 then
				numWeapons = 1
			end
			if numWeapons >= 2 and weaponSlot >= 43 then
				if weaponSlot % 2 == 1 then
					offhandSlotData = IEex_ReadDword(creatureData + 0x4AD8 + (weaponSlot + 1) * 0x4)
				else
					offhandSlotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
				end
				if offhandSlotData > 0 then
					offhandRES = IEex_ReadLString(offhandSlotData + 0xC, 8)
					local offhandWrapper = IEex_DemandRes(offhandRES, "ITM")
					if offhandWrapper:isValid() then
						local weaponData = offhandWrapper:getData()
						local numEffects = IEex_ReadWord(weaponData + 0x82 + 0x1E, 0x0)
						local firstEffectIndex = IEex_ReadWord(weaponData + 0x82 + 0x20, 0x0)
	--					local itemType = IEex_ReadWord(weaponData + 0x1C, 0x0)
	--					headerType = IEex_ReadByte(weaponData + 0x82 + weaponHeader * 0x38, 0x0)
						local effectOffset = IEex_ReadDword(weaponData + 0x6A)
						local numGlobalEffects = IEex_ReadWord(weaponData + 0x70, 0x0)
						for i = 0, numGlobalEffects - 1, 1 do
							local offset = weaponData + effectOffset + i * 0x30
							local theopcode = IEex_ReadWord(offset, 0x0)
							local theparameter2 = IEex_ReadDword(offset + 0x8)
							if theopcode == 288 and theparameter2 == 192 then
								local theparameter1 = IEex_ReadDword(offset + 0x4)
								local thesavingthrow = IEex_ReadDword(offset + 0x24)
								if bit.band(thesavingthrow, 0x30000) == 0x10000 and (bit.band(thesavingthrow, 0x40000) > 0 or rogueLevel > 0) then
									sneakAttackDiceNumberOffHand = sneakAttackDiceNumberOffHand + theparameter1
								end
							end
						end
						for i = firstEffectIndex, firstEffectIndex + numEffects - 1, 1 do
							local offset = weaponData + effectOffset + i * 0x30
							local theopcode = IEex_ReadWord(offset, 0x0)
							local theresource = IEex_ReadLString(offset + 0x14, 8)
							if theopcode == 500 and theresource == "EXDAMAGE" then
								local headerExtraSneakAttackDice = IEex_ReadByte(offset + 0x6, 0x0)
								local thesavingthrow = IEex_ReadDword(offset + 0x24)
								if bit.band(thesavingthrow, 0x1800000) == 0x1800000 and sneakAttackDiceNumberOffHand > 0 then
									sneakAttackDiceNumberOffHand = sneakAttackDiceNumberOffHand + headerExtraSneakAttackDice
								end
							end
						end
					end
					offhandWrapper:free()
				end
			end
			if isLauncher then
				local weaponSet = IEex_ReadByte(creatureData + 0x4C68, 0x0)
				local launcherSlotData = IEex_ReadDword(creatureData + 0x4AD8 + (43 + 2 * weaponSet) * 0x4)
				if launcherSlotData > 0 then
					local launcherRES = IEex_ReadLString(launcherSlotData + 0xC, 8)
					local launcherWrapper = IEex_DemandRes(launcherRES, "ITM")
					if launcherWrapper:isValid() then
						local weaponData = launcherWrapper:getData()
						local numHeaders = IEex_ReadSignedWord(weaponData + 0x68, 0x0)
						local numEffects = IEex_ReadWord(weaponData + 0x82 + 0x1E, 0x0)
						local firstEffectIndex = IEex_ReadWord(weaponData + 0x82 + 0x20, 0x0)
	--					local itemType = IEex_ReadWord(weaponData + 0x1C, 0x0)
	--					headerType = IEex_ReadByte(weaponData + 0x82 + weaponHeader * 0x38, 0x0)
						local effectOffset = IEex_ReadDword(weaponData + 0x6A)
						local numGlobalEffects = IEex_ReadWord(weaponData + 0x70, 0x0)
						for i = 0, numGlobalEffects - 1, 1 do
							local offset = weaponData + effectOffset + i * 0x30
							local theopcode = IEex_ReadWord(offset, 0x0)
							local theparameter2 = IEex_ReadDword(offset + 0x8)
							if theopcode == 288 and theparameter2 == 192 then
								local theparameter1 = IEex_ReadDword(offset + 0x4)
								local thesavingthrow = IEex_ReadDword(offset + 0x24)
								if bit.band(thesavingthrow, 0x30000) == 0x10000 and (bit.band(thesavingthrow, 0x40000) > 0 or rogueLevel > 0) then
									sneakAttackDiceNumberMainHand = sneakAttackDiceNumberMainHand + theparameter1
								end
							end
						end
						for i = firstEffectIndex, firstEffectIndex + numEffects - 1, 1 do
							local offset = weaponData + effectOffset + i * 0x30
							local theopcode = IEex_ReadWord(offset, 0x0)
							local theresource = IEex_ReadLString(offset + 0x14, 8)
							if theopcode == 500 and theresource == "EXDAMAGE" then
								local headerExtraSneakAttackDice = IEex_ReadByte(offset + 0x6, 0x0)
								local thesavingthrow = IEex_ReadDword(offset + 0x24)
								if bit.band(thesavingthrow, 0x1800000) == 0x1800000 and sneakAttackDiceNumberMainHand > 0 then
									sneakAttackDiceNumberMainHand = sneakAttackDiceNumberMainHand + headerExtraSneakAttackDice
								end
							end
						end
					end
					launcherWrapper:free()
				end
			end
			if numWeapons >= 2 and weaponSlot >= 43 then
				line = string.gsub(line, "%d+d6", sneakAttackDiceNumberMainHand .. "d6/" .. sneakAttackDiceNumberOffHand .. "d6")
			else
				line = string.gsub(line, "%d+d6", sneakAttackDiceNumberMainHand .. "d6")
			end
		elseif string.match(line, turnUndeadLevelString .. ":") then
			local clericLevel = IEex_GetActorStat(targetID, 98)
			local paladinLevel = IEex_GetActorStat(targetID, 102)
			local charismaBonus = math.floor((IEex_GetActorStat(targetID, 42) - 10) / 2)
			local turnLevel = clericLevel + charismaBonus
			if paladinLevel >= 3 then
				turnLevel = turnLevel + paladinLevel - 2
			end
			if IEex_GetActorSpellState(targetID, 194) then
				IEex_IterateActorEffects(targetID, function(eData)
					local theopcode = IEex_ReadDword(eData + 0x10)
					local theparameter2 = IEex_ReadDword(eData + 0x20)
					if theopcode == 288 and theparameter2 == 194 then
						local theparameter1 = IEex_ReadDword(eData + 0x1C)
						turnLevel = turnLevel + theparameter1
					end
				end)
			end
			local turningFeat = IEex_ReadByte(creatureData + 0x78C, 0)
			turnLevel = turnLevel + turningFeat * 3
			line = string.gsub(line, "%d+", turnLevel)
		elseif string.match(line, wholenessOfBodyString .. ":") then
			local monkLevel = IEex_GetActorStat(targetID, 101)
			local wisdomBonus = math.floor((IEex_GetActorStat(targetID, 39) - 10) / 2)
			if wisdomBonus < 1 then
				wisdomBonus = 1
			end
			line = string.gsub(line, "%d+", monkLevel * wisdomBonus)
		elseif string.match(line, monkWisdomBonusString .. ":") or string.match(line, genericString .. ":") or string.match(line, expertiseString .. ":") then
			local monkLevel = IEex_GetActorStat(targetID, 101)
			if monkLevel > 0 then
				local wisdomBonus = math.floor((IEex_GetActorStat(targetID, 39) - 10) / 2)
				if wisdomBonus > 0 then
					local monkACBonusDisabled = false
					local fixMonkACBonus = true
					local unfixMonkACBonus = (IEex_ReadByte(creatureData + 0x9D4, 0x0) > 0)
					IEex_IterateActorEffects(targetID, function(eData)
						local theopcode = IEex_ReadDword(eData + 0x10)
						local theparameter1 = IEex_ReadDword(eData + 0x1C)
						local theparameter2 = IEex_ReadDword(eData + 0x20)
						local theresource = IEex_ReadLString(eData + 0x30, 8)
						local thesavingthrow = IEex_ReadDword(eData + 0x40)
						local thespecial = IEex_ReadDword(eData + 0x48)
						if theopcode == 288 and theparameter2 == 241 then
							local thegeneralitemcategory = IEex_ReadByte(eData + 0x48, 0x0)
							if thegeneralitemcategory >= 1 and thegeneralitemcategory <= 3 then
								monkACBonusDisabled = true
								if (thegeneralitemcategory == 1 and (theparameter1 ~= 67 or not ex_elven_chainmail_counts_as_unarmored)) or thegeneralitemcategory == 3 then
									fixMonkACBonus = false
								end
							end
--[[
						elseif theopcode == 502 and theresource == "MEPOLYBL" then
							if thespecial > monkLevel then
								unfixMonkACBonus = true
							end
--]]
						end

					end)
					if not monkACBonusDisabled then
						if unfixMonkACBonus then
							if string.match(line, monkWisdomBonusString .. ":") then
								line = string.gsub(line, "%d+", 0)
							elseif string.match(line, genericString .. ":") then
								local genericAC = string.match(line, "%d+")
								if string.match(line, "%-") then
									genericAC = genericAC * -1
								end
								genericAC = genericAC + wisdomBonus
								if genericAC > 0 then
									line = string.gsub(line, "." .. "%d+", "+" .. genericAC)
								elseif genericAC < 0 then
									line = string.gsub(line, "." .. "%d+", "-" .. math.abs(genericAC))
								else
									line = ""
								end
							end
						elseif ex_monk_bonus_ac_cannot_exceed_monk_level and wisdomBonus > monkLevel then
							if string.match(line, monkWisdomBonusString .. ":") then
								line = string.gsub(line, "%d+", monkLevel)
							elseif string.match(line, genericString .. ":") then
								local genericAC = string.match(line, "%d+")
								if string.match(line, "%-") then
									genericAC = genericAC * -1
								end
								genericAC = genericAC + wisdomBonus - monkLevel
								if genericAC > 0 then
									line = string.gsub(line, "." .. "%d+", "+" .. genericAC)
								elseif genericAC < 0 then
									line = string.gsub(line, "." .. "%d+", "-" .. math.abs(genericAC))
								else
									line = ""
								end
							end
						end
					elseif monkACBonusDisabled and fixMonkACBonus and not unfixMonkACBonus then
						if ex_monk_bonus_ac_cannot_exceed_monk_level and wisdomBonus > monkLevel then
							wisdomBonus = monkLevel
						end
						if string.match(line, monkWisdomBonusString .. ":") then
							line = string.gsub(line, "0", wisdomBonus)
						elseif string.match(line, genericString .. ":") then
							local genericAC = string.match(line, "%d+")
							if string.match(line, "%-") then
								genericAC = genericAC * -1
							end
							genericAC = genericAC - wisdomBonus
							if genericAC > 0 then
								line = string.gsub(line, "." .. "%d+", "+" .. genericAC)
							elseif genericAC < 0 then
								line = string.gsub(line, "." .. "%d+", "-" .. math.abs(genericAC))
							else
								line = ""
							end
						end
					end
				end
			end
			local expertiseCount = IEex_ReadDword(creatureData + 0x4C54)
			if expertiseCount > 0 then
				local actionID = IEex_ReadWord(creatureData + 0x476, 0x0)
				if actionID ~= 3 and actionID ~= 94 and actionID ~= 98 and actionID ~= 105 and actionID ~= 134 and actionID ~= 27 then
					local isRanged = false
					local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
					local weaponHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
					local weaponRES = ""
					local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
					local weaponWrapper = 0
					if slotData > 0 then
						weaponRES = IEex_ReadLString(slotData + 0xC, 8)
						weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
						if weaponWrapper:isValid() then
							local itemData = weaponWrapper:getData()
							local numHeaders = IEex_ReadSignedWord(itemData + 0x68, 0x0)
							if weaponHeader >= numHeaders then
								weaponHeader = 0
							end
							headerType = IEex_ReadByte(itemData + 0x82 + weaponHeader * 0x38, 0x0)
							local itemType = IEex_ReadWord(itemData + 0x1C, 0x0)
							if headerType == 2 then
								isRanged = true
							end
						end
					end
					if not isRanged then
						if string.match(line, expertiseString .. ":") then
							line = string.gsub(line, "%d+", 0)
						elseif string.match(line, genericString .. ":") then
							local genericAC = string.match(line, "%d+")
							if string.match(line, "%-") then
								genericAC = genericAC * -1
							end
							genericAC = genericAC + expertiseCount
							if genericAC > 0 then
								line = string.gsub(line, "." .. "%d+", "+" .. genericAC)
							elseif genericAC < 0 then
								line = string.gsub(line, "." .. "%d+", "-" .. math.abs(genericAC))
							else
								line = ""
							end
						end
					end
				end
			end
		elseif string.match(line, bonusSpellsString) then
			ex_checking_bonus_spells = true
		elseif ex_checking_bonus_spells and line == "" then
			ex_checking_bonus_spells = false
			if IEex_GetActorSpellState(targetID, 197) then
				local advancedSlotsList = {}
				IEex_IterateActorEffects(targetID, function(eData)
					local theopcode = IEex_ReadDword(eData + 0x10)
					local theparameter1 = IEex_ReadDword(eData + 0x1C)
					local theparameter2 = IEex_ReadDword(eData + 0x20)
					local theparameter3 = IEex_ReadDword(eData + 0x60)
					local theresource = IEex_ReadLString(eData + 0x30, 8)
					local thesavingthrow = IEex_ReadDword(eData + 0x40)
					local thespecial = IEex_ReadDword(eData + 0x48)
					if theopcode == 288 and theparameter2 == 197 and bit.band(thesavingthrow, 0x10000) > 0 then
						if not advancedSlotsList[thespecial] then
							advancedSlotsList[thespecial] = {theparameter1 - theparameter3, theparameter1}
						else
							advancedSlotsList[thespecial] = {advancedSlotsList[thespecial][1] + theparameter1 - theparameter3, advancedSlotsList[thespecial][2] + theparameter1}
						end
					end
				end)
				if #advancedSlotsList > 0 then
					line = IEex_FetchString(ex_tra_55495)
				end
				local firstAdvancedSlot = true
				for k, v in ipairs(advancedSlotsList) do
					if not firstAdvancedSlot then
						line = line .. ", "
					end
					line = line .. levelString .. " +" .. k .. ": " .. v[1] .. "/" .. v[2]
					firstAdvancedSlot = false
				end
			end
		elseif descPanelNum == 1 and string.match(line, castingFailureString .. ":") then
			local armoredArcanaFeatCount = IEex_ReadByte(creatureData + 0x781, 0x0)
			local castingFailure = string.match(line, "%d+")
			castingFailure = castingFailure - (armoredArcanaFeatCount * (ex_armored_arcana_multiplier - 1)) * 5
			if castingFailure < 0 then
				castingFailure = 0
			end
			line = string.gsub(line, "%d+", castingFailure)
		elseif descPanelNum == 1 and string.match(line, armoredArcanaString .. ":") then
			local armoredArcanaFeatCount = IEex_ReadByte(creatureData + 0x781, 0x0)
			line = string.gsub(line, "%d+", (armoredArcanaFeatCount * ex_armored_arcana_multiplier) * 5)
		elseif descPanelNum == 1 and string.match(line, abilitiesString .. ":") then
			local abilityBonus = string.match(line, "%d+")
			if string.match(line, "%-") then
				abilityBonus = abilityBonus * -1
			end
			if ex_current_record_hand == 1 then
				abilityBonus = abilityBonus + IEex_ReadSignedByte(creatureData + 0x9F8, 0x0)
			else
				abilityBonus = abilityBonus + IEex_ReadSignedByte(creatureData + 0x9FC, 0x0)
			end
			if abilityBonus > 0 then
				line = string.gsub(line, "." .. "%d+", "+" .. abilityBonus)
			elseif abilityBonus < 0 then
				line = string.gsub(line, "." .. "%d+", "-" .. math.abs(abilityBonus))
			else
				line = ""
			end
		elseif string.match(line, mainhandString .. ":") or string.match(line, offhandString .. ":") or string.match(line, numberOfAttacksString) then
			local normalAPR = IEex_GetActorStat(targetID, 8)
			local imptwfFeatID = ex_feat_name_id["ME_IMPROVED_TWO_WEAPON_FIGHTING"]
			local imptwfFeatCount = 0
			if imptwfFeatID ~= nil then
				imptwfFeatCount = IEex_ReadByte(creatureData + 0x744 + imptwfFeatID, 0x0)
			end
			local manyshotFeatID = ex_feat_name_id["ME_MANYSHOT"]
			local manyshotFeatCount = 0
			if manyshotFeatID ~= nil then
				manyshotFeatCount = IEex_ReadByte(creatureData + 0x744 + manyshotFeatID, 0x0)
			end
			local rapidShotEnabled = (IEex_ReadByte(creatureData + 0x4C64, 0x0) > 0)
			local monkLevel = IEex_GetActorStat(targetID, 101)
			local handSpecificAttackBonus = IEex_ReadSignedByte(creatureData + 0x9F8, 0x0)
			if ex_current_record_hand == 2 then
				handSpecificAttackBonus = IEex_ReadSignedByte(creatureData + 0x9FC, 0x0)
			end
			local baseAPR = IEex_ReadByte(creatureData + 0x5ED, 0x0)
			local trueBaseAPR = baseAPR
			local monkAttackBonusDisabled, fixMonkAttackBonus = IEex_CheckMonkAttackBonus(creatureData)
			local firstFiveAttacksDisabled = {0, 0, 0, 0, 0}
			local firstFiveAttacksFixed = {0, 0, 0, 0, 0}
			local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
			local weaponHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
			local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
			local weaponRES = ""
			local weaponWrapper = 0
			local rapidShotActive = false
			if slotData > 0 then
				weaponRES = IEex_ReadLString(slotData + 0xC, 8)
				weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
				if weaponWrapper:isValid() then
					local weaponData = weaponWrapper:getData()
					local numHeaders = IEex_ReadSignedWord(weaponData + 0x68, 0x0)
					if weaponHeader >= numHeaders then
						weaponHeader = 0
					end
					local itemType = IEex_ReadWord(weaponData + 0x1C, 0x0)
					headerType = IEex_ReadByte(weaponData + 0x82 + weaponHeader * 0x38, 0x0)
					if rapidShotEnabled and headerType == 2 and itemType ~= 27 and itemType ~= 31 then
						rapidShotActive = true
					end
				end
			end
			if monkAttackBonusDisabled and fixMonkAttackBonus then
				trueBaseAPR = tonumber(IEex_2DAGetAtStrings("BAATMKU", "NUM_ATTACKS", tostring(monkLevel)))
				if trueBaseAPR > 4 then
					trueBaseAPR = 4
				end
				firstFiveAttacksDisabled[1] = tonumber(IEex_2DAGetAtStrings("BAATNFG", "BASE_ATTACK", tostring(monkLevel)))
				firstFiveAttacksFixed[1] = tonumber(IEex_2DAGetAtStrings("BAATMKU", "BASE_ATTACK", tostring(monkLevel)))
				for i = 2, 5, 1 do
					if i == 2 and rapidShotActive then
						firstFiveAttacksDisabled[i] = firstFiveAttacksDisabled[i - 1]
						firstFiveAttacksFixed[i] = firstFiveAttacksFixed[i - 1]
					else
						firstFiveAttacksDisabled[i] = firstFiveAttacksDisabled[i - 1] - 5
						if firstFiveAttacksDisabled[i] < 0 then
							firstFiveAttacksDisabled[i] = 0
						end
						firstFiveAttacksFixed[i] = firstFiveAttacksFixed[i - 1] - 3
					end
				end
--				handSpecificAttackBonus = handSpecificAttackBonus + tonumber(IEex_2DAGetAtStrings("BAATMKU", "BASE_ATTACK", tostring(monkLevel))) - tonumber(IEex_2DAGetAtStrings("BAATNFG", "BASE_ATTACK", tostring(monkLevel)))
			end
			if ex_record_attack_stats_hidden_difference[targetID] ~= nil then
				handSpecificAttackBonus = handSpecificAttackBonus - ex_record_attack_stats_hidden_difference[targetID][1]
			end
			local attackPenaltyIncrement = 5
			local monkAttackBonusNowEnabled = (monkLevel > 0 and (not monkAttackBonusDisabled or fixMonkAttackBonus))
			local extraMonkAttacks = 0
			if monkAttackBonusNowEnabled then
				attackPenaltyIncrement = 3
				extraMonkAttacks = ex_monk_apr_progression[monkLevel]
				if IEex_GetEquippedWeaponRES(targetID) == ex_monk_fist_progression[monkLevel] or IEex_GetEquippedWeaponRES(targetID) == ex_incorporeal_monk_fist_progression[monkLevel] or string.sub(IEex_GetEquippedWeaponRES(targetID), 1, 7) == "00MFIST" then
					extraMonkAttacks = extraMonkAttacks + 1
				end
			end
			local attackI = 0

			if not string.match(line, numberOfAttacksString) then
				line = string.gsub(line, "(%d+)", "!%1!")
				for w in string.gmatch(line, "%d+") do
					attackI = attackI + 1
					local monkAttackPenaltyIncrementFix = 0
					if monkAttackBonusDisabled and fixMonkAttackBonus then
						monkAttackPenaltyIncrementFix = firstFiveAttacksFixed[attackI] - firstFiveAttacksDisabled[attackI]
					end
					line = string.gsub(line, "!" .. w .. "!", w + handSpecificAttackBonus + monkAttackPenaltyIncrementFix, 1)
				end
			end

			if ((normalAPR + imptwfFeatCount + extraMonkAttacks >= 5) or ((trueBaseAPR + imptwfFeatCount + extraMonkAttacks >= 5))) or (manyshotFeatCount > 0 and rapidShotEnabled) then
				local totalAttacks = trueBaseAPR + extraMonkAttacks
				local extraAttacks = 0
				local extraMainhandAttacks = extraMonkAttacks
				local manyshotAttacks = manyshotFeatCount
				local numWeapons = 0
				local headerType = 1
				local offhandSlotData = 0
				local offhandRES = ""
				if slotData > 0 then
					weaponRES = IEex_ReadLString(slotData + 0xC, 8)
					local weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
					if weaponWrapper:isValid() then
						local weaponData = weaponWrapper:getData()
						local numHeaders = IEex_ReadSignedWord(weaponData + 0x68, 0x0)
						if weaponHeader >= numHeaders then
							weaponHeader = 0
						end
						local itemType = IEex_ReadWord(weaponData + 0x1C, 0x0)
						headerType = IEex_ReadByte(weaponData + 0x82 + weaponHeader * 0x38, 0x0)
						if rapidShotEnabled and headerType == 2 and itemType ~= 27 and itemType ~= 31 then
							totalAttacks = totalAttacks + 1
							extraMainhandAttacks = extraMainhandAttacks + 1
						end
						local effectOffset = IEex_ReadDword(weaponData + 0x6A)
						local numGlobalEffects = IEex_ReadWord(weaponData + 0x70, 0x0)
						for i = 0, numGlobalEffects - 1, 1 do
							local offset = weaponData + effectOffset + i * 0x30
							local theopcode = IEex_ReadWord(offset, 0x0)
							local theparameter2 = IEex_ReadDword(offset + 0x8)
							if theopcode == 1 and theparameter2 == 0 then
								local theparameter1 = IEex_ReadDword(offset + 0x4)
								totalAttacks = totalAttacks + theparameter1
								extraMainhandAttacks = extraMainhandAttacks + theparameter1
							end
						end
					end
				end
				local isFistWeapon = false
				local isBow = false
				local wearingLightArmor = true
				IEex_IterateActorEffects(targetID, function(eData)
					local theopcode = IEex_ReadDword(eData + 0x10)
					local theparameter1 = IEex_ReadDword(eData + 0x1C)
					local theparameter2 = IEex_ReadDword(eData + 0x20)
					local thesavingthrow = IEex_ReadDword(eData + 0x40)
					local thespecial = IEex_ReadDword(eData + 0x48)
					if theopcode == 288 and theparameter2 == 241 then
						local thegeneralitemcategory = IEex_ReadByte(eData + 0x48, 0x0)
						if thegeneralitemcategory == 5 then
							numWeapons = numWeapons + 1
						elseif thegeneralitemcategory == 6 then
							isFistWeapon = true
						elseif (theparameter1 >= 62 and theparameter1 <= 66) or theparameter1 == 68 then
							wearingLightArmor = false
						elseif theparameter1 == 15 then
							isBow = true
						end
					end
				end)
				if weaponSlot == 42 and numWeapons >= 2 then
					numWeapons = 1
				end
				if numWeapons >= 2 and weaponSlot >= 43 then
					if weaponSlot % 2 == 1 then
						offhandSlotData = IEex_ReadDword(creatureData + 0x4AD8 + (weaponSlot + 1) * 0x4)
					else
						offhandSlotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
					end
					if offhandSlotData > 0 then
						offhandRES = IEex_ReadLString(offhandSlotData + 0xC, 8)
						local offhandWrapper = IEex_DemandRes(offhandRES, "ITM")
						if offhandWrapper:isValid() then
							local weaponData = offhandWrapper:getData()
							local effectOffset = IEex_ReadDword(weaponData + 0x6A)
							local numGlobalEffects = IEex_ReadWord(weaponData + 0x70, 0x0)
							for i = 0, numGlobalEffects - 1, 1 do
								local offset = weaponData + effectOffset + i * 0x30
								local theopcode = IEex_ReadWord(offset, 0x0)
								local theparameter2 = IEex_ReadDword(offset + 0x8)
								if theopcode == 1 and theparameter2 == 0 then
									local theparameter1 = IEex_ReadDword(offset + 0x4)
									totalAttacks = totalAttacks + theparameter1
									extraAttacks = extraAttacks + theparameter1
								end
							end
						end
						offhandWrapper:free()
					end
				end
				IEex_IterateActorEffects(targetID, function(eData)
					local theopcode = IEex_ReadDword(eData + 0x10)
					local theparameter1 = IEex_ReadDword(eData + 0x1C)
					local theparameter2 = IEex_ReadDword(eData + 0x20)
					local thesavingthrow = IEex_ReadDword(eData + 0x40)
					local thespecial = IEex_ReadDword(eData + 0x48)
					local theparent_resource = IEex_ReadLString(eData + 0x94, 8)
					if theopcode == 1 then
						if theparameter2 == 0 and theparent_resource ~= weaponRES and theparent_resource ~= offhandRES then
							totalAttacks = totalAttacks + theparameter1
							if bit.band(thesavingthrow, 0x100000) > 0 and offhandRES ~= "" then
								extraAttacks = extraAttacks + theparameter1
							else
								extraMainhandAttacks = extraMainhandAttacks + theparameter1
							end
						elseif theparameter2 == 1 then
							totalAttacks = theparameter1
							if setAPR ~= 0 then
								setAPR = theparameter1
							end
						end
					elseif theopcode == 288 and theparameter2 == 196 and (thespecial == 0 or thespecial == headerType) then
						if bit.band(thesavingthrow, 0x20000) > 0 then
							manyshotAttacks = manyshotAttacks + theparameter1
						end
					end
				end)
				if not isBow or not rapidShotEnabled then
					manyshotAttacks = 0
				end
				local usingImptwf = false
				if numWeapons >= 2 then
					totalAttacks = totalAttacks + 1
				end
				local stateValue = bit.bor(IEex_ReadDword(creatureData + 0x5BC), IEex_ReadDword(creatureData + 0x920))
				if bit.band(stateValue, 0x8000) > 0 then
					totalAttacks = totalAttacks + 1
					extraMainhandAttacks = extraMainhandAttacks + 1
				end
				if bit.band(stateValue, 0x10000) > 0 then
					totalAttacks = totalAttacks - 1
					extraMainhandAttacks = extraMainhandAttacks - 1
				end
				if numWeapons >= 2 then
					if imptwfFeatCount > 0 and (IEex_GetActorStat(targetID, 103) < 9 or wearingLightArmor or (IEex_ReadByte(creatureData + 0x5EC, 0x0) >= 16 and bit.band(IEex_ReadDword(creatureData + 0x75C), 0x2) > 0 and bit.band(IEex_ReadDword(creatureData + 0x764), 0x40) > 0)) then
						totalAttacks = totalAttacks + 1
						extraAttacks = extraAttacks + 1
						usingImptwf = true
						if imptwfFeatCount > 1 and (IEex_GetActorStat(targetID, 103) < 15 or wearingLightArmor or (IEex_ReadByte(creatureData + 0x5EC, 0x0) >= 21 and bit.band(IEex_ReadDword(creatureData + 0x75C), 0x2) > 0 and bit.band(IEex_ReadDword(creatureData + 0x764), 0x40) > 0)) then
							totalAttacks = totalAttacks + 1
							extraAttacks = extraAttacks + 1
						end
					end
					if normalAPR == 5 and baseAPR < 4 then
						extraMainhandAttacks = extraMainhandAttacks + baseAPR - normalAPR + 1
					end
				else
					extraAttacks = extraAttacks + extraMainhandAttacks
					extraMainhandAttacks = 0
					if normalAPR == 5 then
						extraAttacks = extraAttacks + baseAPR - normalAPR
						if extraAttacks < 0 then
							extraAttacks = 0
						end
					end
				end
				totalAttacks = totalAttacks + manyshotAttacks
				if IEex_GetActorSpellState(targetID, 138) then
					if numWeapons >= 2 then
						extraMainhandAttacks = extraMainhandAttacks * 2 + (normalAPR - 1)
						extraAttacks = extraAttacks * 2 + 1
					else
						extraAttacks = extraAttacks * 2 + normalAPR
					end
					manyshotAttacks = manyshotAttacks * 2
					totalAttacks = normalAPR + extraAttacks + extraMainhandAttacks + manyshotAttacks
				end
				if string.match(line, numberOfAttacksString) then
					if numWeapons >= 2 then
						line = string.gsub(line, "%d.%d", (normalAPR - 1 + extraMainhandAttacks) .. "+" .. (1 + extraAttacks))
					else
						line = string.gsub(line, "%d+", totalAttacks)
					end
				else
					local lastAttackRollBonus = 0
					for w in string.gmatch(line, "%d+") do
						lastAttackRollBonus = w
					end
					if manyshotAttacks > 0 then
						local firstAttackRollBonus = string.match(line, "%d+")
						local manyshotAttackRollBonus = firstAttackRollBonus - attackPenaltyIncrement * manyshotAttacks
						local manyshotAttackListString = ""
						if manyshotAttackRollBonus >= 0 then
							for i = 1, manyshotAttacks, 1 do
								manyshotAttackListString = manyshotAttackListString .. "+" .. manyshotAttackRollBonus .. "/"
							end
							line = string.gsub(line, "." .. firstAttackRollBonus .. ".." .. firstAttackRollBonus, manyshotAttackListString .. "+" .. manyshotAttackRollBonus .. "/+" .. firstAttackRollBonus)
						else
							for i = 1, manyshotAttacks, 1 do
								manyshotAttackListString = manyshotAttackListString .. "-" .. math.abs(manyshotAttackRollBonus) .. "/"
							end
							line = string.gsub(line, "(.)" .. math.abs(firstAttackRollBonus), manyshotAttackListString .. "-" .. math.abs(manyshotAttackRollBonus) .. "/%1" .. firstAttackRollBonus)
						end
					end
					if string.match(line, mainhandString .. ":") and numWeapons >= 2 then
						for i = 1, extraMainhandAttacks, 1 do
							local nextAttackRollBonus = lastAttackRollBonus - i * attackPenaltyIncrement
							if nextAttackRollBonus >= 0 then
								line = line .. "/+" .. nextAttackRollBonus
							else
								line = line .. "/-" .. math.abs(nextAttackRollBonus)
							end
						end
					else
						for i = 1, extraAttacks, 1 do
							local nextAttackRollBonus = lastAttackRollBonus - i * attackPenaltyIncrement
							if nextAttackRollBonus >= 0 then
								line = line .. "/+" .. nextAttackRollBonus
							else
								line = line .. "/-" .. math.abs(nextAttackRollBonus)
							end
						end
					end
				end
			end
			weaponWrapper:free()
		elseif string.match(line, baseString .. ":") and string.match(line, "%+") and ex_current_record_hand == 1 then
			local normalAPR = IEex_GetActorStat(targetID, 8)
			local monkLevel = IEex_GetActorStat(targetID, 101)
			local handSpecificAttackBonus = 0
			local baseAPR = IEex_ReadByte(creatureData + 0x5ED, 0x0)
			local trueBaseAPR = baseAPR
			local monkAttackBonusDisabled, fixMonkAttackBonus = IEex_CheckMonkAttackBonus(creatureData)
			if monkAttackBonusDisabled and fixMonkAttackBonus then
				trueBaseAPR = tonumber(IEex_2DAGetAtStrings("BAATMKU", "NUM_ATTACKS", tostring(monkLevel)))
				if trueBaseAPR > 4 then
					trueBaseAPR = 4
				end
				handSpecificAttackBonus = handSpecificAttackBonus + tonumber(IEex_2DAGetAtStrings("BAATMKU", "BASE_ATTACK", tostring(monkLevel))) - tonumber(IEex_2DAGetAtStrings("BAATNFG", "BASE_ATTACK", tostring(monkLevel)))
				local attackPenaltyIncrement = 3
				local attackI = 0
				local attackIBonus = 0
				line = string.gsub(line, "(%d+)", "!%1!")
				for w in string.gmatch(line, "%d+") do
					attackI = attackI + 1
					local monkAttackPenaltyIncrementFix = 0
					if attackI >= 2 then
						monkAttackPenaltyIncrementFix = (attackI - 1) * 2
					end
					attackIBonus = w + handSpecificAttackBonus + monkAttackPenaltyIncrementFix
					line = string.gsub(line, "!" .. w .. "!", attackIBonus)
				end
				if trueBaseAPR > attackI then
					for i = 1, trueBaseAPR - attackI, 1 do
						local nextAttackRollBonus = attackIBonus - i * attackPenaltyIncrement
						if nextAttackRollBonus >= 0 then
							line = line .. "/+" .. nextAttackRollBonus
						else
							line = line .. "/-" .. math.abs(nextAttackRollBonus)
						end
					end
				end
			end
		elseif descPanelNum == 1 and string.match(line, damageString .. ":") then
			ex_current_record_on_weapon_statistics = true
			local damageBonus = IEex_ReadSignedWord(creatureData + 0x9A6, 0x0)
			local powerAttackCount = IEex_ReadDword(creatureData + 0x4C58)
			if ex_double_power_attack_damage_for_two_handed_weapons and powerAttackCount > 0 then
				local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
				local weaponHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
				local weaponRES = ""
				local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
				local weaponWrapper = 0
				if slotData > 0 then
					weaponRES = IEex_ReadLString(slotData + 0xC, 8)
					weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
					if weaponWrapper:isValid() then
						local itemData = weaponWrapper:getData()
						local numHeaders = IEex_ReadSignedWord(itemData + 0x68, 0x0)
						if weaponHeader >= numHeaders then
							weaponHeader = 0
						end
						headerType = IEex_ReadByte(itemData + 0x82 + weaponHeader * 0x38, 0x0)
						local itemFlags = IEex_ReadDword(itemData + 0x18)
						if headerType == 1 and bit.band(itemFlags, 0x2) > 0 then
							damageBonus = damageBonus - powerAttackCount
						end
					end
					weaponWrapper:free()
				end
			end
			if damageBonus > 0 then
				IEex_SetToken("EXRDVAL1", damageBonus)
				line = line .. string.gsub(IEex_FetchString(ex_tra_55604), "<EXRDVAL1>", damageBonus)
			elseif damageBonus < 0 then
				IEex_SetToken("EXRDVAL1", math.abs(damageBonus))
				line = line .. string.gsub(IEex_FetchString(ex_tra_55605), "<EXRDVAL1>", math.abs(damageBonus))
			end
			local numbersProcessed = 0
			for w in string.gmatch(line, "%d+") do
				if numbersProcessed == 0 then
					ex_current_record_weapon_die_number = tonumber(w)
				elseif numbersProcessed == 1 then
					ex_current_record_weapon_die_size = tonumber(w)
				end
				numbersProcessed = numbersProcessed + 1
			end
			local luckBonus = IEex_ReadSignedWord(creatureData + 0x95C, 0x0)
			if IEex_GetActorSpellState(targetID, 64) then
				line = string.gsub(line, "%d+d%d+", ex_current_record_weapon_die_number * ex_current_record_weapon_die_size)
			elseif luckBonus > 0 then
				local minimumRoll = 1 + luckBonus
				if minimumRoll > ex_current_record_weapon_die_size then
					minimumRoll = ex_current_record_weapon_die_size
				end
				if minimumRoll == ex_current_record_weapon_die_size then
					line = string.gsub(line, "%d+d%d+", ex_current_record_weapon_die_number * ex_current_record_weapon_die_size)
				else
					IEex_SetToken("EXRLVAL1", minimumRoll)
					line = line .. string.gsub(IEex_FetchString(ex_tra_55606), "<EXRLVAL1>", minimumRoll)
				end
			elseif luckBonus < 0 then
				local maximumRoll = ex_current_record_weapon_die_size + luckBonus
				if maximumRoll < 1 then
					maximumRoll = 1
				end
				if maximumRoll == 1 then
					line = string.gsub(line, "%d+d%d+", ex_current_record_weapon_die_number)
				else
					IEex_SetToken("EXRLVAL1", maximumRoll)
					line = line .. string.gsub(IEex_FetchString(ex_tra_55607), "<EXRLVAL1>", maximumRoll)
				end
			end
		elseif descPanelNum == 1 and string.match(line, powerAttackString .. ":") then
			local powerAttackCount = IEex_ReadDword(creatureData + 0x4C58)
			if ex_double_power_attack_damage_for_two_handed_weapons and powerAttackCount > 0 then
				local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
				local weaponHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
				local weaponRES = ""
				local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
				local weaponWrapper = 0
				if slotData > 0 then
					weaponRES = IEex_ReadLString(slotData + 0xC, 8)
					weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
					if weaponWrapper:isValid() then
						local itemData = weaponWrapper:getData()
						local numHeaders = IEex_ReadSignedWord(itemData + 0x68, 0x0)
						if weaponHeader >= numHeaders then
							weaponHeader = 0
						end
						headerType = IEex_ReadByte(itemData + 0x82 + weaponHeader * 0x38, 0x0)
						local itemFlags = IEex_ReadDword(itemData + 0x18)
						if headerType == 1 and bit.band(itemFlags, 0x2) > 0 then
							line = string.gsub(line, "." .. "%d+", "+" .. powerAttackCount * 2)
						end
					end
					weaponWrapper:free()
				end
			end
		elseif descPanelNum == 1 and string.match(line, damageBonusString .. ":") then
			local damageBonus = IEex_ReadSignedWord(creatureData + 0x9A6, 0x0)
			local powerAttackCount = IEex_ReadDword(creatureData + 0x4C58)
			if ex_double_power_attack_damage_for_two_handed_weapons and powerAttackCount > 0 then
				local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
				local weaponHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
				local weaponRES = ""
				local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
				local weaponWrapper = 0
				if slotData > 0 then
					weaponRES = IEex_ReadLString(slotData + 0xC, 8)
					weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
					if weaponWrapper:isValid() then
						local itemData = weaponWrapper:getData()
						local numHeaders = IEex_ReadSignedWord(itemData + 0x68, 0x0)
						if weaponHeader >= numHeaders then
							weaponHeader = 0
						end
						headerType = IEex_ReadByte(itemData + 0x82 + weaponHeader * 0x38, 0x0)
						local itemFlags = IEex_ReadDword(itemData + 0x18)
						if headerType == 1 and bit.band(itemFlags, 0x2) > 0 then
							damageBonus = damageBonus - powerAttackCount
						end
					end
					weaponWrapper:free()
				end
			end
			line = string.gsub(line, "." .. "%d+", "+" .. damageBonus)
		elseif descPanelNum == 1 and (string.match(line, strengthString .. ":") or string.match(line, proficiencyString .. ":")) and ex_current_record_on_weapon_statistics then
			local strengthBonus = math.floor((IEex_GetActorStat(targetID, 36) - 10) / 2)
			local dexterityBonus = math.floor((IEex_GetActorStat(targetID, 40) - 10) / 2)
			if dexterityBonus > strengthBonus then
				local finesseBonus = math.floor(dexterityBonus / 2)
				local race = IEex_ReadByte(creatureData + 0x26, 0x0)
				local subrace = IEex_GetActorStat(targetID, 93)
				local hasWeaponFinesse = (bit.band(IEex_ReadDword(creatureData + 0x764), 0x80) > 0)
				if hasWeaponFinesse or (race == 5 and subrace == 0) then
					local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
					local weaponHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
					if ex_current_record_hand == 1 then
						local weaponRES = IEex_GetItemSlotRES(targetID, weaponSlot)
						local weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
						if weaponWrapper:isValid() then
							local itemData = weaponWrapper:getData()
							local itemType = IEex_ReadWord(itemData + 0x1C, 0x0)
							local numHeaders = IEex_ReadSignedWord(itemData + 0x68, 0x0)
							if weaponHeader >= numHeaders then
								weaponHeader = 0
							end
							local headerType = IEex_ReadByte(itemData + 0x82 + weaponHeader * 0x38, 0x0)
							local headerFlags = IEex_ReadDword(itemData + 0xA8 + weaponHeader * 0x38)
							if bit.band(IEex_ReadDword(itemData + 0x18), 0x2) > 0 then
								strengthBonus = math.floor(strengthBonus * 1.5)
							end
							local finesseDifference = finesseBonus - strengthBonus
							if bit.band(headerFlags, 0x1) > 0 then
								if finesseDifference > 0 and ((hasWeaponFinesse and ex_weapon_finesse_damage_bonus and (itemType == 16 or itemType == 19)) or (race == 5 and subrace == 0 and ex_lightfoot_halfling_thrown_dexterity_bonus_to_damage and headerType == 2 and itemType ~= 5 and itemType ~= 15 and itemType ~= 27 and itemType ~= 31) or ((race == 2 or race == 183) and ex_elf_large_sword_weapon_finesse and ex_weapon_finesse_damage_bonus and (itemType == 20))) then
									if string.match(line, strengthString .. ":") then
										line = string.gsub(line, "%p%d+", "+" .. finesseBonus)
										line = string.gsub(line, strengthString, dexterityString)
									elseif string.match(line, proficiencyString .. ":") then
										local proficiencyBonus = tonumber(string.match(line, "%d+"))
										if string.match(line, "%-") then
											proficiencyBonus = proficiencyBonus * -1
										end
										if strengthBonus == 0 then
											if proficiencyBonus == finesseDifference then
												line = string.gsub(line, proficiencyString, dexterityString)
											else
												line = string.gsub(line, proficiencyString, dexterityString .. "/" .. proficiencyString)
											end
										else
											proficiencyBonus = proficiencyBonus - finesseDifference
											if proficiencyBonus == 0 then
												IEex_RemoveEntryFromCPtrList(m_plstStrings, node)
											elseif proficiencyBonus > 0 then
												line = string.gsub(line, "%p%d+", "+" .. proficiencyBonus)
											else
												line = string.gsub(line, "%p%d+", proficiencyBonus)
											end
										end
									end
								end
							end
						end
						weaponWrapper:free()
					elseif ex_current_record_hand == 2 and hasWeaponFinesse and weaponSlot >= 43 and weaponSlot <= 49 then
						weaponSlot = weaponSlot + 1
						local offhandRES = IEex_GetItemSlotRES(targetID, weaponSlot)
						local offhandWrapper = IEex_DemandRes(offhandRES, "ITM")
						if offhandWrapper:isValid() then
							local itemData = offhandWrapper:getData()
							local itemType = IEex_ReadWord(itemData + 0x1C, 0x0)
							local numHeaders = IEex_ReadSignedWord(itemData + 0x68, 0x0)
							if numHeaders > 0 then
								local headerType = IEex_ReadByte(itemData + 0x82, 0x0)
								local headerFlags = IEex_ReadDword(itemData + 0xA8)
								if headerType == 1 and bit.band(headerFlags, 0x1) > 0 then
									local offhandStrengthBonus = math.floor(strengthBonus / 2)
									if offhandStrengthBonus == 0 and strengthBonus == 1 then
										offhandStrengthBonus = 1
									end
									local finesseDifference = finesseBonus - offhandStrengthBonus
									if finesseDifference > 0 and ex_weapon_finesse_damage_bonus and (itemType == 16 or itemType == 19 or ((race == 2 or race == 183) and ex_elf_large_sword_weapon_finesse and (itemType == 20))) then
										if string.match(line, strengthString .. ":") then
											line = string.gsub(line, "%p%d+", "+" .. finesseBonus)
											line = string.gsub(line, strengthString, dexterityString)
										elseif string.match(line, proficiencyString .. ":") then

											local proficiencyBonus = tonumber(string.match(line, "%d+"))
											if string.match(line, "%-") then
												proficiencyBonus = proficiencyBonus * -1
											end
											if strengthBonus == 0 then
												if proficiencyBonus == finesseDifference then
													line = string.gsub(line, proficiencyString, dexterityString)
												else
													line = string.gsub(line, proficiencyString, dexterityString .. "/" .. proficiencyString)
												end
											else
												proficiencyBonus = proficiencyBonus - finesseDifference
												if proficiencyBonus == 0 then
													IEex_RemoveEntryFromCPtrList(m_plstStrings, node)
												elseif proficiencyBonus > 0 then
													line = string.gsub(line, "%p%d+", "+" .. proficiencyBonus)
												else
													line = string.gsub(line, "%p%d+", proficiencyBonus)
												end
											end
										end
									end
								end
							end
						end
						offhandWrapper:free()
					end
				end
			end
		elseif string.match(line, damagePotentialString .. ":") then
			local damageBonus = IEex_ReadSignedWord(creatureData + 0x9A6, 0x0)
			local numbersProcessed = 0
			local minimumDamage = 0
			local maximumDamage = 0
			for w in string.gmatch(line, "%d+") do
				if numbersProcessed == 0 then
					minimumDamage = tonumber(w)
				elseif numbersProcessed == 1 then
					maximumDamage = tonumber(w)
				end
				numbersProcessed = numbersProcessed + 1
			end
			minimumDamage = minimumDamage + damageBonus
			maximumDamage = maximumDamage + damageBonus
			local luckBonus = IEex_ReadSignedWord(creatureData + 0x95C, 0x0)
			if IEex_GetActorSpellState(targetID, 64) then
				minimumDamage = maximumDamage
			elseif luckBonus > 0 then
				local minimumRoll = 1 + luckBonus
				if minimumRoll > ex_current_record_weapon_die_size then
					minimumRoll = ex_current_record_weapon_die_size
				end
				minimumDamage = minimumDamage + (minimumRoll - 1) * ex_current_record_weapon_die_number
			elseif luckBonus < 0 then
				local maximumRoll = ex_current_record_weapon_die_size + luckBonus
				if maximumRoll < 1 then
					maximumRoll = 1
				end
				maximumDamage = maximumDamage - (ex_current_record_weapon_die_size - maximumRoll) * ex_current_record_weapon_die_number
			end
			line = string.gsub(line, "%d+%-%d+", minimumDamage .. "-" .. maximumDamage)
		elseif string.match(line, criticalHitString .. ":") then
			local weaponRES = ""
			local weaponSlot = IEex_ReadByte(creatureData + 0x4BA4, 0x0)
			if ex_current_record_hand == 2 and weaponSlot >= 43 then
				weaponSlot = weaponSlot + 1
			end
			local itemType = 0
			local headerType = 0
			local currentHeader = IEex_ReadByte(creatureData + 0x4BA6, 0x0)
			local criticalMultiplier = 2
			local applyImprovedCritical = (bit.band(IEex_ReadDword(creatureData + 0x75C), 0x40000000) > 0 and ex_3e_improved_critical)
			local specificCriticalHitBonus = 0
			if ex_record_attack_stats_hidden_difference[targetID] ~= nil then
				specificCriticalHitBonus = specificCriticalHitBonus - ex_record_attack_stats_hidden_difference[targetID][2]
			end
			local slotData = IEex_ReadDword(creatureData + 0x4AD8 + weaponSlot * 0x4)
			if slotData > 0 and weaponSlot <= 50 then
				weaponRES = IEex_ReadLString(slotData + 0xC, 8)
			end
			local weaponWrapper = IEex_DemandRes(weaponRES, "ITM")
			if weaponWrapper:isValid() then
				local weaponData = weaponWrapper:getData()
				itemType = IEex_ReadWord(weaponData + 0x1C, 0x0)
				local equippedAppearance = IEex_ReadLString(weaponData + 0x22, 2)
				if applyImprovedCritical then
					if itemType == 20 and equippedAppearance == "SC" then
						specificCriticalHitBonus = specificCriticalHitBonus + 2
					elseif itemType == 16 or itemType == 19 or itemType == 20 or itemType == 57 or itemType == 69 then
						specificCriticalHitBonus = specificCriticalHitBonus + 1
					end
				end
				if ex_item_type_critical[itemType] ~= nil then
					criticalMultiplier = ex_item_type_critical[itemType][2]
				end
				if currentHeader >= IEex_ReadSignedWord(weaponData + 0x68, 0x0) then
					currentHeader = 0
				end
				headerType = IEex_ReadByte(weaponData + 0x82 + currentHeader * 0x38, 0x0)
				local effectOffset = IEex_ReadDword(weaponData + 0x6A)
				local numGlobalEffects = IEex_ReadWord(weaponData + 0x70, 0x0)
				for i = 0, numGlobalEffects - 1, 1 do
					local offset = weaponData + effectOffset + i * 0x30
					local theopcode = IEex_ReadWord(offset, 0x0)
					local theparameter1 = IEex_ReadDword(offset + 0x4)
					local theparameter2 = IEex_ReadDword(offset + 0x8)
					local theresource = IEex_ReadLString(offset + 0x14, 8)
					local thesavingthrow = IEex_ReadDword(offset + 0x24)
					if theopcode == 288 and theparameter2 == 195 and bit.band(thesavingthrow, 0x10000) > 0 then
						criticalMultiplier = criticalMultiplier + theparameter1
					elseif theopcode == 500 and theresource == "MECRIT" and bit.band(thesavingthrow, 0x100000) > 0 then
						specificCriticalHitBonus = specificCriticalHitBonus + theparameter1
					end
				end
			end
			local launcherRES = ""
			if weaponSlot >= 11 and weaponSlot <= 14 then
				IEex_IterateActorEffects(targetID, function(eData)
					local theopcode = IEex_ReadDword(eData + 0x10)
					local theparameter1 = IEex_ReadDword(eData + 0x1C)
					local theparameter2 = IEex_ReadDword(eData + 0x20)
					local thegeneralitemcategory = IEex_ReadByte(eData + 0x48, 0x0)
					if theopcode == 288 and theparameter2 == 241 and thegeneralitemcategory == 7 then
						launcherRES = IEex_ReadLString(eData + 0x94, 8)
					end
				end)
			end
			local launcherWrapper = IEex_DemandRes(launcherRES, "ITM")
			if launcherWrapper:isValid() then
				local launcherData = weaponWrapper:getData()
				local effectOffset = IEex_ReadDword(launcherData + 0x6A)
				local numGlobalEffects = IEex_ReadWord(launcherData + 0x70, 0x0)
				for i = 0, numGlobalEffects - 1, 1 do
					local offset = launcherData + effectOffset + i * 0x30
					local theopcode = IEex_ReadWord(offset, 0x0)
					local theparameter1 = IEex_ReadDword(offset + 0x4)
					local theparameter2 = IEex_ReadDword(offset + 0x8)
					local theresource = IEex_ReadLString(offset + 0x14, 8)
					local thesavingthrow = IEex_ReadDword(offset + 0x24)
					if theopcode == 288 and theparameter2 == 195 and bit.band(thesavingthrow, 0x10000) > 0 then
						criticalMultiplier = criticalMultiplier + theparameter1
					elseif theopcode == 500 and theresource == "MECRIT" and bit.band(thesavingthrow, 0x100000) > 0 then
						specificCriticalHitBonus = specificCriticalHitBonus + theparameter1
					end
				end
			end
			IEex_IterateActorEffects(targetID, function(eData)
				local theopcode = IEex_ReadDword(eData + 0x10)
				local theparameter1 = IEex_ReadDword(eData + 0x1C)
				local theparameter2 = IEex_ReadDword(eData + 0x20)
				local thesavingthrow = IEex_ReadDword(eData + 0x40)
				local thespecial = IEex_ReadDword(eData + 0x48)
				if theopcode == 288 and theparameter2 == 195 and bit.band(thesavingthrow, 0x10000) == 0 and (thespecial == -1 or thespecial == itemType) then
					criticalMultiplier = criticalMultiplier + theparameter1
				end
			end)
			line = string.gsub(line, "x%d+", "x" .. criticalMultiplier)
			local newLowestCriticalHitRoll = string.match(line, "%d+") - specificCriticalHitBonus
			if newLowestCriticalHitRoll < 1 then
				newLowestCriticalHitRoll = 1
			end
			line = string.gsub(line, "%d+%-", newLowestCriticalHitRoll .. "-")
		elseif hasDamageImmunity and descPanelNum == 0 then
			if string.match(line, bludgeoningString .. ":") then
				if damageImmunityList[0x0] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x0] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, acidString .. ":") then
				if damageImmunityList[0x1] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x1] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, coldString .. ":") then
				if damageImmunityList[0x2] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x2] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, electricityString .. ":") then
				if damageImmunityList[0x4] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x4] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, fireString .. ":") then
				if damageImmunityList[0x8] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x8] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, piercingString .. ":") then
				if damageImmunityList[0x10] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x10] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, poisonString .. ":") then
				if damageImmunityList[0x20] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x20] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, magicDamageString .. ":") then
				if damageImmunityList[0x40] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x40] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, missileString .. ":") then
				if damageImmunityList[0x80] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x80] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			elseif string.match(line, slashingString .. ":") then
				if damageImmunityList[0x100] == 1 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55601))
				elseif damageImmunityList[0x100] == 2 then
					line = string.gsub(line, "%d+", IEex_FetchString(ex_tra_55602))
				end
			end
		end
		-- do whatever changes you want to the line here
		IEex_CString_Set(lineEntry + 0x4, line)
	end)
	local bardLevel = IEex_ReadByte(creatureData + 0x628, 0x0)
	if bardLevel > 0 then
		local baseSpellSlots = {0, 0, 0, 0, 0, 0, 0, 0}
		for level, baseNumSlots in ipairs(baseSpellSlots) do
			baseNumSlots = tonumber(IEex_2DAGetAtStrings("MXSPLBRD", tostring(level), tostring(bardLevel)))
			if baseNumSlots > 0 then
				local spellListOffset = IEex_ReadDword(creatureData + 0x4288 + 0x1C * (level - 1))
				local spellListEnd = IEex_ReadDword(creatureData + 0x428C + 0x1C * (level - 1))
				while spellListOffset < spellListEnd do
					if IEex_ReadDword(spellListOffset + 0x8) > baseNumSlots then
						IEex_WriteDword(spellListOffset + 0x8, baseNumSlots)
					end
					spellListOffset = spellListOffset + 0x10
				end
			end
		end
	end
	local sorcererLevel = IEex_ReadByte(creatureData + 0x630, 0x0)
	if sorcererLevel > 0 then
		local baseSpellSlots = {0, 0, 0, 0, 0, 0, 0, 0, 0}
		for level, baseNumSlots in ipairs(baseSpellSlots) do
			baseNumSlots = tonumber(IEex_2DAGetAtStrings("MXSPLSOR", tostring(level), tostring(sorcererLevel)))
			if baseNumSlots > 0 then
				local spellListOffset = IEex_ReadDword(creatureData + 0x4788 + 0x1C * (level - 1))
				local spellListEnd = IEex_ReadDword(creatureData + 0x478C + 0x1C * (level - 1))
				while spellListOffset < spellListEnd do
					if IEex_ReadDword(spellListOffset + 0x8) > baseNumSlots then
						IEex_WriteDword(spellListOffset + 0x8, baseNumSlots)
					end
					spellListOffset = spellListOffset + 0x10
				end
			end
		end
	end
end
