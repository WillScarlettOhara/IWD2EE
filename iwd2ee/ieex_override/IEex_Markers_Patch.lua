
(function()

	IEex_DisableCodeProtection()

	--------------------------------------------------------------------------------
	-- Per-character selection-marker colour.
	--
	-- CMarker::AsynchronousUpdate (0x766900) decides the marker colour from the
	-- sprite's allegiance, and CGameSprite::AsynchronousUpdate calls it once for the
	-- selection circle (m_marker) and once for the move-destination reticle
	-- (m_destMarker) -- so this single hook colours both.
	--
	-- The hook sits at the BRANCH JOIN (0x766C06): every colour branch has already
	-- stored its result into m_rgbColor ([esi+6]) and the picked/hover pulse ramp
	-- (0x766C43) has not run yet. The helper therefore sees the final BASE colour,
	-- substitutes the character's own clothing colour when it recognises one of the
	-- two controlled-PC greens (red and blue both zero -- talking white, morale
	-- yellow, enemy red and neutral cyan fail that test and are left alone), and the
	-- engine then animates whatever we left there, for free.
	--   esi = CMarker*, edi = CGameSprite*.
	--   Displaced 6 bytes @0x766C06:
	--     8B 87 2A 71 00 00   mov eax,[edi+0x712A]  (m_talkingCounter) -> resume 0x766C0C
	--
	-- Deliberately NOT renderer-gated: a colour decision costs nothing under the
	-- software renderer either. Only the stroke THICKNESS is OpenGL-only, and that
	-- lives in the DrawEllipse3d / DrawRecticle3d overrides installed by
	-- IEex_CameraZoom_Patch.lua.
	--
	-- Player settings, [IEex Options] in Icewind2.ini (read by IEexHelper, lazily):
	--   Colored Selection Circles       0 = vanilla green (default), 1 = tinted (options menu row)
	--   Selection Circle Thickness      0 = auto (2px, or 3px above 1920 wide), 1-4 = forced
	--   Colored Portrait Frames         0 = vanilla green portrait frames (default), 1 = tinted
	--                                   (options menu row; needs the World HUD Refonte)
	--   Portrait Frame Thickness        0 = follow Selection Circle Thickness (default), 1-4 = forced
	--   Selection Circle Color Slot     0 metal, 1 minor cloth (default), 2 major, 3 skin, ...
	--   Selection Circle Min Brightness legibility floor for dark clothing (default 110)
	--------------------------------------------------------------------------------
	IEex_HookRestore(0x766C06, 0, 6, {[[
		!push_all_registers_iwd2
		!push_edi
		!push_esi
		!call >IEex_Helper_MarkerTintPC
		!pop_all_registers_iwd2
	]]})

end)()
