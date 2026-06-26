
(function()

	-- HD UI master gate. INSTALL-time decision, NOT a player ini: the WeiDU "2x UI" component
	-- (2x_ui_resolution_gate.tpa) COPIES the 2x assets + pre-scaled CHU into override AND flips this
	-- flag false->true. The core ships it OFF (stock 1x UI, correct at any res). Push it to the helper
	-- so GetUICanvasScale (the GL canvas factor) tracks the install, not a togglable key. A runtime
	-- toggle can't work: a 2x CHU left in override renders oversized/broken when the canvas is 1x.
	local IEEX_HD_UI = false
	IEex_Helper_SetHDUI(IEEX_HD_UI and 1 or 0)

	-- Menu torch gate (install-time). The default menu art has the torch holder -> ON by default. The
	-- New-GUI component (DESIGNATED 37) has no torch in its menu art, so it flips this false. The torch
	-- only renders at HD-on anyway (GetUICanvasScale>1), so at <1200p / no-2x it stays off regardless.
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
	-- GL FONT FIX (opengl-only): the GL glyph atlas (CVidFont::LoadGlyphs @0x7A0B20) packs glyphs at row
	-- pitch = node->m_nFontHeight ([esi+0x40]), AND RenderCharacters (the GL text draw) samples each
	-- glyph as a node->m_nFontHeight-tall cell. That value (frame-1 height = 26) is too short two ways:
	--   (1) 1px under maxAscent+maxDescent (=27) -> atlas rows overlap -> a dash bleeds atop short
	--       letters (o/i/u);
	--   (2) the cell reaches only baseLine+4 below the baseline but descenders need 7 -> g/p/y/j tails
	--       are CROPPED.
	-- (Software renderer blits glyphs directly = no atlas, no per-cell sample = neither bug, which is
	-- why feature/ui-2x-scaling was clean.) FIX: bump the CACHED node->m_nFontHeight by +4 at the bake
	-- (right after it is set @0x7A0BD4). That widens BOTH the atlas pitch (kills the dash) and the render
	-- cell (restores descenders). Rendered LINE-SPACING is UNAFFECTED -- multi-line layout uses the
	-- recomputed GetFontHeight() (frame-1 height = 26), not node->m_nFontHeight -- so no single-line
	-- risk. Hook 0x7A0BDF (5 displaced bytes 89 4E 44 6A 01 = mov [esi+0x44],ecx / push 1), prepend
	--   83 46 40 04   add dword [esi+0x40], 4    (node->m_nFontHeight += 4)
	-- GL-only (LoadGlyphs is the GL bake); harmless / never reached under the software renderer.
	--------------------------------------------------------------------------------
	IEex_HookRestore(0x7A0BDF, 0, 5, {[[
		83 46 40 04
	]]})

	--------------------------------------------------------------------------------
	-- MENU TORCH (pivot). The animated main-menu torch (CScreenConnection::RenderTorch @0x5FB020) is
	-- drawn POST-Flip, into the buffer just swapped away from the display. On Wine/Mesa (triple-
	-- buffered) that frozen flame frame flickers through the live animation as the cursor moves -- the
	-- "parasite frame". FIX = SINGLE-RENDER: re-issue the torch ourselves PRE-Flip (helper
	-- Export_UIScaleRenderEndUI, every frame, on the buffer about to be presented) and NEUTRALISE the
	-- engine's own post-Flip draw (helper Export_UIScaleTorchBegin collapses the MODELVIEW off-screen
	-- when g_inMyTorchCall is false). So the torch is drawn exactly ONCE per frame, on the right buffer.
	-- Under the m_bUseNewGui tier the engine doubles the offset (pt 106,383 -> 212,766) and the
	-- de-doubled 2x MMTRCHB blits native = crisp 2x; the helper re-render gates on g_hdUI && UIMult()==2,
	-- and ComputeUIScaleRect is identity there so the engine's own coords are used as-is.
	-- Entry 0x5FB020: 5 displaced bytes (a1 dc f6 8c 00  mov eax,ds:0x8cf6dc) -> continue 0x5FB025.
	--------------------------------------------------------------------------------
	IEex_HookRestore(0x5FB020, 0, 5, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_UIScaleTorchBegin
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- WORLD HUD 2x (HD UI) -- reproduce the engine's NATIVE 2x tier for the in-world HUD, the same
	-- mechanism the game ships at the 1600/2048 resolution tiers. The menus scale via a pre-scaled
	-- CHU; the world HUD CANNOT (it positions its panels itself, AND the message log [CInfinity] +
	-- action bar [CInfButtonArray] scale off g_pBaldurChitin->field_4A2C, NOT the CHU). So flip
	-- field_4A2C=1 for the WORLD engine: the engine then doubles the HUD panel positions/sizes
	-- (CUIPanel ctor), the message screen and the action bar ALL together = one consistent 2x HUD,
	-- using the engine's OWN hit-test (so the mouse-wheel viewport/log gate + clicks stay correct --
	-- we do NOT touch them). field_4A2C is read ONLY by world-HUD code; the menus key off a DIFFERENT
	-- flag (m_bUseNewGui), so they are completely untouched.
	--
	-- field_4A2C=1 also makes CResCell pixel-DOUBLE every asset (GetFrameData: nearest 2x2). With our
	-- 2x-authored art that is 4x + blocky. So DE-DOUBLE: force bDoubleSize=FALSE in the three CResCell
	-- accessors -> the 2x asset draws at its native size (crisp 2x) while the panel/control GEOMETRY
	-- stays doubled. Net: crisp 2x HUD, same spirit as the menus (2x art at native pixels). The
	-- de-double is global but only bites when something renders bDoubleSize=TRUE, and at our
	-- resolution the ONLY such consumer is this world HUD.
	--
	-- Gated on IEEX_HD_UI: without the 2x assets this would put 1x art in 2x slots, so it stays off
	-- when HD is off (the world HUD then renders stock 1x, correct at any resolution). This SUPERSEDES
	-- the Stage-2 world render-scale (now identity in the helper) -- the engine does the 2x natively.
	--   field_4A2C @ [ [0x8CF6DC] + 0x4A2C ]  (g_pBaldurChitin)
	--   CScreenWorld::EngineGameInit 0x686DE0 : SEH prologue, 7 displaced (6A FF / 68 B6 24 83 00)
	--   CResCell::GetFrame      0x77F520 : bDoubleSize @[esp+0x0C], 7 displaced
	--   CResCell::GetCompressed 0x77F5C0 : bDoubleSize @[esp+0x08], 6 displaced (stop before the jne)
	--   CResCell::GetFrameData  0x77F5F0 : bDoubleSize @[esp+0x08], 7 displaced
	--------------------------------------------------------------------------------
	if IEEX_HD_UI then
		IEex_DisableCodeProtection()
		-- NOTE: m_bUseNewGui + field_4A2C are now set GLOBALLY by IEex_Extern_InitHighResolutionPaddingPanels
		-- (the engine's native 2x tier), so the old per-screen forces here -- field_4A2C@0x686DE0 (world) and
		-- the fInit@0x4D3B80 force for the inventory-class screens -- are REMOVED (redundant + conflicting
		-- with the global tier). UIMult() now reads 0x4A28=1 -> the render-scale auto-fits the 2x UI.
		-- =====================================================================================
		-- SELECTIVE 2x UI de-double (ported from feature/ui-2x-scaling). Replaces the earlier GLOBAL
		-- de-double, which forced bDoubleSize=FALSE on EVERY asset and so cancelled the engine's
		-- doubling for VANILLA 1x art (action-bar item/spell icons rendered 1x = absent). This is
		-- resref/dimension-gated: ONLY the HD-authored set (fonts, ~90 UI BAMs incl. FORM*/GUIHITPT,
		-- SP*/I* icons, MOS panels, HD portraits) is de-doubled (-> native crisp 2x); everything else
		-- keeps the engine doubling (1x art -> 2x, visible). + HD cursor save-under + STATES icons.
		-- =====================================================================================
		-- [HD UI fonts] crisp 2x for the HD-repacked fonts. At 2x UI the engine doubles 1x font BAMs via
		-- CVidCell::m_bDoubleSize, passed as the bDoubleSize ARG to CResCell::GetFrame (dims x2) and
		-- CResCell::GetFrameData (NN pixel x2). We ship 2x-authored BAMs, so any doubling makes them 4x. The flag
		-- is read on MANY paths incl. GetResFrame INLINED (CUtil::SplitString) -> these two CResCell resource fns
		-- are the single convergence point all of them hit. Each: this=ecx=CResCell*; m_pDimmKeyTableEntry @+0x10,
		-- its resRef first dword @+0. If the resref matches an HD-repacked font, force the bDoubleSize stack ARG
		-- to 0 -> native (sharp 2x). NULL-guarded; resref-scoped so sprites/items/NON-repacked fonts keep doubling.
		-- Match the FULL 8-char resref (both dwords), NOT just the 4-char prefix: "STON" collides with 20+
		-- inventory stone graphics (STONARM/STONSLOT/STONWEAP/STONQUIV/...) and "TOOL" with TOOLTIP -- a prefix
		-- filter de-doubled those too and broke the inventory. Each font: if resref[0:4]==dword1 AND
		-- resref[4:8]==dword2 -> hit. dword2 = chars 5-8 LE (null-padded). Add a font here when its HD BAM ships.
		-- NORMAL "NORM"/"AL\0\0" · TOOLFONT "TOOL"/"FONT" · STONESML "STON"/"ESML" · INFOFONT "INFO"/"FONT"
		-- · NUMFONT "NUMF"/"ONT\0" (portrait HP numbers -- replaced the stock 1-bit bevel digits with a crisp
		-- silly_pixel BAM authored at final px, so it must de-double too, else the 1px outline renders 2px).
		-- · REALMS "REAL"/"MS\0\0" (uncial display/title face; HD BAM repacked from an auto-traced TTF of the
		-- stock REALMS glyphs -- potrace+FontForge, scripts/realms_trace.py + realms_build.py).
		-- · INITIALS "INIT"/"IALS" (ornate illuminated drop-caps; full-colour, so the HD BAM is a 2x Lanczos
		-- upscale of the stock colour frames repacked verbatim in the original palette, scripts/initials_upscale.py).
		-- See HD_UI_FONTS.md §1a/§7/§8.
		local hd_match =
			"!push(eax) !mov(eax,[ecx+0x10]) !test_eax_eax !jz_dword >skip "
			.. "!mov(eax,[eax]) !cmp_eax_dword #4D524F4E !jne_dword >c1 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #00004C41 !jz_dword >hit @c1 "
			.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #4C4F4F54 !jne_dword >c2 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #544E4F46 !jz_dword >hit @c2 "
			.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #4E4F5453 !jne_dword >c3 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #4C4D5345 !jz_dword >hit @c3 "
			.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #4F464E49 !jne_dword >c4 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #544E4F46 !jz_dword >hit @c4 "
			.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #464D554E !jne_dword >c5 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #00544E4F !jz_dword >hit @c5 "
			.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #4C414552 !jne_dword >c6 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #0000534D !jz_dword >hit @c6 "
			.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #54494E49 !jne_dword >c7 !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #534C4149 !jz_dword >hit @c7 "
		-- [HD UI buttons] the SAME CResCell de-double, extended to the 49 UI button/graphic BAMs
		-- (action bar GUIBTACT, the GBTN* family, inventory/spell/store/options buttons, inn-room
		-- images) that draw via CUIControlButton -> CVidCell with m_bDoubleSize = manager->m_bDoubleSize.
		-- Each is AI-upscaled (Remacri) to 2x and de-doubled here by FULL 8-char resref (branches c8+).
		-- The 255-frame stone fonts (STONEBIG/STONESM3) + STATES2 status icons stay 1x. See §11.
		local btn_list = {
			{0x52544D4D, 0x00424843}, -- MMTRCHB (main-menu torch animation; 2x asset -> de-double = crisp 2x)
			{0x42475355, 0x4C514E54}, -- USGBTNQL (mod quickloot ACTIVATION button on the command dial; 2x asset)
			{0x54554243, 0x00000000}, -- CBUT
			{0x41454743, 0x00000052}, -- CGEAR
			{0x4B494C43, 0x4E4F4332}, -- CLIK2CON
			{0x544E4F43, 0x4B434142}, -- CONTBACK
			{0x47414C46, 0x00000031}, -- FLAG1
			{0x4E544247, 0x4D524642}, -- GBTNBFRM
			{0x4E544247, 0x4B4E4C42}, -- GBTNBLNK
			{0x4E544247, 0x00004143}, -- GBTNCA
			{0x4E544247, 0x4E54424A}, -- GBTNJBTN
			{0x4E544247, 0x4B43494B}, -- GBTNKICK
			{0x4E544247, 0x0047524C}, -- GBTNLRG
			{0x4E544247, 0x3247524C}, -- GBTNLRG2
			{0x4E544247, 0x3347524C}, -- GBTNLRG3
			{0x4E544247, 0x0044454D}, -- GBTNMED
			{0x4E544247, 0x3244454D}, -- GBTNMED2
			{0x4E544247, 0x534E494D}, -- GBTNMINS
			{0x4E544247, 0x3154504F}, -- GBTNOPT1
			{0x4E544247, 0x3354504F}, -- GBTNOPT3
			{0x4E544247, 0x4D524550}, -- GBTNPERM
			{0x4E544247, 0x53554C50}, -- GBTNPLUS
			{0x4E544247, 0x00524F50}, -- GBTNPOR
			{0x4E544247, 0x42434552}, -- GBTNRECB
			{0x4E544247, 0x4C524353}, -- GBTNSCRL
			{0x4E544247, 0x31425053}, -- GBTNSPB1
			{0x4E544247, 0x32425053}, -- GBTNSPB2
			{0x4E544247, 0x33425053}, -- GBTNSPB3
			{0x4E544247, 0x00445453}, -- GBTNSTD
			{0x4E544247, 0x4E445055}, -- GBTNUPDN
			{0x4D4F4347, 0x4E54424D}, -- GCOMMBTN
			{0x4D4F4347, 0x0042534D}, -- GCOMMSB
			{0x42495547, 0x54434154}, -- GUIBTACT
			{0x42495547, 0x54554254}, -- GUIBTBUT
			{0x43495547, 0x004C5254}, -- GUICTRL
			{0x4D495547, 0x43575041}, -- GUIMAPWC
			{0x52495547, 0x524F5053}, -- GUIRSPOR
			{0x52495547, 0x524F505A}, -- GUIRZPOR
			{0x53495547, 0x0052444C}, -- GUISLDR
			{0x53495547, 0x43424254}, -- GUISTBBC
			{0x53495547, 0x43534D54}, -- GUISTMSC
			{0x42564E49, 0x00325455}, -- INVBUT2
			{0x42564E49, 0x00335455}, -- INVBUT3
			{0x4D4F4F52, 0x554C4544}, -- ROOMDELU
			{0x4D4F4F52, 0x4352454D}, -- ROOMMERC
			{0x4D4F4F52, 0x45424F4E}, -- ROOMNOBE
			{0x4D4F4F52, 0x53414550}, -- ROOMPEAS
			{0x424C5053, 0x00005455}, -- SPLBUT
			{0x4E4F5453, 0x544F4C53}, -- STONSLOT
			{0x524F5453, 0x52435345}, -- STORESCR
			{0x47474F54, 0x0000454C}, -- TOGGLE
			{0x424D554E, 0x00005245}, -- NUMBER (action-bar/item count digits; CIcon::RenderIcon, HD LycheeSoda)
			{0x4E4F5453, 0x47494245}, -- STONEBIG (inventory/record names + titles; HD Amood IV serif)
			{0x4E4F5453, 0x334D5345}, -- STONESM3 (stone small-caps; HD Amood IV caps)
			-- inventory chrome (HD Remacri): selection frame + usability tints + empty equip-slot stones
			{0x48474948, 0x5448474C}, -- HIGHLGHT (green/red select frame)
			{0x524F5453, 0x544E4954}, -- STORTINT (red can't-use tint)
			{0x524F5453, 0x344E4954}, -- STORTIN4 (gold UMD tint)
			{0x4E4F5453, 0x004D5241}, -- STONARM
			{0x4E4F5453, 0x4D4C4548}, -- STONHELM
			{0x4E4F5453, 0x54454C47}, -- STONGLET
			{0x4E4F5453, 0x4C554D41}, -- STONAMUL
			{0x4E4F5453, 0x56495551}, -- STONQUIV
			{0x4E4F5453, 0x544C4542}, -- STONBELT
			{0x4E4F5453, 0x544F4F42}, -- STONBOOT
			{0x4E4F5453, 0x4B4F4C43}, -- STONCLOK
			{0x4E4F5453, 0x474E4952}, -- STONRING
			{0x4E4F5453, 0x4C494853}, -- STONSHIL
			{0x4E4F5453, 0x50414557}, -- STONWEAP
			{0x4E4F5453, 0x4D455449}, -- STONITEM
			{0x4E4F5453, 0x4D524F46}, -- STONFORM
			{0x4E4F5453, 0x474E4F53}, -- STONSONG
			{0x4E4F5453, 0x43455053}, -- STONSPEC
			{0x4E4F5453, 0x4C455053}, -- STONSPEL
			{0x4D554849, 0x00000000}, -- IHUM    (item icon reused as a spell icon; outside SP* gate)
			{0x53494D49, 0x00343843}, -- IMISC84 (item icon reused as a spell icon)
			{0x4F4F4D49, 0x0000004E}, -- IMOON   (item icon reused as a spell icon)
			{0x54534946, 0x00000000}, -- FIST    (item icon, outside I* gate)
			{0x504D4554, 0x00000000}, -- TEMP    (item icon, outside I* gate)
			{0x4C505355, 0x35315441}, -- USPLAT15 (item icon, outside I* gate)
			{0x434E4950, 0x00535245}, -- PINCERS (action-bar quickSlotIcon, outside I*/SP*)
			{0x57415057, 0x00000000}, -- WPAW
			{0x57415050, 0x00000000}, -- PPAW
			{0x57415044, 0x00000000}, -- DPAW
			{0x4D524F46, 0x00000030}, -- FORM0 (formation icon)
			{0x4D524F46, 0x00000031}, -- FORM1 (formation icon)
			{0x4D524F46, 0x00000032}, -- FORM2 (formation icon)
			{0x4D524F46, 0x00000033}, -- FORM3 (formation icon)
			{0x4D524F46, 0x00000034}, -- FORM4 (formation icon)
			{0x4D524F46, 0x00000035}, -- FORM5 (formation icon)
			{0x4D524F46, 0x00000036}, -- FORM6 (formation icon)
			{0x4D524F46, 0x00000037}, -- FORM7 (formation icon)
			{0x4D524F46, 0x00000038}, -- FORM8 (formation icon)
			{0x4D524F46, 0x00000039}, -- FORM9 (formation icon)
			{0x4D524F46, 0x00000041}, -- FORMA (formation icon)
			{0x4D524F46, 0x00000042}, -- FORMB (formation icon)
			{0x48495547, 0x54505449}, -- GUIHITPT (portrait HP bar BAM)
		}
		for k, p in ipairs(btn_list) do
			local lbl = "c" .. (7 + k)
			hd_match = hd_match
				.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #" .. string.format("%08X", p[1])
				.. " !jne_dword >" .. lbl
				.. " !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #" .. string.format("%08X", p[2])
				.. " !jz_dword >hit @" .. lbl .. " "
		end
		-- HD spell icons: PREFIX gate -- one branch covers all ~390 SP* spell/ability icons.
		-- and eax,0x0000FFFF (chars 0-1) ; cmp "SP" (0x5053) ; hit. SP* via CResCell = spell icons +
		-- SPLBUT (both HD); spell-effect/projectile SP* BAMs are NOT cell-drawn so never reach here.
		hd_match = hd_match .. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) 25 FF FF 00 00 !cmp_eax_dword #00005053 !jz_dword >hit "
		-- HD item icons: PREFIX gate -- one branch covers all I* item icons (and eax,0xFF (char0); cmp 'I').
		-- I* via CResCell = item icons + INITIALS/INVBUT/INFOFONT (all already HD/de-doubled). SP* scroll
		-- item icons are caught by the SP* branch above; FIST/TEMP/USPLAT15 by resref.
		hd_match = hd_match .. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) 25 FF 00 00 00 !cmp_eax_dword #00000049 !jz_dword >hit "
		hd_match = hd_match .. "!jmp_dword >skip @hit "
		-- === HD cursor save-under: enlarge the pointer backup surfaces (height 64 -> 256) ===
		-- The dragged-item cursor draws the de-doubled item icon (~128px tall) + its stack number.
		-- The cursor save-under backup (CVidInf SURFACE_4/5) is hardcoded 256x64 in THREE spots --
		-- a 2x item overflows the 64px height -> StoreBackground/RestoreBackground (and the
		-- SURFACE_4->5 double-buffer sync) can't save/restore the bottom -> trailing smear. Patch
		-- all three heights to 256 (width stays 256 -> uniform, no desync). 256x256 covers a 2x
		-- item + number (and a future 2x cursor).
		IEex_WriteDword(0x79B7C6, 0x100)  -- CreateSurfaces: SURFACE_4/5 dwHeight  64 -> 256
		IEex_WriteDword(0x79C282, 0x100)  -- Flip3d sync-blit src rect bottom      64 -> 256
		IEex_WriteDword(0x79C59A, 0x100)  -- cursor-surface dims getter height     64 -> 256
		-- Cursor stack-number trail: on the dragged cursor the number is positioned from the ITEM's
		-- frameSize (CVidInf::RenderPointerImage), drawn at the item's lower-right corner = at/just
		-- past the save-under rect, regardless of NUMBER.BAM's own cx/cy. Extend rStorage right+bottom
		-- BEFORE the rClip clamp so the number region is saved/restored each frame.
		-- At 0x7AE46E the rect is in regs: eax=left esi=top edx=right ecx=bottom (pre-clamp).
		IEex_AttemptHook(0x7AE46E,  -- CVidCell::StoreBackground: grow save-under to cover the cursor stack number
			{"83 C2 30 83 C1 60"},  -- right += 0x30, bottom += 0x60 (clamped to screen by the following code)
			{"8B 5C 24 34 8B E8 !jmp_dword :7AE474"}, {0x8B, 0x5C, 0x24, 0x34, 0x8B, 0xE8})
		IEex_AttemptHook(0x77F520,  -- CResCell::GetFrame (metrics); bDoubleSize arg @[esp+0x0C] (->+0x10 after push)
			{hd_match .. "!mov([esp+10],0) @skip !pop(eax)"},
			{"8B 51 64 56 85 D2 !jmp_dword :77F526"}, {0x8B, 0x51, 0x64, 0x56, 0x85, 0xD2})
		IEex_AttemptHook(0x77F5F0,  -- CResCell::GetFrameData (pixels); bDoubleSize arg @[esp+0x08] (->+0x0C after push)
			{hd_match .. "!mov([esp+0C],0) @skip !pop(eax)"},
			{"83 EC 10 53 8B D9 !jmp_dword :77F5F6"}, {0x83, 0xEC, 0x10, 0x53, 0x8B, 0xD9})

		-- === HD portrait status icons (STATES): force the portrait cell to NOT engine-double ===
		-- The buff/status icons on portraits are CGameSprite.m_portraitIconVidCell (resref "STATES"), AI-upscaled
		-- to 2x (Nomos8kDAT). The cell is built with bDoubleSize = m_bUseNewGui, so at 2x UI it doubled our 2x BAM
		-- -> 4x (icons 2x too big). De-doubling via the CResCell/CResCellHeader GetFrame hooks is unsafe here:
		-- CGameSprite INLINES the cell ctor (SetResRef 0x58FC70 is never called) and draws via an inlined
		-- GetResFrame -> the header doubler 0x77FDA0; hooking 0x77FDA0 corrupted other header-cached UI. Instead
		-- patch the ONE source: in CGameSprite::CGameSprite the portrait cell's bDoubleSize comes from a single
		-- read of m_bUseNewGui at 0x6EFFCB (mov eax,[ecx+0x4A28]) that is immediately push'd as the ctor arg.
		-- Replace it with xor eax,eax (+nops) so the cell is built bDoubleSize=FALSE -> never doubles on ANY path
		-- (metrics+pixels, header or not). Scoped to ONLY this cell: it is the sole 0x4A28 read in the ctor, ecx
		-- is reassigned right after, eax is pushed immediately. Layout unchanged -- RenderPortrait positions icons
		-- by its OWN bDoubleSize param (m_bUseNewGui), not the cell flag. We ship the 2x STATES BAM so it renders
		-- native-crisp at the correct size. bytes @0x6EFFCB: 8B 81 28 4A 00 00 -> 31 C0 90 90 90 90. See §13.
		IEex_WriteDword(0x6EFFCB, 0x9090C031)  -- xor eax,eax ; nop ; nop  (0x6EFFCB..CE)
		IEex_WriteWord(0x6EFFCF, 0x9090)       -- nop ; nop                (0x6EFFCF..D0)


		-- === HD UI mosaics (MOS) de-double -- crisp upscaled panels instead of NN-doubled ===
		-- CResMosaic is the MOS twin of CResCell: GetMosaicWidth/Height/TileSize(bDoubleSize)
		-- return 2x the header dim, GetTileData(nTile,bDoubleSize) NN-expands each pixel to a 2x2
		-- block. Under m_bUseNewGui the panel MOS double -> blocky. Ship a 2x-authored (Lanczos/AI
		-- upscaled) MOS and force bDoubleSize=0 for its resref in all FOUR fns -> renders native =
		-- crisp 2x. Resref via m_pDimmKeyTableEntry @[this+0x10] (same as the font de-double).
		-- bDoubleSize: @[esp+4] in the 3 size fns (->+8 after push eax), @[esp+8] in GetTileData
		-- (->+0xC). Every UI panel MOS (ALL MOS now -- NearInfinity confirms MOS are all UI) is AI-upscaled (Remacri) to 2x and
		-- shipped; each entry below is its resref's two LE dwords (chars 0-3, 4-7). Match ANY -> force
		-- bDoubleSize=0 (renders native = crisp 2x). The thin fill/bar strips (<90px tall) stay
		-- NN-doubled (imperceptible, no detail to recover). Add a MOS here as its HD .MOS ships.
		local mos_list = {
			{0x4F4C4F43, 0x00000052}, -- COLOR
			{0x54434147, 0x3830304E}, -- GACTN008
			{0x54434147, 0x3830314E}, -- GACTN108
			{0x54434147, 0x3831314E}, -- GACTN118
			{0x50474347, 0x59545241}, -- GCGPARTY
			{0x4D4F4347, 0x3830304D}, -- GCOMM008
			{0x4D4F4347, 0x3830314D}, -- GCOMM108
			{0x4D4F4347, 0x3831314D}, -- GCOMM118
			{0x4D4F4347, 0x3832314D}, -- GCOMM128
			{0x54494947, 0x3830484D}, -- GIITMH08
			{0x43504D47, 0x42425241}, -- GMPCARBB
			{0x4D504D47, 0x42524843}, -- GMPMCHRB
			{0x4D504D47, 0x42524C50}, -- GMPMPLRB
			{0x4E504D47, 0x31454743}, -- GMPNCGE1
			{0x4E504D47, 0x32454743}, -- GMPNCGE2
			{0x4E504D47, 0x33454743}, -- GMPNCGE3
			{0x4E504D47, 0x424D4743}, -- GMPNCGMB
			{0x4E504D47, 0x42585049}, -- GMPNIPXB
			{0x4E504D47, 0x424D474A}, -- GMPNJGMB
			{0x4E504D47, 0x454D474A}, -- GMPNJGME
			{0x4E504D47, 0x42424F4C}, -- GMPNLOBB
			{0x4E504D47, 0x42444F4D}, -- GMPNMODB
			{0x4E504D47, 0x424F4850}, -- GMPNPHOB
			{0x4E504D47, 0x454F4850}, -- GMPNPHOE
			{0x4E504D47, 0x424D4E50}, -- GMPNPNMB
			{0x4E504D47, 0x42545250}, -- GMPNPRTB
			{0x4E504D47, 0x42524553}, -- GMPNSERB
			{0x4E504D47, 0x42504354}, -- GMPNTCPB
			{0x4E504D47, 0x45504354}, -- GMPNTCPE
			{0x50504D47, 0x42425241}, -- GMPPARBB
			{0x50504D47, 0x45425241}, -- GMPPARBE
			{0x53504D47, 0x0000424D}, -- GMPSMB
			{0x56504D47, 0x42524843}, -- GMPVCHRB
			{0x44574D47, 0x30424D4D}, -- GMWDMMB0
			{0x44574D47, 0x38424D4D}, -- GMWDMMB8
			{0x44574D47, 0x30424C53}, -- GMWDSLB0
			{0x44574D47, 0x38424C53}, -- GMWDSLB8
			{0x46504F47, 0x31424B42}, -- GOPFBKB1
			{0x46504F47, 0x32424B42}, -- GOPFBKB2
			{0x47504F47, 0x00424D41}, -- GOPGAMB
			{0x50504F47, 0x00425541}, -- GOPPAUB
			{0x53504F47, 0x0042444E}, -- GOPSNDB
			{0x53504F47, 0x4253444E}, -- GOPSNDSB
			{0x4F4D5047, 0x00003031}, -- GPMO10
			{0x4F525047, 0x52414247}, -- GPROGBAR
			{0x45465247, 0x38305441}, -- GRFEAT08
			{0x42525447, 0x52414250}, -- GTRBPBAR
			{0x42525447, 0x00474250}, -- GTRBPBG
			{0x42525447, 0x50414350}, -- GTRBPCAP
			{0x42525447, 0x004B5350}, -- GTRBPSK
			{0x42525447, 0x324B5350}, -- GTRBPSK2
			{0x43525447, 0x00474244}, -- GTRCDBG
			{0x43525447, 0x51455244}, -- GTRCDREQ
			{0x53525447, 0x004E5243}, -- GTRSCRN
			{0x53525447, 0x52414250}, -- GTRSPBAR
			{0x53525447, 0x00474250}, -- GTRSPBG
			{0x53525447, 0x50414350}, -- GTRSPCAP
			{0x53525447, 0x004B5350}, -- GTRSPSK
			{0x53525447, 0x324B5350}, -- GTRSPSK2
			{0x4F435547, 0x3042544E}, -- GUCONTB0
			{0x4F435547, 0x3842544E}, -- GUCONTB8
			{0x45445547, 0x30485441}, -- GUDEATH0
			{0x45445547, 0x38485441}, -- GUDEATH8
			{0x41495547, 0x00004242}, -- GUIABB
			{0x41495547, 0x00004250}, -- GUIAPB
			{0x41495547, 0x00324250}, -- GUIAPB2
			{0x42495547, 0x0048414C}, -- GUIBLAH
			{0x43495547, 0x42425241}, -- GUICARBB
			{0x43495547, 0x00505845}, -- GUICEXP
			{0x43495547, 0x00004247}, -- GUICGB
			{0x43495547, 0x42534948}, -- GUICHISB
			{0x43495547, 0x42305048}, -- GUICHP0B
			{0x43495547, 0x42315048}, -- GUICHP1B
			{0x43495547, 0x42325048}, -- GUICHP2B
			{0x43495547, 0x42335048}, -- GUICHP3B
			{0x43495547, 0x42345048}, -- GUICHP4B
			{0x43495547, 0x42355048}, -- GUICHP5B
			{0x43495547, 0x42365048}, -- GUICHP6B
			{0x43495547, 0x0054534C}, -- GUICLST
			{0x43495547, 0x454D414E}, -- GUICNAME
			{0x43495547, 0x42524F50}, -- GUICPORB
			{0x43495547, 0x45434152}, -- GUICRACE
			{0x43495547, 0x42545355}, -- GUICUSTB
			{0x44495547, 0x424C4343}, -- GUIDCCLB
			{0x45495547, 0x42305252}, -- GUIERR0B
			{0x45495547, 0x42315252}, -- GUIERR1B
			{0x45495547, 0x42325252}, -- GUIERR2B
			{0x45495547, 0x42335252}, -- GUIERR3B
			{0x45495547, 0x42345252}, -- GUIERR4B
			{0x45495547, 0x00455058}, -- GUIEXPE
			{0x46495547, 0x00544145}, -- GUIFEAT
			{0x46495547, 0x32544145}, -- GUIFEAT2
			{0x47495547, 0x50595441}, -- GUIGATYP
			{0x47495547, 0x00004244}, -- GUIGDB
			{0x48495547, 0x00504C45}, -- GUIHELP
			{0x48495547, 0x54505449}, -- GUIHITPT
			{0x48495547, 0x00004253}, -- GUIHSB
			{0x49495547, 0x3830564E}, -- GUIINV08
			{0x49495547, 0x4241564E}, -- GUIINVAB
			{0x49495547, 0x4252564E}, -- GUIINVRB
			{0x49495547, 0x4552564E}, -- GUIINVRE
			{0x4A495547, 0x004C4E52}, -- GUIJRNL
			{0x4C495547, 0x00425055}, -- GUILUPB
			{0x4D495547, 0x42415041}, -- GUIMAPAB
			{0x4D495547, 0x4D475041}, -- GUIMAPGM
			{0x4D495547, 0x42575041}, -- GUIMAPWB
			{0x4D495547, 0x43575041}, -- GUIMAPWC
			{0x4D495547, 0x0042564F}, -- GUIMOVB
			{0x4E495547, 0x0000454D}, -- GUINME
			{0x52495547, 0x38304345}, -- GUIREC08
			{0x52495547, 0x004E4547}, -- GUIRGEN
			{0x52495547, 0x314C564C}, -- GUIRLVL1
			{0x52495547, 0x324C564C}, -- GUIRLVL2
			{0x52495547, 0x334C564C}, -- GUIRLVL3
			{0x52495547, 0x344C564C}, -- GUIRLVL4
			{0x52495547, 0x354C564C}, -- GUIRLVL5
			{0x52495547, 0x364C564C}, -- GUIRLVL6
			{0x52495547, 0x374C564C}, -- GUIRLVL7
			{0x53495547, 0x00005845}, -- GUISEX
			{0x53495547, 0x0052444C}, -- GUISLDR
			{0x53495547, 0x38304C50}, -- GUISPL08
			{0x53495547, 0x00324C50}, -- GUISPL2
			{0x53495547, 0x42484C50}, -- GUISPLHB
			{0x53495547, 0x42515252}, -- GUISRRQB
			{0x53495547, 0x42565352}, -- GUISRSVB
			{0x53495547, 0x45565352}, -- GUISRSVE
			{0x53495547, 0x53544154}, -- GUISTATS
			{0x53495547, 0x42424254}, -- GUISTBBB
			{0x53495547, 0x42534254}, -- GUISTBSB
			{0x53495547, 0x454F4454}, -- GUISTDOE
			{0x53495547, 0x42524454}, -- GUISTDRB
			{0x53495547, 0x42444954}, -- GUISTIDB
			{0x53495547, 0x42504D54}, -- GUISTMPB
			{0x53495547, 0x45504D54}, -- GUISTMPE
			{0x53495547, 0x46504D54}, -- GUISTMPF
			{0x53495547, 0x424F5254}, -- GUISTROB
			{0x56495547, 0x00425245}, -- GUIVERB
			{0x57495547, 0x45544843}, -- GUIWCHTE
			{0x57495547, 0x46544843}, -- GUIWCHTF
			{0x57495547, 0x00455050}, -- GUIWPPE
			{0x42575547, 0x38315054}, -- GUWBTP18
			{0x42575547, 0x30335054}, -- GUWBTP30
			{0x42575547, 0x38335054}, -- GUWBTP38
			{0x43575547, 0x38425448}, -- GUWCHTB8
			{0x44414F4C, 0x30303031}, -- LOAD1000
			{0x44414F4C, 0x30303032}, -- LOAD2000
			{0x44414F4C, 0x30303033}, -- LOAD3000
			{0x44414F4C, 0x30303034}, -- LOAD4000
			{0x44414F4C, 0x30303134}, -- LOAD4100
			{0x44414F4C, 0x30303035}, -- LOAD5000
			{0x44414F4C, 0x30303135}, -- LOAD5100
			{0x44414F4C, 0x30303235}, -- LOAD5200
			{0x44414F4C, 0x30303335}, -- LOAD5300
			{0x44414F4C, 0x30303036}, -- LOAD6000
			{0x44414F4C, 0x30353036}, -- LOAD6050
			{0x44414F4C, 0x30303136}, -- LOAD6100
			{0x44414F4C, 0x30303236}, -- LOAD6200
			{0x44414F4C, 0x30303336}, -- LOAD6300
			{0x54534552, 0x00000000}, -- REST
			{0x52415453, 0x00000054}, -- START
			{0x52415453, 0x00004E54}, -- STARTN
			{0x4E4F5453, 0x00423031}, -- STON10B
			{0x4E4F5453, 0x004C3031}, -- STON10L
			{0x4E4F5453, 0x00523031}, -- STON10R
			{0x4E4F5453, 0x00543031}, -- STON10T
			{0x4E4F5453, 0x54504F45}, -- STONEOPT
			{0x50414D57, 0x00000031}, -- WMAP1
			{0x50414D57, 0x00000032}, -- WMAP2
			{0x50414D57, 0x00000033}, -- WMAP3
		}
		local mos_match = "!push(eax) !mov(eax,[ecx+0x10]) !test_eax_eax !jz_dword >skip "
		for k, p in ipairs(mos_list) do
			mos_match = mos_match
				.. "!mov(eax,[ecx+0x10]) !mov(eax,[eax]) !cmp_eax_dword #" .. string.format("%08X", p[1])
				.. " !jne_dword >m" .. k
				.. " !mov(eax,[ecx+0x10]) !mov(eax,[eax+0x4]) !cmp_eax_dword #" .. string.format("%08X", p[2])
				.. " !jz_dword >hit @m" .. k .. " "
		end
		mos_match = mos_match .. "!jmp_dword >skip @hit "
		IEex_AttemptHook(0x780310,  -- CResMosaic::GetMosaicWidth
			{mos_match .. "!mov([esp+8],0) @skip !pop(eax)"},
			{"8B 44 24 04 85 C0 !jmp_dword :780316"}, {0x8B, 0x44, 0x24, 0x04, 0x85, 0xC0})
		IEex_AttemptHook(0x780340,  -- CResMosaic::GetMosaicHeight
			{mos_match .. "!mov([esp+8],0) @skip !pop(eax)"},
			{"8B 44 24 04 85 C0 !jmp_dword :780346"}, {0x8B, 0x44, 0x24, 0x04, 0x85, 0xC0})
		IEex_AttemptHook(0x780370,  -- CResMosaic::GetTileSize
			{mos_match .. "!mov([esp+8],0) @skip !pop(eax)"},
			{"8B 44 24 04 85 C0 !jmp_dword :780376"}, {0x8B, 0x44, 0x24, 0x04, 0x85, 0xC0})
		IEex_AttemptHook(0x7803A0,  -- CResMosaic::GetTileData
			{mos_match .. "!mov([esp+0C],0) @skip !pop(eax)"},
			{"83 EC 08 33 D2 53 !jmp_dword :7803A6"}, {0x83, 0xEC, 0x08, 0x33, 0xD2, 0x53})

		-- === HD UI portraits (BMP) de-double -- crisp upscaled character art instead of NN-doubled ===
		-- Portrait controls blit via CVidBitmap with m_bDoubleSize = manager->m_bDoubleSize
		-- (CUIControlFactory), so under the 2x UI the stock 210x330 _L / 42x42 _S portrait BMP get
		-- NN-doubled (blocky). Ship an AI-upscaled (RealESRGAN x4) 420x660 _L + 84x84 _S (face crop)
		-- and force bDoubleSize=0 in CResBitmap::GetImageData (0x77ECF0) + GetImageDimensions
		-- (0x77EF70) when the native dims are our HD sizes -> renders native = crisp 2x. BOTH fns
		-- must agree (the control sizes the blit rect from GetImageDimensions, reads pixels from
		-- GetImageData). Gate on DIMS not resref: no stock BMP is 420x660 or 84x84 (verified scan),
		-- so this also covers custom party portraits authored at HD. CResBitmap layout:
		-- bParsed @[this+0x58]; pBitmapInfoHeader @[this+0x64]; biWidth @[+4]; biHeight @[+8].
		local bmp_match =
			"!push(eax) !mov(eax,[ecx+0x58]) !test_eax_eax !jz_dword >skip "          -- not parsed -> leave
			.. "!mov(eax,[ecx+0x64]) !test_eax_eax !jz_dword >skip "                  -- null BITMAPINFOHEADER guard
			.. "!mov(eax,[eax+0x4]) !cmp_eax_dword #000001A4 !jne_dword >c84 "        -- biWidth==420?
			.. "!mov(eax,[ecx+0x64]) !mov(eax,[eax+0x8]) !cmp_eax_dword #00000294 !jz_dword >hit " -- biHeight==660 -> HD _L
			.. "@c84 !mov(eax,[ecx+0x64]) !mov(eax,[eax+0x4]) !cmp_eax_dword #00000054 !jne_dword >c42 " -- biWidth==84?
			.. "!mov(eax,[ecx+0x64]) !mov(eax,[eax+0x8]) !cmp_eax_dword #00000054 !jz_dword >hit "        -- biHeight==84 -> HD _S
			.. "@c42 !mov(eax,[ecx+0x10]) !test_eax_eax !jne_dword >skip "                          -- m_pDimmKeyTableEntry != NULL: a NAMED 42x42 resource = an in-game/custom _S portrait (stock small portraits are 42x42 too). Leave it doubled. ONLY the save-screen copy de-doubles -- it is loaded by CDimm::ServiceFromFile (CResRef(""), no key-table entry -> +0x10 == NULL), so this guard separates it from real portraits sharing the size.
			.. "!mov(eax,[ecx+0x64]) !mov(eax,[eax+0x4]) !cmp_eax_dword #0000002A !jne_dword >skip " -- biWidth==42?
			.. "!mov(eax,[ecx+0x64]) !mov(eax,[eax+0x8]) !cmp_eax_dword #0000002A !jne_dword >skip "       -- biHeight==42 -> the 2x portrait copy a 2x-UI save writes into MPSave/<slot>/PORTRTn.BMP. De-double so the Load/Save list shows it native (not 4x/garbled). Display-only: the saved BMP is untouched, so the save stays vanilla-compatible. Old 1x (21x21) saves don't match here -> still doubled -> still correct.
			.. "@hit "
		IEex_AttemptHook(0x77ECF0,  -- CResBitmap::GetImageData; bDoubleSize @[esp+4] (->+8 after push eax)
			{bmp_match .. "!mov([esp+8],0) @skip !pop(eax)"},
			{"83 EC 14 53 56 !jmp_dword :77ECF5"}, {0x83, 0xEC, 0x14, 0x53, 0x56})
		IEex_AttemptHook(0x77EF70,  -- CResBitmap::GetImageDimensions; bDoubleSize @[esp+8] (->+0xC after push eax)
			{bmp_match .. "!mov([esp+0C],0) @skip !pop(eax)"},
			{"8B 41 58 85 C0 !jmp_dword :77EF75"}, {0x8B, 0x41, 0x58, 0x85, 0xC0})
		-- portrait GEOMETRY: CGameSprite::RenderPortrait sizes the image rect + HP bar by nScale=(bDoubleSize
		-- ?2:1). The menus pass bDoubleSize=FALSE (nScale=1) -> 1x portrait + tiny HP bar in a 2x slot
		-- (cropped/small). Force bDoubleSize=TRUE -> nScale=2 everywhere: 2x image rect (filled by the now-
		-- native 2x BMP) + 2x HP bar. Works in BOTH the world HUD and the pre-scaled-CHU menus (2x slots).
		IEex_HookRestore(0x704D40, 0, 7, {[[ C7 44 24 1C 01 00 00 00 ]]})   -- RenderPortrait bDoubleSize@[esp+0x1C]=1
		IEex_EnableCodeProtection()
	end

end)()
