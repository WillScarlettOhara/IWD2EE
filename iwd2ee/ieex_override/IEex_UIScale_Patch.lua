
(function()

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
		!call >IEex_Helper_UIScaleRenderEnd
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- STAGE 1b hit-test: align mouse input with the scaled UI WITHOUT touching the
	-- cursor. The full-screen screens delegate every mouse event to their CUIManager
	-- (CScreenInventory::OnLButtonDown -> m_cUIManager.OnLButtonDown(pt), etc), so the
	-- CUIManager mouse handlers are the single hit-test chokepoint. Each is
	-- __thiscall(CPoint pt) (ret 8), so pt is on the stack at [entry_esp+4]; map it
	-- physical->logical there. m_ptPointer is left physical, so the cursor sprite keeps
	-- tracking the real mouse (handled separately below). Gated to non-world engines in
	-- the helper, so the world screen's HUD handlers are untouched.
	--   0x4D40B0 OnMouseMove      5B (83 EC 10 53 55)
	--   0x4D41D0 OnLButtonDown    5B (83 EC 10 53 55)
	--   0x4D42B0 OnLButtonUp      6B (56 8B F1 8B 4E 14)
	--   0x4D4310 OnLButtonDblClk  6B (8B 41 04 83 EC 10)
	--   0x4D43D0 OnRButtonDown    5B (83 EC 10 53 55)
	--   0x4D44B0 OnRButtonUp      6B (56 8B F1 8B 4E 14)
	--------------------------------------------------------------------------------

	local mapPointAsm = {[[
		!mark_esp
		!push_all_registers_iwd2
		!marked_esp !lea(eax,[esp+4]) !push_eax
		!call >IEex_Helper_UIScaleMapPoint
		!pop_all_registers_iwd2
	]]}

	IEex_HookRestore(0x4D40B0, 0, 5, mapPointAsm)
	IEex_HookRestore(0x4D41D0, 0, 5, mapPointAsm)
	IEex_HookRestore(0x4D42B0, 0, 6, mapPointAsm)
	IEex_HookRestore(0x4D4310, 0, 6, mapPointAsm)
	IEex_HookRestore(0x4D43D0, 0, 5, mapPointAsm)
	IEex_HookRestore(0x4D44B0, 0, 6, mapPointAsm)

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

end)()
