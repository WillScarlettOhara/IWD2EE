
(function()

	IEex_DisableCodeProtection()

	------------------------------------------------------------------------------
	-- Enable the engine's native OpenGL renderer (CVideo3d) -------------------- --
	------------------------------------------------------------------------------
	-- CBaldurChitin's ctor at 0x4220ED does `mov [esi+0x91c],ebx` (ebx=0) ->
	-- m_cVideo.m_bIs3dAccelerated = FALSE -> CChitin::InitializeServices takes the
	-- SOFTWARE renderer (no GL context). Patch the modrm 0x9E->0xB6 so it becomes
	-- `mov [esi+0x91c],esi` (esi = this, always non-zero) -> the flag is truthy ->
	-- the Initialize3d() GL path runs. Done in-memory (survives an exe verify+repair,
	-- unlike the old on-disk exe byte patch). The engine's fragile fullscreen mode-switch
	-- is neutralized below (borderless), so this now works on native Windows and any
	-- Wine/Proton build (not just CachyOS). cnc-ddraw must be ABSENT (the GL path uses
	-- opengl32 directly, NOT the ddraw->GL software wrapper).
	--
	-- The gate below reads the STOCK ini key [Program Options] "3D Acceleration", which is now
	-- IEex-MANAGED: IEex_Gui_State.lua normalizes it EVERY launch (before any reader) from the
	-- player opt-out [IEex Options] "Software Renderer" (default 0 = GL on). Opt-out=1 -> the key
	-- is forced 0 -> this patch is SKIPPED and the engine stays on its stock software (DirectDraw)
	-- renderer, for anyone whose system has GL trouble. Self-consistent with the engine: retail
	-- HARDCODES m_bIs3dAccelerated=FALSE at the ctor (it does NOT read this key) and WRITES it
	-- back on shutdown from the runtime field (CBaldurChitin 0x4220ED read / 0x422xxx write) --
	-- the every-launch rewrite makes that round-trip harmless either way.
	-- Software mode forgoes every GL-track feature (HD UI / UI stretch / camera zoom / cursor +
	-- font scaling), which self-disable on the SAME key: IEex_Gui_State.lua (HD UI off),
	-- IEex_UIScale_Patch.lua + IEex_CameraZoom_Patch.lua + IEex_HDTiles_Patch.lua (no hooks).
	-- Default 1 = GL on (current behaviour, unchanged).
	if not IEex_Vanilla and IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") ~= 0 then
		IEex_WriteByte(0x4220EE, 0xB6)

		-- BORDERLESS FULLSCREEN. CVidInf::SetDisplayMode (0x7BDCE0, called only from the GL
		-- CVideo::Initialize3d fullscreen path) does a Win32 ChangeDisplaySettingsA(CDS_FULLSCREEN)
		-- mode-switch. Its mode-search filters on `dmDisplayFrequency <= CVideo::FPS`; when no
		-- enumerated mode matches SCREENWIDTH/HEIGHT (e.g. 3840x2160 only exists at 120/144Hz on a
		-- high-refresh desktop, all > FPS) iBestMode stays 0 -> it switches to display-mode 0
		-- (640x480) and the frame renders into a corner (and the desktop is left stuck at 640x480).
		-- The engine's fullscreen window is already a WS_POPUP sized to the screen and the GL
		-- renderer presents via opengl32 to that window, so the mode-switch is unnecessary. No-op
		-- the function (mov al,1 ; ret) -> "fullscreen" becomes a borderless window over the
		-- native-res desktop: native 4K, GL on, no fragile mode-switch (works on Windows + every
		-- Wine/Proton build, not just CachyOS). Borderless follows the desktop res, so the GL
		-- fullscreen res should equal the desktop res to fill the screen.
		-- HOST-GATED (2026-06-29): only no-op on NATIVE WINDOWS. The no-op turns "fullscreen" into
		-- a borderless desktop window, which is required on Windows (the GL mode-search picks
		-- 640x480 at 4K/high-refresh, see above) -- but a borderless fullscreen window does NOT
		-- release on alt-tab under Wine/Proton: returning to the game gives a permanent BLACK screen
		-- and TRAPS focus (you can never alt-tab back out, MangoHud also vanishes = zero presents).
		-- The engine's native SetDisplayMode mode-switch works fine on Wine/Proton (the 640x480 bug
		-- is Windows-only) AND survives alt-tab, so leave it intact there. Wine is detected by the
		-- presence of ntdll!wine_get_version (absent on real Windows -> GetProcAddress returns 0).
		-- WINDOWED MODE ("IEex Options" "Windowed"=1): also no-op on Wine -- a windowed run must NEVER
		-- mode-switch the desktop (the helper makes a normal titlebar window at the game res, leaving
		-- the desktop untouched). Without this the Wine path would ChangeDisplaySettings the whole
		-- desktop to the game res behind a small window.
		local windowed = IEex_GetPrivateProfileInt("IEex Options", "Windowed", 0, ".\\Icewind2.ini") ~= 0
		if windowed or IEex_GetProcAddress("ntdll.dll", "wine_get_version") == 0x0 then   -- native Windows OR windowed
			IEex_WriteByte(0x7BDCE0, 0xB0)   -- mov al, 1
			IEex_WriteByte(0x7BDCE1, 0x01)
			IEex_WriteByte(0x7BDCE2, 0xC3)   -- ret
		end

		-- FORCE MAX REFRESH for the GL fullscreen mode-switch (Wine/Proton, where SetDisplayMode runs).
		-- CVidInf::SetDisplayMode (0x7BDCE0) switches the desktop to the game resolution and picks the
		-- highest mode with dmDisplayFrequency <= CVideo::FPS (static @0x8BA318). CVideo::FPS DEFAULTS to
		-- 60 and is only raised to the panel max during DirectDraw init -- so if a mode-switch fires while
		-- it is still 60 (the intro-movie playback path triggers exactly this), the desktop is pinned to
		-- e.g. 1080p@60 for the WHOLE session and the frame limiter then caps ~58fps (desktop 4K@120 ->
		-- game 1080p@60 instead of @120). NOP the `ja` upper-refresh filter (@0x7BDD9D, bytes 77 08) so
		-- the search ignores CVideo::FPS and always selects the HIGHEST refresh for the game resolution
		-- (1080p@120). Harmless on native Windows (SetDisplayMode is no-op'd above -> never reached there).
		IEex_WriteAssembly(0x7BDD9D, {"!repeat(2,!nop)"})

		-- SUB-NATIVE BORDERLESS FILL. The borderless window is sized to the GAME resolution, so a
		-- resolution below the desktop only covers a corner. Intercept the SwapBuffers call inside
		-- CVidInf::WindowedFlip3d (@0x7BE520 = "call dword ptr [0xA0E170]", 6 bytes FF 15 70 E1 A0 00).
		-- By then the world+UI+cursor have rendered into our game-res FBO (bound at frame start in
		-- Export_BlankBackBuffer); the helper blit-scales that FBO to fill the full desktop window
		-- (letterboxed), then calls the real SwapBuffers. hDC is already pushed (push ecx @0x7BE51F),
		-- so the export is __stdcall(HDC). No-op passthrough at native res + vsync off ("Fill Screen"=0
		-- disables it entirely). Also taken at native res when vsync is on (single persistent buffer ->
		-- reduces the vsync UI flicker).
		IEex_WriteAssembly(0x7BE520, {[[
			!call >IEex_Helper_PresentScaled
			!nop
		]]})

	-----------------------------------------------------------------------------
	-- SAVE-GAME BMP CAPTURE UNDER THE FBO ------------------------------------- --
	-----------------------------------------------------------------------------
	-- CVidInf::PrintSurfaceToBmp (3D path @0x7BE5A0) grabs the framebuffer for the
	-- save screenshot (ICEWIND2.BMP) + party portraits (PORTRT0-5.BMP) via
	-- glReadBuffer(GL_BACK) @0x7BE805 then glReadPixels. Under the Fill-Screen FBO
	-- the bound framebuffer during the save capture is the FBO (FillBindForRender
	-- bound it at the CChitin::SynchronousUpdate frame start), where GL_BACK is
	-- invalid (GL_INVALID_OPERATION) -> glReadPixels writes nothing -> the buffer
	-- stays 0xFF -> PrintSurfaceToBmp's sentinel check discards it -> no BMP.
	-- Reroute the single `call ds:glReadBuffer` (6 bytes FF 15 C4 78 90 00) to a
	-- helper that picks GL_COLOR_ATTACHMENT0 (0x8CE1) when the FBO is active, else
	-- GL_BACK (0x405, stock). The only glReadBuffer call site in the binary -> no
	-- other path affected. NB: with Fill Screen=0 the helper passes GL_BACK
	-- through unchanged, so this is safe in both modes.
	IEex_WriteAssembly(0x7BE805, {[[
		!call >IEex_Helper_ReadBufferForSave
		!nop
	]]})

	-- Hook glReadPixels @0x7BE857 (6 bytes FF 15 C8 78 90 00). Under Wine, glReadPixels from the
	-- Fill-Screen FBO (a texture attachment) fails with GL_INVALID_OPERATION for every format, so
	-- the capture buffer stays 0xFF and PrintSurfaceToBmp discards it -> no BMP. The helper reads
	-- the FBO texture via glGetTexImage instead (bypassing the Wine quirk) when the FBO is active,
	-- else runs the stock glReadPixels. Pairs with the CheckResults3d fix below.
	IEex_WriteAssembly(0x7BE857, {[[
		!call >IEex_Helper_ReadPixelsForSave
		!nop
	]]})

		-----------------------------------------------------------------------------
		-- INTRO / CUTSCENE MOVIES UNDER THE GL RENDERER ------------------------- --
		-----------------------------------------------------------------------------
		-- BINK movies (BISLOGO/INTRO/MIDDLE/END/CREDITS) are played by CBaldurProjector,
		-- which blits each decoded frame straight into the DirectDraw back surface and
		-- Flip()s. That has no equivalent under the GL renderer, so the engine's own 2002
		-- guard makes CBaldurProjector::EngineActivated (0x43EC20) bail BEFORE BinkOpen
		-- whenever m_bIs3dAccelerated -> the movie is silently SKIPPED (no intro video at
		-- all in GL mode). Three patches, GL-only (this whole block is gated on the
		-- "3D Acceleration" key above, so the stock software movie path is untouched):
		--
		-- (1) EngineActivated guard: at 0x43ED02 `je 0x43ED21` is the "not 3d -> open the
		--     movie" branch; the fall-through (3d accelerated) reverts the engine without
		--     opening BINK. Force it to ALWAYS take the open path (je -> jmp short). The
		--     subsequent EraseScreen(BACK) is 3d-safe (returns FALSE when the DD surface
		--     is NULL, which it is under GL).
		IEex_WriteByte(0x43ED02, 0xEB)
		--
		-- (2) EngineDeactivated cleanup (0x43EED0): the BinkClose / pDimm->Resume / pointer
		--     re-enable block is gated `if (!m_bIs3dAccelerated)` -> skipped under GL, which
		--     would leave input + the cursor suspended (EngineActivated's Suspend now runs
		--     under GL too). NOP the `jne 0x43EFF5` skip so the cleanup ALWAYS runs (its
		--     EnterCriticalSection/LeaveCriticalSection stay balanced; BinkClose self-guards
		--     on m_hBink != NULL).
		IEex_WriteAssembly(0x43EF47, {"!repeat(6,!nop)"})
		--
		-- (3) RenderBinkFrame (0x43E300) full replacement -> decode the frame, upload it to
		--     a GL texture and draw it through the same FBO present path the world renderer
		--     uses (Export_RenderBinkFrameGL). __thiscall(this, HBINK): marshal (this, bnk)
		--     to the __stdcall export and clean the 1 stack arg (ret 4).
		IEex_WriteAssembly(0x43E300, {[[
			!mark_esp
			!marked_esp !push([esp+0x04])
			!push_ecx
			!call >IEex_Helper_RenderBinkFrameGL
			!ret_word 04 00
		]]})

		-----------------------------------------------------------------------------
		-- SPRITE PER-CELL TINT UNDER GL (lightmap / infravision / fades) -------- --
		-----------------------------------------------------------------------------
		-- CInfinity::FXRender (0x5CE280) only ORs blit flag 0x20000 ("apply the cell's
		-- m_paletteAffects.rgbTintColor during the palette realize") when NOT
		-- 3d-accelerated:
		--   0x5CE2F2  mov eax,[ecx+0x91C]   ; m_bIs3dAccelerated
		--   0x5CE2F8  test eax,eax
		--   0x5CE2FA  jne 0x5CE308          ; GL -> skip `or ebx,0x20000`
		-- That flag carries everything routed through the per-cell tint colour: the
		-- area lightmap sampled at the sprite's feet (LM/LN bmp, CGameArea::
		-- GetTintColor), creature darkening at night in extended-night (night-WED)
		-- areas, the infravision grey (200,200,200) when a darkvision party member is
		-- out at full night, and area-transition fades on sprites. The fullscreen
		-- RenderTint3d multiply never covers sprites (it fires at the end of
		-- CInfinity::Render and at the tile-atlas flush, both BEFORE sprites draw), so
		-- under GL all of the above was silently dropped -- at full night characters
		-- rendered full-bright daylight. The GL realize paths (RealizeResource3d
		-- 0x7D6240 / RealizeRange3d 0x7D6900 -> shared CVidPalette::GetTint 0x7BF430)
		-- already handle 0x20000; only this gate withheld the flag. NOP the jne so GL
		-- takes the same OR the software renderer takes (software is unchanged: with
		-- m_bIs3dAccelerated==0 the jne was never taken). The 0x10000 global-tint
		-- night blue (plain outdoor areas) is untouched -- FXRender only reaches this
		-- OR when 0x10000 is absent.
		IEex_WriteAssembly(0x5CE2FA, {"!repeat(2,!nop)"})

		-- TINT PROBE (diagnostic, TEMPORARY -- delete together with Export_TintProbe
		-- in the DLL once the GL night-tint report is resolved). Logs the flags +
		-- tint inputs FXRender ends up with to <game>\tint_probe.log (on-change,
		-- 100ms floor, 400-line cap). Hooked right after the un-gated
		-- `or ebx,0x20000` block: ebx = final dwFlags, ebp = pVidCell; the replaced
		-- 6-byte `mov eax,[ecx+0x3c4]` is re-run by the trampoline after the stub.
		-- [IEex Options] "Tint Probe"=0 disables (default on).
		IEex_HookRestore(0x5CE308, 0, 6, {[[
			!push_all_registers_iwd2
			!push(ebx)
			!push(ebp)
			!call >IEex_Helper_TintProbe
			!pop_all_registers_iwd2
		]]})
	end

	--------------------------------------------------------------------------
	-- wined3d.dll + WINEDEBUG environment variable should log debug output --
	--------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookAfterCall(0x7952FB, IEex_FlattenTable({[[
			!push_all_registers_iwd2
			]], IEex_GenLuaCall("IEex_Extern_AfterDirectDrawCreate"), [[
			@call_error
			!pop_all_registers_iwd2
		]]}))
	end

	----------------------------------
	-- Transparent Fog of War Hooks --
	----------------------------------

	if not IEex_Vanilla then

		local optionsStr = IEex_WriteStringAuto("IEex_Options")

		local getFogTypePtr = IEex_WriteAssemblyAuto({[[
			!push_ecx
			!push_edx
			!push_dword ]], {optionsStr, 4}, [[
			!call >IEex_Helper_LockGlobal
			!push_[dword] ]], {IEex_FogTypePtr, 4}, [[
			!push_dword ]], {optionsStr, 4}, [[
			!call >IEex_Helper_UnlockGlobal
			!pop_eax
			!pop_edx
			!pop_ecx
			!ret
		]]})

		-- Install new solid FoW rendering
		IEex_HookRestore(0x551FF0, 0, 5, {[[
			!call ]], {getFogTypePtr, 4, 4}, [[
			!cmp_[eax]_byte 00
			!jnz_dword >IEex_Helper_RenderFoWSolid
		]]})

		-- Install new transparent FoW rendering
		IEex_HookBeforeCall(0x477B61, {[[
			!call ]], {getFogTypePtr, 4, 4}, [[
			!cmp_[eax]_byte 00
			!jz_dword >no_hook
			!push_ecx
			!push_esi
			!call >IEex_Helper_RenderFoW
			!pop_ecx
			@no_hook
		]]})

		-- Toggle common FoW interlacing for sprites
		local spriteInterlaceHook = IEex_WriteAssemblyAuto({[[
			!mark_esp
			!push(eax)
			!call ]], {getFogTypePtr, 4, 4}, [[
			!cmp_[eax]_byte 00
			!jz_dword >no_hook
			!marked_esp !mov([esp+2C],0)
			@no_hook
			!pop(eax)
			!ret
		]]})

		for _, address in ipairs({0x56ECD3, 0x61DF8F, 0x62ED48, 0x7040AA, 0x704235, 0x70F4D9, 0x70FCDB, 0x710539}) do
			IEex_HookRestore(address, 0, 6, {"!call", {spriteInterlaceHook, 4, 4}})
		end

		-- Sprite textures are created with GL_NEAREST but the engine never sets a wrap mode, so they
		-- default to GL_REPEAT. At some sub-pixel positions the u=1 / v=1 edge wraps onto u=0 / v=0,
		-- drawing a 1px seam line around the sprite (rare, frame-dependent; a tester caught a vertical
		-- one in combat). Force CLAMP_TO_EDGE on WRAP_S + WRAP_T right after the engine's
		-- MIN_FILTER=NEAREST call in each of the three sprite draw paths. Use glTexParameterF (ds:0x9079CC,
		-- param passed as a float: 33071.0 = 0x47012F00), NOT glTexParameterI (ds:0x9079D4): the engine only
		-- ever calls ...f (to set NEAREST, just above each hook), so the ...i pointer is never resolved and is
		-- NULL on native Windows -- calling it crashed at the main menu (BKRender sprite draw). Wine happens to
		-- fill ...i in, which hid it. glTexParameterf(TEXTURE_2D=0xDE1, WRAP_S=0x2802 / _T=0x2803, CLAMP=33071.0f).
		local spriteTexClampStub = IEex_WriteAssemblyAuto({[[
			!push_all_registers_iwd2
			68 00 2F 01 47
			68 02 28 00 00
			68 E1 0D 00 00
			FF 15 CC 79 90 00
			68 00 2F 01 47
			68 03 28 00 00
			68 E1 0D 00 00
			FF 15 CC 79 90 00
			!pop_all_registers_iwd2
			!ret
		]]})
		IEex_HookRestore(0x7C54ED, 0, 5, {"!call", {spriteTexClampStub, 4, 4}})   -- CVidCell::FXRender3d @0x7C5330
		IEex_HookRestore(0x7C4BE0, 0, 6, {"!call", {spriteTexClampStub, 4, 4}})   -- CVidCell::Render3d @0x7C4A90
		IEex_HookRestore(0x7C4F3D, 0, 6, {"!call", {spriteTexClampStub, 4, 4}})   -- CVidCell::Render3d @0x7C4E20

		-- Toggle FoW interlacing for ground piles
		IEex_HookJump(0x47FA0D, 4, {[[
			!call ]], {getFogTypePtr, 4, 4}, [[
			!cmp_[eax]_byte 00
			!jnz_dword >jmp_success
			!mov_al_[esp+byte] 12
			!test_al_al
		]]})
	end

	--------------------------------------------------------------
	-- Don't crash when attempting to dither a sprite           --
	-- effect on a creature with a large posZ                   --
	-- (engine failed to calculate rClip correctly, subtracting --
	--  posZ out of rClip.bottom when it should keep it)        --
	--------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_WriteAssembly(0x709AA7, {"!repeat(3,!nop)"})
	end

	-----------------------------------------------------------------------------------------
	-- Disable engine's default windowed mode under cnc-ddraw. When the engine attempts to --
	-- toggle the window mode, send cnc-ddraw the correct WindowProc message and suppress  --
	-- the default toggle behavior.                                                        --
	-----------------------------------------------------------------------------------------

		-----------------------------------------------------------------
		-- Detect cnc-ddraw and force fullscreen mode if it is present --
		-----------------------------------------------------------------

		IEex_HookReturnNOPs(0x422092, 3, IEex_FlattenTable({
			{[[
				!push_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_CheckForceFullscreen", {
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor(eax,eax)

				@no_error
				!pop_registers_iwd2
				!test(eax,eax)
				!jz_dword >do_call

				!add(esp,10)
				!jmp_dword >skip_call

				@do_call
				!call_ebp

				@skip_call
				!mov_byte:[esi+dword]_al #E1
			]]},
		}))

		----------------------------------------------------------------------
		-- Suppress the default window mode toggle behavior under cnc-ddraw --
		-- and send cnc-ddraw the correct WindowProc message                --
		----------------------------------------------------------------------

		IEex_HookRestore(0x7912F0, 0, 6, IEex_FlattenTable({
			{[[
				!push_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_CheckSuppressToggleFullscreen", {
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor(eax,eax)

				@no_error
				!pop_registers_iwd2
				!test(eax,eax)
				!jz_dword >return

				!ret_word 04 00
			]]},
		}))

		----------------------------------------------------------------------------
		-- Make the options screen report the correct window mode under cnc-ddraw --
		----------------------------------------------------------------------------

		IEex_HookBeforeCall(0x655E95, IEex_FlattenTable({
			{[[
				!push_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_CheckOverrideOptionsScreenThinksGameIsFullScreen", {
				["returnType"] = IEex_LuaCallReturnType.Number,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!mov(eax,-1)

				@no_error
				!pop_registers_iwd2
				!cmp(eax,-1)
				!je_dword >call

				!mov([esp],eax)
			]]},
		}))

		IEex_HookReturnNOPs(0x6558E2, 3, IEex_FlattenTable({
			{[[
				!push(eax)
				!push(ebx)
				!push(edx)
				!push(ebp)
				!push(esi)
				!push(edi)
			]]},
			IEex_GenLuaCall("IEex_Extern_CheckOverrideOptionsScreenThinksGameIsFullScreen", {
				["returnType"] = IEex_LuaCallReturnType.Number,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!mov(eax,-1)

				@no_error
				!xor(ecx,ecx)
				!cmp(eax,-1)
				!je_dword >continue_normally

				!mov_cl_al
				!pop(edi)
				!pop(esi)
				!pop(ebp)
				!pop(edx)
				!pop(ebx)
				!pop(eax)
				!jmp_dword >return

				@continue_normally
				!pop(edi)
				!pop(esi)
				!pop(ebp)
				!pop(edx)
				!pop(ebx)
				!pop(eax)
				!mov_cl_byte:[edx+dword] #E1
			]]},
		}))

		--------------------------------------------------------------------------------------
		-- Force the options screen to request windowed mode when it attempts to toggle the --
		-- mode under cnc-ddraw. Since the engine permanently thinks it is in fullscreen    --
		-- mode under cnc-ddraw, in order to trigger the toggle behavior the engine must    --
		-- attempt to enter windowed mode.                                                  --
		--------------------------------------------------------------------------------------

		IEex_HookRestore(0x6558FD, 0, 6, IEex_FlattenTable({
			{[[
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_CheckForceOptionsScreenToRequestWindowedMode", {
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor(eax,eax)

				@no_error
				!test(eax,eax)
				!pop_all_registers_iwd2
				!jz_dword >return

				!mov_al 00
			]]},
		}))

	------------------------------------------------------------------------------
	-- Decrease the maximum time it takes for a creature to become visible from --
	-- 6 AI updates (~400 milliseconds) to 1 AI update (~66.6 milliseconds)     --
	------------------------------------------------------------------------------

	if not IEex_Vanilla then

		IEex_DisableRDataProtection()

		-- CGameObject::VISIBLE_DELAY
		IEex_WriteByte(0x84C50F, 1)
		IEex_EnableRDataProtection()
	end

	---------------------------------------------------------
	-- Highlight empty containers in gray instead of green --
	---------------------------------------------------------

	if not IEex_Vanilla then

		local callHook = IEex_WriteAssemblyAuto(IEex_FlattenTable({
			{[[
				!mark_esp
				!push_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_OverrideContainerHighlightColor", {
				["args"] = {
					{"!push(esi)"},
					{"!marked_esp !push([esp+0x4])"},
					{[[
						!marked_esp !lea(eax,[esp+0x14])
						!push(eax)
					]]},
				},
			}),
			{[[
				@call_error
				!pop_registers_iwd2
				!ret_word 04 00
			]]},
		}))

		-- GL-native translucent FILL for the highlight polygons. The engine draws the
		-- highlight as OUTLINE (CInfinity::OutlinePoly @0x5CECD0) + a translucent FILL
		-- (CGame*::RenderClippedPoly), but the FILL is gated OFF in 3D at every call site
		-- (`TRANSLUCENT_BLTS_ON && !Is3dAccelerated()`) because the FX fill path is
		-- software-only (CVidInf::FXPrep's 3D branch can't COPYFROMBACK). So under the GL
		-- renderer doors/containers/triggers highlight as outline-only and lootables are
		-- hard to spot. IEex_Helper_CInfinity_FillHighlightPoly3d redraws the fill GPU-side.
		-- It is hooked immediately BEFORE each OutlinePoly call, so it reuses the exact same
		-- polygon + colour the outline is about to use -- including the empty-container gray
		-- override callHook applies just above, so the fill colour tracks it automatically.
		-- 3D only: in software the engine's own fill already runs (don't double-fill / no GL).
		-- fillBlock duplicates OutlinePoly's 4 stack args (pPoly,nVerts,rClip,colour; colour
		-- at [esp+0xC]) and forwards them __thiscall (ecx = pInfinity, untouched) to the
		-- export, which cleans them (ret 0x10). push_all_registers_iwd2 = 7 regs (0x1C), so
		-- the args sit at [esp+0x28] after it; ecx is saved/restored across, intact for the
		-- engine's own OutlinePoly call that HookBeforeCall appends afterwards.
		local is3D = IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") ~= 0
		local fillBlock = {[[
			!push_all_registers_iwd2
			!push([esp+0x28])
			!push([esp+0x28])
			!push([esp+0x28])
			!push([esp+0x28])
			!call >IEex_Helper_CInfinity_FillHighlightPoly3d
			!pop_all_registers_iwd2
		]]}

		IEex_HookRestore(0x47FB41, 0, 6, {"!push_byte 00 !call", {callHook, 4, 4}}) -- Normal mouse hover - Fill (software)
		IEex_HookBeforeCall(0x47FB76, IEex_FlattenTable({                            -- Normal mouse hover - Outline (+ GL fill)
			{"!push_byte 00 !call", {callHook, 4, 4}},
			is3D and fillBlock or {},
		}))

		IEex_HookRestore(0x47FC2A, 0, 6, {"!push_byte 01 !call", {callHook, 4, 4}}) -- Bash - Fill (software)

		IEex_HookRestore(0x47FD1C, 0, 6, {"!push_byte 02 !call", {callHook, 4, 4}}) -- Alt Down - Fill (software)
		IEex_HookBeforeCall(0x47FD52, IEex_FlattenTable({                            -- Alt down - Outline (+ GL fill)
			{"!push_byte 02 !call", {callHook, 4, 4}},
			is3D and fillBlock or {},
		}))

		-- Remaining OutlinePoly highlight sites that have a (GL-missing) software fill but
		-- no colour-override hook: container script-flash (red), every door state (open/
		-- closed x hover/bash/trap/flash), and triggers / info-points. GL fill only.
		if is3D then
			IEex_HookBeforeCall(0x47FDF2, fillBlock) -- Container - script-flash (red) Outline
			for _, addr in ipairs({0x488CA3, 0x488D34, 0x488E76, 0x488F1C, 0x48929D}) do
				IEex_HookBeforeCall(addr, fillBlock) -- Door highlight Outlines
			end
			IEex_HookBeforeCall(0x4CFC10, fillBlock) -- Trigger / info-point Outline
		end

		-- Translucent-black readability PANEL behind floating in-world text (CGameText,
		-- the INFOFONT damage/feedback strings). Software composites float-text through the
		-- FX scratch with FXPREP_COPYFROMBACK -> a semi-transparent panel sized to the text;
		-- FXPrep's 3D branch never copies-from-back, so in GL the panel is gone and white text
		-- is hard to read over bright terrain. IEex_Helper_CInfinity_FillTextBackdrop3d edits
		-- the FX staging buffer (CVideo3d::texImageData) directly -- fills translucent black
		-- over the rasterised glyphs' bounding box -- so the single existing FXBltFrom blits
		-- text + panel together (auto-sized, no extra GL draw, no GL-state change). 3D only.
		--
		-- Hooked at the single CGameText::Render FXBltFrom call (0x4CC0AF), AFTER FXTextOut has
		-- rasterised the glyphs into the scratch. NOT the shared FXBltFrom/FXPrep function --
		-- that path also blits translucent SPRITES, which must not get a panel. backdropBlock
		-- duplicates FXBltFrom's 7 stack args (last, dwFlags, at [esp+0x18] before push_all ->
		-- [esp+0x34] after the 0x1C push_all) and forwards them __thiscall (ecx = pInfinity,
		-- preserved across push/pop_all for the engine's own FXBltFrom that follows). The export
		-- cleans them (ret 0x1C); re-reading [esp+0x34] each push walks down the 7 args.
		if is3D then
			local backdropBlock = {[[
				!push_all_registers_iwd2
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!call >IEex_Helper_CInfinity_FillTextBackdrop3d
				!pop_all_registers_iwd2
			]]}
			IEex_HookBeforeCall(0x4CC0AF, backdropBlock) -- CGameText::Render - floating-text readability panel (+ engine FXBltFrom)
		end

		-- GL-native lightning bolt. CInfinity::RenderLightning (@0x5CFB40) draws the
		-- Call-Lightning / storm-strike bolt as 12 CVidMode::PolyLine passes (4 jagged
		-- segments x outer/middle/center thickness), but PolyLine (@0x79A080) is
		-- software-only (LockSurface + DrawLine32, no 3d branch) -> under GL the bolt
		-- never shows: thunder + global flash only. RenderLightning is PolyLine's ONLY
		-- caller (all 12 callsites, binary-verified), so on 3D installs replace the
		-- function entry outright with the GL quad-based draw; software installs keep
		-- the stock path untouched. __thiscall(nSurface, CRect&, LPPOINT, nCount,
		-- COLORREF, nThickness) ret 0x18 -> forward the last 4 args to the __stdcall
		-- export (ret 0x10): after the 0x1C push_all, thickness sits at [esp+0x34] and
		-- each push shifts esp so re-reading [esp+0x34] walks rgb, nCount, lpPoints --
		-- pushed right-to-left as the export expects. eax=1 = the BOOL success return.
		if is3D then
			IEex_WriteAssembly(0x79A080, {"!jmp_dword", {IEex_WriteAssemblyAuto({[[
				!push_all_registers_iwd2
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!push([esp+0x34])
				!call >IEex_Helper_LightningPolyLine3d
				!pop_all_registers_iwd2
				!mov_eax #01
				!ret_word 18 00
			]]}), 4, 4}})
		end
	end

	------------------------------------------------------------------------------
	-- PERF: neutralize CVidMode::CheckResults3d (the per-GL-call debug check) -- --
	------------------------------------------------------------------------------
	-- 0x7BEA80 __thiscall BOOL CVidMode::CheckResults3d(int rc). The engine calls
	-- it after EVERY immediate-mode GL call in the hot render paths (tile/cell/MOS
	-- /fog) -- thousands of times per frame at 4K. It only calls glGetError when
	-- rc != 0, and EVERY render-path caller passes 0, so the error scan never runs;
	-- even on a real error it only Format()s a CString that is then DISCARDED (never
	-- logged). So it is a no-op debug hook = pure dead per-call overhead. Patch the
	-- entry to `mov eax,1 ; ret 4` (return TRUE / 1: no error) so the
	-- thiscall cleans its one 4-byte arg and callers that gate on the BOOL (notably
	-- CVidInf::PrintSurfaceToBmp @0x7BE866, which frees the capture buffer + returns
	-- FALSE when CheckResults3d returns 0 -> no save BMP) see success. Returning 1
	-- matches the real fn's no-error path (it sets esi=1 then returns it). Zero
	-- render effect (callers in the hot paths pass rc=0 and ignore the BOOL anyway).
	-- MEASURED (scripts/perf): removes its own ~0.5% self-time; net fps change
	-- negligible -- the frame is bound by the nvidia-glcore driver (per-tile
	-- bind+draw), not by these CPU-side checks. Kept as correct dead-code removal.
	-- (The ~4% CString::~CString in the profile is NOT from here -- it is resource-
	-- name loading via CDimm::Local*Resource.)
	if not IEex_Vanilla then
		IEex_WriteAssembly(0x7BEA80, {"!mov(eax,1) !ret_word 04 00"})
	end

	-- NOTE: an experiment that also NOP'd the redundant per-tile glTexParameterf
	-- (MIN/MAG = NEAREST, already set per-texture at upload) in CVidTile::RenderTexture
	-- @0x7C65A2/0x7C65D7 was measured to give ZERO perf change (scripts/perf): the
	-- ~30% nvidia-glcore cost is the per-tile glBindTexture + textured-quad draw, NOT
	-- the cheap state calls -- consistent with the failed geometry-batching attempts.
	-- Reverted (no win, slight blur risk). Only a tile texture atlas could cut the binds.

	-- (The IEex_Test* console helpers live in IEex_IWD2_State.lua: _Patch files run
	-- in the startup patching pass, not in the runtime Lua state the console
	-- evaluates in -- functions defined here are nil by the time the console runs.)

	IEex_EnableCodeProtection()

end)()
