
(function()

	IEex_DisableCodeProtection()

	-- Software-renderer opt-out (stock ini key [Program Options] "3D Acceleration" = 0): camera zoom is
	-- a GL MODELVIEW feature; install none of it under the software renderer. See IEex_Render_Patch.lua.
	-- Default 1 = GL on (current behaviour, unchanged).
	if IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") == 0 then
		return
	end

	--------------------------------------------------------------------------------
	-- Camera zoom (STAGE 1, zoom-in): bracket CGameArea::Render (0x477740) with a
	-- GL MODELVIEW scale around the viewport centre. See IEexHelper
	-- Export_ZoomWorldBegin / Export_ZoomWorldEnd.
	--
	-- CGameArea::Render draws the world viewport (tiles + sorted sprites + FoW +
	-- selection highlight); UI panels draw AFTER it with MODELVIEW back at identity.
	-- Scaling MODELVIEW between the two hooks scales the world only. The helper uses
	-- glLoadIdentity (stateless) so the engine's m_bAreaLoaded early-return can never
	-- imbalance the matrix stack.
	--
	--   entry 0x477740: this=ecx=CGameArea*; 8 displaced bytes
	--                   (83 EC 14            sub esp,0x14
	--                    A1 DC F6 8C 00      mov eax,ds:0x8CF6DC) -> continue 0x477748
	--   exit  0x477E55: epilogue before ret 0x8 @ 0x477E5C; 7 displaced bytes
	--                   (5F 5D 5B 5E         pop edi/ebp/ebx/esi
	--                    83 C4 14            add esp,0x14)         -> continue 0x477E5C
	--------------------------------------------------------------------------------

	-- Entry: pass CGameArea* (ecx) to begin.
	IEex_HookRestore(0x477740, 0, 8, {[[
		!push_all_registers_iwd2
		!push_ecx
		!call >IEex_Helper_ZoomWorldBegin
		!pop_all_registers_iwd2
	]]})

	-- Exit: reset MODELVIEW to identity.
	IEex_HookRestore(0x477E55, 0, 7, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_ZoomWorldEnd
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- STAGE 2: replace CInfinity::GetWorldCoordinates (0x5CDFC0) with a zoom-aware
	-- reimplementation so mouse picking / selection / move-orders align when zoomed.
	-- Direct jmp: __thiscall struct-return matches native ABI (ecx=this, stack=
	-- [sret][ptScreen], ret 0x8). Original body becomes dead (never executed).
	--------------------------------------------------------------------------------
	IEex_WriteAssembly(0x5CDFC0, {[[
		!jmp_dword >IEex_Helper_CInfinity_GetWorldCoordinatesOverride
	]]})

	--------------------------------------------------------------------------------
	-- STAGE 2b: zoom-aware band-select growth. CGameArea::OnMouseMove (0x476970)
	-- grows m_selectSquare.right/bottom with INLINE screen+scroll arithmetic
	-- (vanilla 1:1 world transform), while the anchor (OnActionButtonDown) goes
	-- through the zoom-aware GetWorldCoordinates override above -> at z>1 the two
	-- edges live in different spaces and the rect gains phantom size
	-- ((dist from viewport centre)*(1-1/z)): OnActionButtonUp's "<=8px = click"
	-- test misreads a plain move click as a band-select (spurious selection
	-- rectangle), and a real band-drag selects a region that doesn't match the
	-- visual rect. Route both growth sites through Export_BandSelectGrow
	-- (identical to the vanilla arithmetic at z==1).
	--   Site 1 @0x476C02..0x476C77 (group-protect/state-3 growth) -> resume 0x476DD6.
	--   Site 2 @0x476C94..0x476D0C (normal growth); the width test that follows
	--   expects edi=right, ebp=left (still live from 0x476C7C), eax=bottom and
	--   ecx/flags = right-left -> recreate them, resume at the jns @0x476D12.
	-- esi = CGameArea*, ebx = CPoint* pt at both sites; no external jumps enter
	-- the replaced ranges (the 0x476DD6 tail reloads ebx from the stack itself).
	--------------------------------------------------------------------------------
	IEex_WriteAssembly(0x476C02, {[[
		!push_all_registers_iwd2
		53
		56
		!call >IEex_Helper_BandSelectGrow
		!pop_all_registers_iwd2
		!jmp_dword :476DD6
	]]})
	IEex_WriteAssembly(0x476C94, {[[
		!push_all_registers_iwd2
		53
		56
		!call >IEex_Helper_BandSelectGrow
		!pop_all_registers_iwd2
		8B BE E4 03 00 00
		8B 86 E8 03 00 00
		8B CF
		2B CD
		!jmp_dword :476D12
	]]})

	--------------------------------------------------------------------------------
	-- STAGE 3a: replace CInfinity::SetViewPosition (0x5D11F0) with an overscroll-
	-- aware reimplementation. When zoomed, allow panning past the map edges (~half
	-- the viewport) so content the bottom UI would occlude can be repositioned;
	-- byte-faithful vanilla clamp at z==1. __thiscall(int,int,uint), ret 0xC.
	--------------------------------------------------------------------------------
	IEex_WriteAssembly(0x5D11F0, {[[
		!jmp_dword >IEex_Helper_CInfinity_SetViewPositionOverride
	]]})

	--------------------------------------------------------------------------------
	-- Crisp circles: replace CVidMode::DrawEllipse3d (0x7BC580) with a zoom-aware
	-- reimplementation. The engine plots selection / move-dest circles as GL_POINTS
	-- at glPointSize(1.0) (px size immune to the MODELVIEW scale -> sparse dots when
	-- zoomed). When the world zoom is active, scale centre+axes by z and rasterise at
	-- identity MODELVIEW for a solid, crisp circle. __thiscall(...), ret 0x10.
	--------------------------------------------------------------------------------
	IEex_WriteAssembly(0x7BC580, {[[
		!jmp_dword >IEex_Helper_CVidMode_DrawEllipse3dOverride
	]]})

	-- Crisp chevrons: replace CVidMode::DrawRecticle3d (0x7BC7A0) — the move-dest /
	-- formation reticle's arc segments are the same GL_POINTS as the circles.
	IEex_WriteAssembly(0x7BC7A0, {[[
		!jmp_dword >IEex_Helper_CVidMode_DrawRecticle3dOverride
	]]})

	--------------------------------------------------------------------------------
	-- Wheel gate (don't scroll the log when zooming the world). CBaldurEngine::
	-- OnMouseWheel (0x4289C0) scrolls the message-log scrollbar on every wheel notch.
	-- When the cursor is over the world (Export_WheelShouldZoom => world screen + GL +
	-- not over a UI panel) we skip the original entirely (ret 0x10) so only the zoom
	-- happens; otherwise the original runs (log scrolls when the cursor is over it).
	-- The zoom tick itself is recorded in window_proc, gated by the same predicate.
	-- Displaced 6 bytes @0x4289C0: 56 57 8B 7C 24 14 (push esi; push edi; mov edi,
	-- [esp+0x14]) -> continue at 0x4289C6.
	--------------------------------------------------------------------------------
	local wheelHook = IEex_WriteAssemblyAuto({[[
		!push_all_registers_iwd2
		!call >IEex_Helper_WheelShouldZoom
		85 C0
		!jz_dword >continue
		!pop_all_registers_iwd2
		!ret_word 10 00
		@continue
		!pop_all_registers_iwd2
		56 57 8B 7C 24 14
		!jmp_dword :4289C6
	]]})
	IEex_WriteAssembly(0x4289C0, IEex_FlattenTable({
		{[[ !jmp_dword ]], {wheelHook, 4, 4}},
		{[[ 90 ]]},
	}))

	--------------------------------------------------------------------------------
	-- Area Map screen: make the green "you are here" rect follow the world zoom, and
	-- let the wheel change the zoom (hence the rect size) from the map itself.
	--
	-- (1) Draw-time inset. CUIControlButtonMapAreaMap::RenderViewRect (0x644B00,
	--     __thiscall(CVidInf*, const CRect& a2, const CRect& a3)) draws the rect from
	--     a3 = field_72A = the UNZOOMED viewport ((nNewX,nNewY)+rViewPort). Under the GL
	--     zoom that is far too big (fills the map at 4K). Export_MapViewRectZoom insets
	--     the DRAWN rect to rViewPort/zoom around its centre by repointing the on-stack
	--     &a3 slot at a static copy; field_72A itself is untouched so the click-to-
	--     recentre / clamp / SetViewPosition math on this screen stays vanilla.
	--       At entry esp: [esp+0xC] = &a3. lea eax,[esp+0xC] BEFORE the push_all so eax
	--       is the absolute slot address (push_all preserves it); pass it to the helper.
	--       Displaced 5 bytes @0x644B00: 83 EC 24 (sub esp,0x24) 53 (push ebx) 55 (push
	--       ebp) -> continue 0x644B05.
	IEex_HookRestore(0x644B00, 0, 5, {[[
		8D 44 24 0C
		!push_all_registers_iwd2
		!push(eax)
		!call >IEex_Helper_MapViewRectZoom
		!pop_all_registers_iwd2
	]]})

	-- (2) Wheel pump. window_proc already records wheel ticks on this screen (the
	--     Export_WheelShouldZoom gate now passes the map engine). Drain them per async
	--     tick into g_fZoomTarget and repaint. Hook the control's TimerAsynchronousUpdate
	--     (0x645100, __thiscall(BOOLEAN)); ecx = the control (this).
	--       Displaced 5 bytes @0x645100: 83 EC 0C (sub esp,0xC) 53 (push ebx) 56 (push
	--       esi) -> continue 0x645105.
	IEex_HookRestore(0x645100, 0, 5, {[[
		!push_all_registers_iwd2
		!push_ecx
		!call >IEex_Helper_MapWheelPump
		!pop_all_registers_iwd2
	]]})

	-- (3) Movable rect. CUIControlButtonMapAreaMap::CenterViewPort (0x6437A0) PRE-clamps the new
	--     scroll to the UNZOOMED viewport range [0, nArea - rViewPort] before SetViewPosition, so
	--     a zoomed-in view can only pan the unzoomed range -- the small rect "moves as if not
	--     zoomed" and never reaches the map edges. Replace it with Export_MapCenterViewPort, which
	--     passes the raw point to SetViewPosition (0x5D11F0 = the zoom-aware overscroll override,
	--     installed above) and reloads the clamped nNewX/nNewY into field_72A. __thiscall(const
	--     CPoint& pt), ret 4; marshal to __stdcall(this, &pt): at entry [esp+4] = &pt.
	local centerStub = IEex_WriteAssemblyAuto({[[
		FF 74 24 04
		!push_ecx
		!call >IEex_Helper_MapCenterViewPort
		!ret_word 04 00
	]]})
	IEex_WriteAssembly(0x6437A0, {[[ !jmp_dword ]], {centerStub, 4, 4}})

	-- (4) Grab hit-zone follows the visible rect. OnLButtonDown (0x642DA0) decides drag-grab vs
	--     click-to-recentre with PtInRect against the UNZOOMED viewport rect r=[esp+0x20], so at
	--     zoom you could grab in the empty margin around the small visible rect. Redirect just the
	--     hit-test (@0x642EFA, the `lea &r; push y,x,&r; call PtInRect; test; je outside` block) to
	--     Export_MapGrabHitTest, which tests the VISIBLE (zoomed) rect. The grab OFFSET that
	--     follows (field_722 = ptWorld - r.left at 0x642F0D) still reads the unzoomed r, so the
	--     drag stays 1:1. edi=ptWorld.x, ebp=ptWorld.y and [esp+0x20]=r must survive (they do:
	--     C++ preserves edi/ebp/ebx/esi; the __stdcall helper cleans its args -> esp restored).
	--       Resume 0x642F0D (inside/grab) or 0x642F2E (outside).
	local grabStub = IEex_WriteAssemblyAuto({[[
		8B E8
		8D 44 24 20
		55
		57
		50
		!call >IEex_Helper_MapGrabHitTest
		85 C0
		!jnz_dword >inside
		!jmp_dword :642F2E
		@inside
		!jmp_dword :642F0D
	]]})
	IEex_WriteAssembly(0x642EFA, {[[ !jmp_dword ]], {grabStub, 4, 4}})

	-- ---------------------------------------------------------------------------
	-- Dialog auto-scroll zoom compensation. CGameDialogEntry::Handle scrolls to centre the speaker,
	-- but an extra vertical ptReference.y/2 nudge lands it OFF the GL zoom pivot ROW, so at zoom the
	-- scale about the viewport centre amplifies it and the auto-pan misses (Bubb: bottom speaker pans
	-- the wrong way). Export_DialogPanCompensateY retargets ptScroll.y to speakerWorldY - vpHeight/2
	-- (dead-centre on the pivot -> zoom-invariant like the horizontal axis), identity at z<=1.
	-- Hook @0x484b88, right after the GetViewPosition() call: esi = ptScroll.y (vanilla target), edi =
	-- pSprite (m_pos.y @edi+0x0A = speaker world Y). Pass BOTH: push edi (arg2 = pSprite) then esi
	-- (arg1 = ptScrollY). NB [esp+0x1c] here is nCurrentY -- the GetViewPosition result for the
	-- dx^2+dy^2 jump-cut test, NOT the speaker (the old bug read it as speakerY). Displaces 8 bytes
	-- (mov ecx,[esp+0x18]; mov eax,[esp+0x1c]); stub re-runs them, resumes 0x484b90. __stdcall callee
	-- cleans its 8 bytes so esp is restored for the displaced [esp+0x18]/[esp+0x1c] reads.
	local dialogPanStub = IEex_WriteAssemblyAuto({[[
		57
		56
		!call >IEex_Helper_DialogPanCompensateY
		8B F0
		8B 4C 24 18
		8B 44 24 1C
		!jmp_dword :484B90
	]]})
	IEex_WriteAssembly(0x484B88, IEex_FlattenTable({
		{[[ !jmp_dword ]], {dialogPanStub, 4, 4}},
		{[[ 90 90 90 ]]},
	}))

end)()
