
(function()

	-- HD UI master gate. INSTALL-time decision, NOT a player ini: the WeiDU "2K UI" component
	-- (2k_ui_resolution_gate.tpa) COPIES the 2x assets + pre-scaled CHU into override AND flips this
	-- flag false->true. The core ships it OFF (stock 1x UI, correct at any res). Push it to the helper
	-- so GetUICanvasScale (the GL canvas factor) tracks the install, not a togglable key. A runtime
	-- toggle can't work: a 2x CHU left in override renders oversized/broken when the canvas is 1x.
	local IEEX_HD_UI = false
	IEex_Helper_SetHDUI(IEEX_HD_UI and 1 or 0)

	-- Menu torch gate (install-time). The default menu art has the torch holder -> ON by default. The
	-- New-GUI component (DESIGNATED 37) has no torch in its menu art, so it flips this false. The torch
	-- only renders at HD-on anyway (GetUICanvasScale>1), so at <1200p / no-2K it stays off regardless.
	local IEEX_MENU_TORCH = true
	IEex_Helper_SetMenuTorch(IEEX_MENU_TORCH and 1 or 0)

	IEex_DisableCodeProtection()

	--------------------------------------------------------------------------------
	-- UI scaling (GRAND PROJECT "C", STAGE 1): bracket CUIManager::Render (0x4D4540)
	-- with a GL MODELVIEW scale so a full-screen UI engine (inventory, main menu,
	-- journal, area map, world map, record, store) fills the chosen resolution
	-- (letterboxed 4:3) instead of a small centred window in a black void. See
	-- IEexHelper Export_UIScaleRenderBegin / Export_UIScaleRenderEnd.
	--
	-- CUIManager::Render draws all panels of the active engine; UI panels go through
	-- the global glOrtho with MODELVIEW at identity, so scaling MODELVIEW between the
	-- two hooks scales the whole UI pass. Gated to non-world engines in the helper, so
	-- the in-world HUD (Stage 2) is untouched. Stateless glLoadIdentity, so an early
	-- return in CUIManager::Render can never imbalance the matrix stack. Orthogonal to
	-- camera zoom (which scales MODELVIEW around the world pass of the world engine).
	--
	--   entry 0x4D4540: SEH prologue; 7 displaced bytes
	--                   (6A FF               push 0xffffffff
	--                    68 28 48 81 00      push 0x814828)        -> continue 0x4D4547
	--   exit  0x4D45C3: single epilogue before ret @ 0x4D45D3; 5 displaced bytes
	--                   (8B 4C 24 14         mov ecx,[esp+0x14]
	--                    5F                  pop edi)              -> continue 0x4D45C8
	--------------------------------------------------------------------------------

	IEex_HookRestore(0x4D4540, 0, 7, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_UIScaleRenderBegin
		!pop_all_registers_iwd2
	]]})

	IEex_HookRestore(0x4D45C3, 0, 5, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_UIScaleRenderEndUI
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- SYSTEMIC hit-test fix (input core). Transform the cursor to UI-LOGICAL at the ONE
	-- capture source -- CChitin::AsynchronousUpdate -- so the stored m_ptPointer AND the pt
	-- dispatched to the engine's On*(pt) handlers are logical whenever the cursor is over
	-- scaled UI. Every downstream hit-test (the CUIManager handlers, CScreenWorld
	-- portrait-pick @0x68C3D0, button dispatch, GetWorldCoordinates rejection, the wheel
	-- gate) then reads correct coords with NO per-site map. World picking/move stays
	-- physical: the helper only logical-ises in the world when the candidate is over a HUD
	-- panel. This REPLACES the old per-site fixes (the 6 CUIManager MapPoint hooks that were
	-- here, and the Stage-2 map inside IEex_IsUIBlockingViewport).
	--
	-- Hook 0x78F489: the m_bFullscreen branch of AsynchronousUpdate, after ScreenToClient
	-- (@0x78F41F) and the m_bPointerInside edge block, BEFORE the pt==m_ptPointer compare /
	-- store (@0x78F4E2) / dispatch. pt is the on-stack client CPoint at [esp+0x1C]/[esp+0x20];
	-- pass &pt and rewrite it in place. 10 displaced bytes
	--   8B 4C 24 1C          mov ecx,[esp+0x1C]
	--   8B 86 06 19 00 00     mov eax,[esi+0x1906]
	-- re-run after the call, now reading the transformed value. Our deploy is always
	-- borderless-fullscreen at native res (m_bFullscreen=TRUE -> only this branch executes);
	-- a windowed mode would need a second hook in the PtInRect branch. See
	-- IEexHelper Export_UIScaleCaptureMap.
	--------------------------------------------------------------------------------
	IEex_HookRestore(0x78F489, 0, 10, {[[
		!mark_esp
		!push_all_registers_iwd2
		!marked_esp !lea(eax,[esp+1C]) !push_eax
		!call >IEex_Helper_UIScaleCaptureMap
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- Cursor sizing: m_ptPointer stays physical, so the cursor already tracks the real
	-- mouse at the correct speed and stays screen-clamped. Native size is too small at
	-- 1440p/4K, so bracket CVidInf::RenderPointer3d (0x7BE300) with a scale ABOUT THE
	-- CURSOR HOTSPOT (Export_UIScaleCursorBegin): the cursor / dragged item grows in
	-- place at the physical mouse without moving. Resetting MODELVIEW at the epilogue is
	-- mandatory: a non-zoomed world frame would otherwise inherit the leftover scale.
	--   entry 0x7BE300: SEH prologue; 7 bytes (6A FF 68 30 5B 84 00) -> 0x7BE307
	--   exit  0x7BE4C1: single epilogue; 10 bytes (5F 5E 5D 64 89 0D 00 00 00 00)
	--                   (pop edi/esi/ebp; mov fs:[0],ecx) -> continue 0x7BE4CB
	--------------------------------------------------------------------------------
	IEex_HookRestore(0x7BE300, 0, 7, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_UIScaleCursorBegin
		!pop_all_registers_iwd2
	]]})
	IEex_HookRestore(0x7BE4C1, 0, 10, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_UIScaleRenderEnd
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- GL FONT ATLAS FIX (opengl-only): CVidFont::LoadGlyphs @0x7A0B20 bakes glyphs into 256x256 atlas
	-- textures, row pitch = node->m_nFontHeight. That pitch is 1px short of the font's true extent
	-- (maxAscent + maxDescent), so the glyph packed ABOVE bleeds its bottom 1px row into the next
	-- glyph's atlas cell-top -> a thin dash atop short letters (o/i/u). (Software renderer blits glyphs
	-- directly = no atlas = no bleed, which is why feature/ui-2x-scaling was clean.) FIX: widen the
	-- atlas row pitch by +2 -- but ONLY the loop's working copy at [esp+0x14], NOT node->m_nFontHeight,
	-- so rendered line-spacing is untouched. Replace the pitch load with load+ADD2, then jump straight
	-- to the store (the auto-restored displaced bytes after our jmp are dead, avoiding a re-load).
	--   0x7A0D0F  8B 46 44     mov eax,[esi+0x44]   (m_nFontHeight)
	--   0x7A0D12  33 FF        xor edi,edi
	--   0x7A0D14  89 44 24 14  mov [esp+0x14],eax   (loop pitch copy; read at 0x7A0DBF for y-advance)
	-- Harmless under the software renderer (LoadGlyphs @0x7A0B20 is the GL-only bake, never reached).
	--------------------------------------------------------------------------------
	IEex_HookRestore(0x7A0D0F, 0, 5, {[[
		8B 46 44
		83 C0 02
		33 FF
		!jmp_dword :7A0D14
	]]})

	--------------------------------------------------------------------------------
	-- 3.6x canvas: the main-menu torch (CScreenConnection::RenderTorch @0x5FB020) uses a
	-- HARDCODED 1x offset CPoint pt(106,383), only doubled for the 2x new-GUI tier. Under the
	-- 3.6x pre-scaled-CHU canvas (1x mode, newGui=0) it stays 1x -> wrong spot. Scale the 1x
	-- immediates to x3.6 (106->382, 383->1379). The torch then renders in the panels' scaled
	-- space because Export_UIScaleRenderEndUI leaves the MODELVIEW set through the overlay pass
	-- (no RenderTorch hook). Gated on "UI Canvas Scale" > 1 so stock/2x-tier are untouched; the
	-- torch offset is scaled by the same factor (106*f, 383*f).
	--   0x5FB0AF  BF 6A 00 00 00   mov edi,106 (pt.x) -> imm@0x5FB0B0 = 382  (0x17E)
	--   0x5FB0B4  BE 7F 01 00 00   mov esi,383 (pt.y) -> imm@0x5FB0B5 = 1379 (0x563)
	--------------------------------------------------------------------------------
	local canvas = IEEX_HD_UI and 2.0 or 1.0
	IEex_DisableCodeProtection()
	if canvas > 1.0 then
		local f = canvas   -- HD UI = the shipped 2x tier (factor 2.0)
		IEex_WriteDword(0x5FB0B0, math.floor(106 * f + 0.5))   -- pt.x = round(106*factor)
		IEex_WriteDword(0x5FB0B5, math.floor(383 * f + 0.5))   -- pt.y = round(383*factor)
	end
	-- The torch renders AFTER pVidMode->Flip(TRUE), so MODELVIEW was reset to identity -> it would land
	-- at raw screen coords. Hook RenderTorch entry (0x5FB020) ALWAYS (not only canvas>1): when HD UI is
	-- ON, the helper re-applies the Stage-1 transform + we re-render pre-Flip (crisp 2x torch). When HD
	-- UI is OFF (<1200p / vanilla tier), the helper NEUTRALISES the engine's torch -- otherwise the
	-- shipped 2x MMTRCHB asset would render at native size = 2x too big. So the torch shows ONLY at HD-on
	-- (+ New-GUI off, see g_menuTorchEnabled); off at HD-off. 5 displaced bytes: A1 DC F6 8C 00. MUST be
	-- before EnableCodeProtection (HookRestore writes a jmp into .text).
	IEex_HookRestore(0x5FB020, 0, 5, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_UIScaleTorchBegin
		!pop_all_registers_iwd2
	]]})
	IEex_EnableCodeProtection()

	-- TEMP TEST (remove after torch testing): force the NIGHT menu (STARTN + torch) regardless of
	-- the system clock. CScreenConnection::UpdateMainPanel @0x5FEE50 picks day (START) for hour
	-- 7..17 via `jle 0x5FEF2E` @0x5FEEBF (the else branch sets STARTN + m_bIsNight=TRUE). Flip the
	-- conditional jump to an unconditional jmp so the night branch always runs.
	IEex_DisableCodeProtection()
	IEex_WriteByte(0x5FEEBF, 0xEB)   -- 0x7E (jle) -> 0xEB (jmp 0x5FEF2E = always night)
	IEex_EnableCodeProtection()

end)()
