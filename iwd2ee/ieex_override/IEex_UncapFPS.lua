
IEex_UncapFPS_Enabled = true

if not IEex_UncapFPS_Enabled then
	return
end

---------------
-- Scrolling --
---------------

IEex_Helper_InitBridgeFromTable("IEex_Scroll_MiddleMouseState", {
	["isDown"] = false,
	["oldX"] = 0,
	["oldY"] = 0,
})

IEex_Scroll_DefaultKeys = {
	IEex_KeyIDS.UP,    IEex_KeyIDS.NUMPAD8, -- m_nKeyScrollState = 1
					   IEex_KeyIDS.NUMPAD9, -- m_nKeyScrollState = 2
	IEex_KeyIDS.RIGHT, IEex_KeyIDS.NUMPAD6, -- m_nKeyScrollState = 3
					   IEex_KeyIDS.NUMPAD3, -- m_nKeyScrollState = 4
	IEex_KeyIDS.DOWN,  IEex_KeyIDS.NUMPAD2, -- m_nKeyScrollState = 5
					   IEex_KeyIDS.NUMPAD1, -- m_nKeyScrollState = 6
	IEex_KeyIDS.LEFT,  IEex_KeyIDS.NUMPAD4, -- m_nKeyScrollState = 7
					   IEex_KeyIDS.NUMPAD7, -- m_nKeyScrollState = 8
}

function IEex_Scroll_ResolveScrollState()
	local state = 0
	for _, key in ipairs(IEex_GetPressedKeysStack()) do
		local customMapIndex = IEex_Hotkeys_GetBoundCustomMapIndex(key)
		if IEex_Hotkeys_IsScrollUp(customMapIndex) then
			if state == 3 or state == 4 then     -- RIGHT / BOTTOM-RIGHT
				state = 2                        -- => TOP-RIGHT
			elseif state == 6 or state == 7 then -- BOTTOM-LEFT / LEFT
				state = 8                        -- => TOP-LEFT
			else
				state = 1                        -- => UP
			end
		elseif IEex_Hotkeys_IsScrollTopRight(customMapIndex) then
			state = 2                            -- => TOP-RIGHT
		elseif IEex_Hotkeys_IsScrollRight(customMapIndex) then
			if state == 1 or state == 8 then     -- UP / TOP-LEFT
				state = 2                        -- => TOP-RIGHT
			elseif state == 5 or state == 6 then -- DOWN / BOTTOM-LEFT
				state = 4                        -- => BOTTOM-RIGHT
			else
				state = 3                        -- => RIGHT
			end
		elseif IEex_Hotkeys_IsScrollBottomRight(customMapIndex) then
			state = 4                            -- => BOTTOM-RIGHT
		elseif IEex_Hotkeys_IsScrollDown(customMapIndex) then
			if state == 2 or state == 3 then     -- TOP-RIGHT / RIGHT
				state = 4                        -- => BOTTOM-RIGHT
			elseif state == 7 or state == 8 then -- LEFT / TOP-LEFT
				state = 6                        -- => BOTTOM-LEFT
			else
				state = 5                        -- => DOWN
			end
		elseif IEex_Hotkeys_IsScrollBottomLeft(customMapIndex) then
			state = 6                            -- => BOTTOM-LEFT
		elseif IEex_Hotkeys_IsScrollLeft(customMapIndex) then
			if state == 1 or state == 2 then     -- UP / TOP-RIGHT
				state = 8                        -- => TOP-LEFT
			elseif state == 4 or state == 5 then -- BOTTOM-RIGHT / DOWN
				state = 6                        -- => BOTTOM-LEFT
			else
				state = 7                        -- => LEFT
			end
		elseif IEex_Hotkeys_IsScrollTopLeft(customMapIndex) then
			state = 8                            -- => TOP-LEFT
		end
	end
	return state
end

IEex_Scroll_CheckScheduled = false

function IEex_Scroll_CheckKeyboardInput()
	if IEex_GetActiveEngine() == IEex_GetEngineWorld() then
		local pVisibleArea = IEex_GetVisibleArea()
		if pVisibleArea ~= 0x0 and IEex_IsWorldScreenAcceptingInput() and not IEex_IsGameAutoScrolling() then
			IEex_WriteDword(pVisibleArea + 0x23C, IEex_Scroll_ResolveScrollState())
			IEex_Scroll_CheckScheduled = false
			return
		end
	end
	IEex_Scroll_CheckScheduled = true
end

function IEex_Scroll_CalculateDeltaFactor()
	local toReturn = 1
	IEex_Helper_StoreMicroseconds("curTick")
	if IEex_Helper_ExistsMicroseconds("lastTick") then
		local diff = IEex_Helper_GetMicrosecondsDiff("curTick", "lastTick")
		toReturn = diff / 25000
	end
	IEex_Helper_AssignMicroseconds("lastTick", "curTick")
	return toReturn
end

function IEex_Scroll_AdjustViewPositionFromScrollState(scrollState, delta)
	if scrollState == 6 or scrollState == 7 or scrollState == 8 then
		IEex_AdjustViewPosition(-delta, 0)
	end
	if scrollState == 2 or scrollState == 3 or scrollState == 4 then
		IEex_AdjustViewPosition(delta, 0)
	end
	if scrollState == 1 or scrollState == 2 or scrollState == 8 then
		IEex_AdjustViewPosition(0, -delta)
	end
	if scrollState == 4 or scrollState == 5 or scrollState == 6 then
		IEex_AdjustViewPosition(0, delta)
	end
end

-- Middle-drag pan cursor: the fill-remapped PHYSICAL cursor, NOT the capture-mapped m_ptPointer.
-- m_ptPointer is HUD-logical-ised over the scaled world-HUD (the inflated bottom band), so its
-- frame-to-frame delta spikes the moment the cursor crosses that band -> camera teleport at
-- sub-4K (the refonte reference-width layout, s<1). The DLL helper hands back a consistent
-- physical position (and keeps the sub-native fill remap). Falls back to the raw capture-mapped
-- cursor on an older DLL that lacks the export.
function IEex_Scroll_GetPanCursor()
	if IEex_Helper_GetCursorPhysicalXY then
		return IEex_Helper_GetCursorPhysicalXY()
	end
	return IEex_GetCursorXY()
end

---------------
-- Listeners --
---------------

function IEex_Scroll_KeyPressedListener(key)

	if key == IEex_KeyIDS.MIDDLE_MOUSE_CLICK then
		IEex_Helper_SynchronizedBridgeOperation("IEex_Scroll_MiddleMouseState", function()
			IEex_Helper_SetBridgeNL("IEex_Scroll_MiddleMouseState", "isDown", true)
			local oldX, oldY = IEex_Scroll_GetPanCursor()
			IEex_Helper_SetBridgeNL("IEex_Scroll_MiddleMouseState", "oldX", oldX)
			IEex_Helper_SetBridgeNL("IEex_Scroll_MiddleMouseState", "oldY", oldY)
		end)
	end

	IEex_Scroll_CheckKeyboardInput()
end

function IEex_Scroll_KeyReleasedListener(key)

	if key == IEex_KeyIDS.MIDDLE_MOUSE_CLICK then
		IEex_Helper_SetBridge("IEex_Scroll_MiddleMouseState", "isDown", false)
	end

	IEex_Scroll_CheckKeyboardInput()
end

function IEex_Scroll_InputStateListener()
	if IEex_Scroll_CheckScheduled then
		IEex_Scroll_CheckKeyboardInput()
	end
end

-- Suppress default scroll key handling
function IEex_Scroll_RejectHardcodedWorldScreenKeybindingListener(key)
	return IEex_FindInTable(IEex_Scroll_DefaultKeys, key)
end

function IEex_Scroll_RegisterListeners()
	IEex_AddKeyPressedListener("IEex_Scroll_KeyPressedListener")
	IEex_AddKeyReleasedListener("IEex_Scroll_KeyReleasedListener")
	IEex_AddInputStateListener("IEex_Scroll_InputStateListener")
	IEex_AddRejectHardcodedWorldScreenKeybindingListener("IEex_Scroll_RejectHardcodedWorldScreenKeybindingListener")
end

function IEex_Scroll_ReloadListener()
	IEex_Scroll_RegisterListeners()
	IEex_ReaddReloadListener("IEex_Scroll_ReloadListener")
end

IEex_AbsoluteOnce("IEex_Scroll_InitListeners", function()
	IEex_Scroll_RegisterListeners()
	IEex_AddReloadListener("IEex_Scroll_ReloadListener")
end)

-----------
-- Hooks --
-----------

------------------
-- Thread: Both --
------------------

function IEex_Extern_CheckScroll()

	IEex_AssertThread(IEex_Thread.Both, true)

	if IEex_Helper_GetBridge("IEex_Helper_SupressScrollCheck", "value") then
		return
	end

	IEex_Helper_SynchronizedBridgeOperation("IEex_Scroll_MiddleMouseState", function()

		if IEex_Helper_GetBridgeNL("IEex_Scroll_MiddleMouseState", "isDown") then

			-- SAME coordinate space as the anchor (set from IEex_GetCursorXY at MMB-down):
			-- m_ptPointer is capture-mapped (sub-native fill remap + logical-over-scaled-HUD).
			-- Raw ScreenToClient(GetCursorPos()) is desktop-px -- at sub-native res with the
			-- fill blit (e.g. 1080p on a 4K desktop) the first delta was anchor(game-res) vs
			-- cursor(desktop-px) = a huge jump (camera teleport on middle-click).
			local cursorX, cursorY = IEex_Scroll_GetPanCursor()
			local deltaX = IEex_Helper_GetBridgeNL("IEex_Scroll_MiddleMouseState", "oldX") - cursorX
			local deltaY = IEex_Helper_GetBridgeNL("IEex_Scroll_MiddleMouseState", "oldY") - cursorY

			-- Zoom-correct the pan: the cursor delta is in SCREEN pixels but the view moves in WORLD
			-- pixels, and the GL camera zoom magnifies the world on screen (1 world px = zoom screen px).
			-- Divide by the zoom so the grabbed map point stays under the cursor (true grab-drag) instead
			-- of the world sliding at a different speed than the cursor. No-op at zoom 1.0.
			local zoom = IEex_Helper_GetCameraZoom and IEex_Helper_GetCameraZoom() or 1
			if zoom and zoom > 0 then
				deltaX = deltaX / zoom
				deltaY = deltaY / zoom
			end

			if IEex_IsWorldScreenAcceptingInput() and not IEex_IsGameAutoScrolling() then
				IEex_AdjustViewPosition(deltaX, deltaY)
			end

			IEex_Helper_SetBridgeNL("IEex_Scroll_MiddleMouseState", "oldX", cursorX)
			IEex_Helper_SetBridgeNL("IEex_Scroll_MiddleMouseState", "oldY", cursorY)
		end
	end)

	local visibleArea = IEex_GetVisibleArea()
	if visibleArea ~= 0x0 then

		local deltaFactor = IEex_Scroll_CalculateDeltaFactor()

		if not IEex_Helper_GetBridgeNL("IEex_Scroll_MiddleMouseState", "isDown") then

			local m_nScrollState = IEex_ReadDword(visibleArea + 0x238)
			local m_nKeyScrollState = IEex_ReadDword(visibleArea + 0x23C)

			local gameData = IEex_GetGameData()
			local scrollSpeed = IEex_ReadDword(gameData + 0x43F2)
			local keyboardScrollSpeed = IEex_ReadDword(gameData + 0x443E) / 3

			IEex_Scroll_AdjustViewPositionFromScrollState(m_nScrollState, scrollSpeed * deltaFactor)
			IEex_Scroll_AdjustViewPositionFromScrollState(m_nKeyScrollState, keyboardScrollSpeed * deltaFactor)
		end
	end
end
