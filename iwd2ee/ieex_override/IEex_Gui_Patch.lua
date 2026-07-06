
(function()

	IEex_DisableCodeProtection()


	local activeContainerIDFuncName = IEex_WriteStringAuto("IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerID")
	local activeContainerSpriteIDFuncName = IEex_WriteStringAuto("IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerSpriteID")
	local containerItemIndexFuncName = IEex_WriteStringAuto("IEex_Extern_CUIControlButtonWorldContainerSlot_GetContainerItemIndex")
	local onlyUpdateSlotFuncName = IEex_WriteStringAuto("IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot")

	----------------------------------------------
	-- IEex_Extern_CUIControlBase_CreateControl --
	----------------------------------------------

	if not IEex_Vanilla then

		IEex_HookJump(0x76D41B, 0, IEex_FlattenTable({
			{[[
				!push_registers_iwd2

				!xor_ebx_ebx
				!jnz_dword >original_fail
				!mov_ebx #1

				@original_fail
			]]},
			IEex_GenLuaCall("IEex_Extern_CUIControlBase_CreateControl", {
				["args"] = {
					{"!push(edx)"}, -- CHU resref
					{"!push(edi)"}, -- panel
					{"!push(esi)"}, -- controlInfo
				},
				["returnType"] = IEex_LuaCallReturnType.Number,
			}),
			{[[
				@call_error
				!test_eax_eax
				!jz_dword >not_custom
				!pop_registers_iwd2
				!jmp_dword :76E93F

				@not_custom
				!test_ebx_ebx
				!pop_registers_iwd2
				!jnz_dword >jmp_success
				!jmp_dword >jmp_fail
			]]},
		}))
	end

	-------------------------------------------------
	-- IEex_Extern_CUIManager_fInit_CHUInitialized --
	-------------------------------------------------

	IEex_HookBeforeCall(0x4D3D55, IEex_FlattenTable({
		{"!push_all_registers_iwd2"},
		IEex_GenLuaCall("IEex_Extern_CUIManager_fInit_CHUInitialized", {
			["args"] = {
				{"!push(esi)"},
				{"!push([ecx+10])"},
			},
		}),
		{[[
			@call_error
			!pop_all_registers_iwd2
		]]},
	}))

	-------------------------------------------------------------------------------------
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot --
	-------------------------------------------------------------------------------------

	IEex_WriteAssemblyAuto({[[

		$IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot
		!push_state

		!push_dword ]], {onlyUpdateSlotFuncName, 4}, [[
		!push_dword *_g_lua_async
		!call >_lua_getglobal
		!add_esp_byte 08

		; arg ;
		!push_[ebp+byte] 08
		!fild_[esp]
		!sub_esp_byte 04
		!fstp_qword:[esp]
		!push_dword *_g_lua_async
		!call >_lua_pushnumber
		!add_esp_byte 0C

		!push_byte 00
		!push_byte 01
		!push_byte 01
		!push_dword *_g_lua_async
		!call >_lua_pcall
		!add_esp_byte 10
		!push_dword *_g_lua_async
		!call >IEex_CheckCallError
		!jz_dword >ok
		!xor_eax_eax
		!jmp_dword >error

		@ok
		!push_byte FF
		!push_dword *_g_lua_async
		!call >_lua_toboolean
		!add_esp_byte 08
		!push_eax
		!push_byte FE
		!push_dword *_g_lua_async
		!call >_lua_settop
		!add_esp_byte 08
		!pop_eax

		@error
		!pop_state
		!ret_word 04 00
	]]})

	-------------------------------------------------------------------------------------
	-- CUIControlScrollBarWorldContainer_UpdateScrollBar                               --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot --
	-------------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookBeforeCall(0x695C8E, {[[
			!push_[esp+byte] 18
			!call >IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot
			!test_eax_eax
			!jnz_dword >return
		]]})
	end

	-------------------------------------------------------------------------------------
	-- CUIControlEncumbrance_SetVolume                                                 --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot --
	-------------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookBeforeCall(0x696080, {[[
			!push_[esp+byte] 20
			!call >IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot
			!test_eax_eax
			!jz_dword >call
			!add_esp_byte 08
			!jmp_dword >return
		]]})
	end

	-------------------------------------------------------------------------------------
	-- CUIControlEncumbrance_SetEncumbrance                                            --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot --
	-------------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookBeforeCall(0x69608D, {[[
			!push_[esp+byte] 20
			!call >IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot
			!test_eax_eax
			!jz_dword >call
			!add_esp_byte 08
			!jmp_dword >return
		]]})
	end

	-------------------------------------------------------------------------------------
	-- CUIControlLabel_SetText                                                         --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot --
	-------------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookBeforeCall(0x6960EE, {[[
			!push_[esp+byte] 1C
			!call >IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_GetOnlyUpdateSlot
			!test_eax_eax
			!jz_dword >call
			!add_esp_byte 04
			!jmp_dword >return
		]]})
	end

	---------------------
	-- push lua_State* --
	-- push func_name  --
	-- push arg        --
	---------------------
	IEex_WriteAssemblyAuto({[[

		$IEex_CallIntsOneArgOneReturn
		!push_state

		!push_[ebp+byte] 0C
		!push_[ebp+byte] 10
		!call >_lua_getglobal
		!add_esp_byte 08

		; arg ;
		!push_[ebp+byte] 08
		!fild_[esp]
		!sub_esp_byte 04
		!fstp_qword:[esp]
		!push_[ebp+byte] 10
		!call >_lua_pushnumber
		!add_esp_byte 0C

		!push_byte 00
		!push_byte 01
		!push_byte 01
		!push_[ebp+byte] 10
		!call >_lua_pcall
		!add_esp_byte 10
		!push_[ebp+byte] 10
		!call >IEex_CheckCallError
		!jz_dword >ok
		!mov_eax #FFFFFFFF
		!jmp_dword >error

		@ok
		!push_byte FF
		!push_[ebp+byte] 10
		!call >_lua_tonumber
		!add_esp_byte 08
		!call >__ftol2_sse
		!push_eax
		!push_byte FE
		!push_[ebp+byte] 10
		!call >_lua_settop
		!add_esp_byte 08
		!pop_eax

		@error
		!pop_state
		!ret_word 0C 00
	]]})

	-------------------------------------------------------------------------
	-- OnLButtonClick - activeContainerID                                  --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerID --
	-------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookRestore(0x69589C, 0, 6, {[[
			!push_dword *_g_lua_async
			!push_dword ]], {activeContainerIDFuncName, 4}, [[
			!push_[esp+byte] 20
			!call >IEex_CallIntsOneArgOneReturn
			!cmp_eax_byte FF
			!jne_dword >return_skip
		]]})
	end

	-------------------------------------------------------------------------------
	-- OnLButtonClick - activeContainerSpriteID                                  --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerSpriteID --
	-------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookRestore(0x6958C7, 0, 6, {[[
			!push_dword *_g_lua_async
			!push_dword ]], {activeContainerSpriteIDFuncName, 4}, [[
			!push_[esp+byte] 20
			!call >IEex_CallIntsOneArgOneReturn
			!mov_esi_eax
			!cmp_eax_byte FF
			!jne_dword >return_skip
		]]})
	end

	--------------------------------------------------------------------------
	-- OnLButtonClick - m_nTopContainerRow                                  --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_GetContainerItemIndex --
	--------------------------------------------------------------------------

	if not IEex_Vanilla then

		IEex_HookRestore(0x6959A3, 0, 8, {[[

			; save eax because I clobber it ;
			!push_eax

			!push_dword *_g_lua_async
			!push_dword ]], {containerItemIndexFuncName, 4}, [[
			!push_[esp+byte] 24
			!call >IEex_CallIntsOneArgOneReturn
			!cmp_eax_byte FF

			!jne_dword >override
			; restore eax ;
			!pop_eax
			!jmp_dword >return

			@override
			!mov_edi_eax
			; clear eax off of stack (only matters when running normal code) ;
			!add_esp_byte 04
			!mov_[esp+byte]_edi 34
			!jmp_dword >return_skip
		]]})
	end

	-------------------------------------------------------------------------------
	-- Render - activeContainerSpriteID                                          --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerSpriteID --
	-------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookRestore(0x696208, 0, 6, {[[
			!push_dword *_g_lua
			!push_dword ]], {activeContainerSpriteIDFuncName, 4}, [[
			!push_esi
			!call >IEex_CallIntsOneArgOneReturn
			!cmp_eax_byte FF
			!jne_dword >return_skip
		]]})
	end

	-------------------------------------------------------------------------
	-- Render - activeContainerID                                          --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_GetActiveContainerID --
	-------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookRestore(0x69623F, 0, 6, {[[
			!push_dword *_g_lua
			!push_dword ]], {activeContainerIDFuncName, 4}, [[
			!push_esi
			!call >IEex_CallIntsOneArgOneReturn
			!mov_ebx_eax
			!cmp_eax_byte FF
			!jne_dword >return_skip
		]]})
	end

	--------------------------------------------------------------------------
	-- Render - m_nTopContainerRow                                          --
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_GetContainerItemIndex --
	--------------------------------------------------------------------------

	if not IEex_Vanilla then

		IEex_HookRestore(0x69627D, 0, 8, {[[

			; save eax because I clobber it ;
			!push_eax

			!push_dword *_g_lua
			!push_dword ]], {containerItemIndexFuncName, 4}, [[
			!push_esi
			!call >IEex_CallIntsOneArgOneReturn
			!cmp_eax_byte FF
			!jne_dword >override

			; restore eax ;
			!pop_eax
			!jmp_dword >return

			@override
			; clear eax off of stack (I'm overriding it) ;
			!add_esp_byte 04
			!lea_ecx_[esp+byte] 2C
			!mov_[esp+byte]_edi 34
			!jmp_dword >return_skip
		]]})
	end

	------------------------------------------------------------------------
	-- IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_Done --
	------------------------------------------------------------------------

	if not IEex_Vanilla then

		IEex_HookRestore(0x696107, 0, 7, {[[

			!push_complete_state

			!push_dword ]], {IEex_WriteStringAuto("IEex_Extern_CUIControlButtonWorldContainerSlot_OnLButtonClick_Done"), 4}, [[
			!push_dword *_g_lua_async
			!call >_lua_getglobal
			!add_esp_byte 08

			; control ;
			!push_[ebp+byte] 08
			!fild_[esp]
			!sub_esp_byte 04
			!fstp_qword:[esp]
			!push_dword *_g_lua_async
			!call >_lua_pushnumber
			!add_esp_byte 0C

			!push_byte 00
			!push_byte 01
			!push_byte 01
			!push_dword *_g_lua_async
			!call >_lua_pcall
			!add_esp_byte 10
			!push_dword *_g_lua_async
			!call >IEex_CheckCallError

			!pop_complete_state
		]]})
	end

	-------------------------------------------------
	-- IEex_Extern_CScreenWorld_AsynchronousUpdate --
	-------------------------------------------------

	if not IEex_Vanilla then

		IEex_HookRestore(0x68C3D0, 0, 7, {[[

			!push_all_registers_iwd2

			!push_dword ]], {IEex_WriteStringAuto("IEex_Extern_CScreenWorld_AsynchronousUpdate"), 4}, [[
			!push_dword *_g_lua_async
			!call >_lua_getglobal
			!add_esp_byte 08

			!push_byte 00
			!push_byte 00
			!push_byte 00
			!push_dword *_g_lua_async
			!call >_lua_pcall
			!add_esp_byte 10
			!push_dword *_g_lua_async
			!call >IEex_CheckCallError

			!pop_all_registers_iwd2
		]]})
	end

	------------------------------------------------------
	-- IEex_Extern_CScreenWorld_OnInventoryButtonRClick --
	------------------------------------------------------

	if not IEex_Vanilla then

		IEex_WriteDword(0x85D798, IEex_WriteAssemblyAuto({[[

			!push_all_registers_iwd2

			!push_dword ]], {IEex_WriteStringAuto("IEex_Extern_CScreenWorld_OnInventoryButtonRClick"), 4}, [[
			!push_dword *_g_lua_async
			!call >_lua_getglobal
			!add_esp_byte 08

			!push_byte 00
			!push_byte 00
			!push_byte 00
			!push_dword *_g_lua_async
			!call >_lua_pcall
			!add_esp_byte 10
			!push_dword *_g_lua_async
			!call >IEex_CheckCallError

			!pop_all_registers_iwd2
			!ret_word 08 00
		]]}))
	end

	-----------------------------------------
	-- IEex_Extern_GetHighlightContainerID --
	-----------------------------------------

	if not IEex_Vanilla then

		IEex_HookAfterRestore(0x47F954, 0, 5, {[[

			!test_eax_eax
			!jnz_dword >return

			!push_registers_iwd2

			!call >IEex_GetLuaState
			!mov_ebx_eax

			!push_dword ]], {IEex_WriteStringAuto("IEex_Extern_GetHighlightContainerID"), 4}, [[
			!push_ebx
			!call >_lua_getglobal
			!add_esp_byte 08

			!push_byte 00
			!push_byte 01
			!push_byte 00
			!push_ebx
			!call >_lua_pcall
			!add_esp_byte 10
			!push_ebx
			!call >IEex_CheckCallError

			!push_byte FF
			!push_ebx
			!call >_lua_tonumber
			!add_esp_byte 08
			!call >__ftol2_sse
			!push_eax
			!push_byte FE
			!push_ebx
			!call >_lua_settop
			!add_esp_byte 08
			!pop_edx

			!xor_eax_eax
			!cmp_edx_[esi+byte] 5C
			!jne_dword >no_highlight
			!mov_eax #1

			@no_highlight
			!pop_registers_iwd2
		]]})
	end

	------------------------------------------------------------------------------
	-- Redirect empty CUIControlButtonWorldContainerSlot_OnLButtonDoubleClick() --
	-- to CUIControlButtonWorldContainerSlot_OnLButtonDown().                   --
	-- Prevents double-click cooldown.                                          --
	------------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_WriteDword(0x85A3E4, 0x66D760)
	end

	-------------------------------------------
	-- IEex_Extern_OnUpdateRecordDescription --
	-------------------------------------------

	if not IEex_Vanilla then
		IEex_HookBeforeCall(0x5DC792, IEex_FlattenTable({[[
			!mark_esp(50)
			!push_all_registers_iwd2
			]], IEex_GenLuaCall("IEex_Extern_OnUpdateRecordDescription", {
				["args"] = {
					{"!push(esi)"},
					{"!push_using_marked_esp([esp-3C])"},
					{"!push(ebx)"},
					{"!push(ecx)"},
				},
			}), [[
			@call_error
			!pop_all_registers_iwd2
		]]}))
	end

	--------------------------------------------------
	-- Remove click cooldown from actionbar buttons --
	--------------------------------------------------

	IEex_WriteDword(0x85C518, 0x4D4D70)

	-------------------------------------------
	-- Remove cooldown from dialog responses --
	-------------------------------------------

	IEex_WriteAssembly(0x687606, {"!repeat(2,!nop)"}) -- Number key
	IEex_WriteAssembly(0x68746A, {"!repeat(6,!nop)"}) -- Enter
	IEex_WriteAssembly(0x6968E0, {"!repeat(2,!nop)"}) -- Left click (continue)
	IEex_WriteAssembly(0x77BCC8, {"!repeat(2,!nop)"}) -- Left click (reply)

	-- Redirect empty Continue button OnLButtonDoubleClick() => OnLButtonDown()
	IEex_WriteDword(0x85A45C, 0x4D4D70)

	--------------------------------------------------------------
	-- Doubled fonts: use the glyph-atlas path (GL text at 2x)  --
	--------------------------------------------------------------

	-- CVidFont::TextOut3d @0x7A1210 gates m_bDoubleSize fonts to TextOutEx3d,
	-- which re-uploads a full 512x512 texture PER GLYPH PER FRAME (no atlas) --
	-- at the engine 2x UI tier every text draw takes that path and text-heavy
	-- screens (dialog, record, inventory) collapse to a slideshow.
	-- RenderCharacters @0x7A1660 (the atlas path) already doubles quads and
	-- advances via nScale when m_bDoubleSize, sampling the 1x atlas with
	-- GL_NEAREST -- pixel-identical to the Blt-doubled slow path. NOP the
	-- doubled-font branch of the gate (jne 0x7A1601 @0x7A12C6) so doubled
	-- fonts fall through to CheckIfLoaded + the atlas renderer.
	-- TextOut3d early-returns unless Is3dAccelerated, so this only affects GL.
	IEex_WriteAssembly(0x7A12C6, {"!repeat(6,!nop)"})

	-----------------------------------------
	-- Also use space to "Continue" dialog --
	-----------------------------------------

	IEex_HookJump(0x687434, 5, {[[
		!je_dword >jmp_fail
		!cmp_al_byte 20 ; spacebar ;
	]]})

	--------------------------------------
	-- IEex_Extern_OnOptionsScreenESC() --
	--------------------------------------

	if not IEex_Vanilla then
		IEex_HookBeforeCall(0x654446, IEex_FlattenTable({
			{[[
				!push_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_OnOptionsScreenESC", {
				["args"] = {
					{"!push(ecx)"}, -- CScreenOptions
				},
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				@call_error
				!test_eax_eax
				!pop_registers_iwd2
				!jnz_dword >return
			]]},
		}))
	end

	-----------------------------------------------------------------------------
	-- Don't throw assert when restoring CVidMode on non-vanilla options panel --
	-----------------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_WriteAssembly(0x6554FB, {"!repeat(5,!nop)"})
	end

	--------------------------------------------------
	-- Render CScreenWorld UI AFTER the worldscreen --
	--------------------------------------------------

	IEex_WriteAssembly(0x68DF87, {"!repeat(5,!nop)"})

	IEex_HookBeforeCall(0x68DF9F, IEex_FlattenTable({
		{[[
			!push_registers_iwd2
		]]},
		IEex_GenLuaCall("IEex_Extern_BeforeWorldRender"),
		{[[
			@call_error
			!pop_registers_iwd2
		]]},
	}))

	-- HUD LAYER (perf): route the re-injected world-UI render through
	-- IEex_Helper_HudLayerRender -- renders the UI into a persistent game-res FBO
	-- (panels repaint only when really dirtied) and composites it over the world
	-- with one blended quad. Falls back to a plain CUIManager::Render call when
	-- the layer is unavailable (software / no FBO ext / [IEex Options] "HUD
	-- Layer"=0) -- IEex_Extern_BeforeWorldRender keeps its per-frame invalidate
	-- fallback in exactly that case (IEex_Helper_IsHudLayerActive).
	IEex_HookRestore(0x68DFB6, 0, 5, {[[
		!mov(ecx,ebp)
		!push_ecx
		!call >IEex_Helper_HudLayerRender ; wraps CUIManager::Render @0x4D4540 ;
	]]})

	---------------------------------------
	-- IEex_Extern_MouseInAreaViewport() --
	---------------------------------------

	IEex_HookReturnNOPs(0x46E45F, 0x4A, IEex_FlattenTable({
		{[[
			!mark_esp
			!push_registers_iwd2
		]]},
		IEex_GenLuaCall("IEex_Extern_MouseInAreaViewport", {
			["args"] = {
				{"!push(esi)"},
			},
			["returnType"] = IEex_LuaCallReturnType.Boolean,
		}),
		{[[
			!jmp_dword >no_error

			@call_error
			!mov(eax,1)

			@no_error
			!marked_esp !mov([esp+1C],eax)
			!pop_registers_iwd2
		]]},
	}))

	---------------------------------------------
	-- IEex_Extern_RejectGetWorldCoordinates() --
	---------------------------------------------

	IEex_HookJump(0x5CDFCE, 3, IEex_FlattenTable({
		{[[
			!push_all_registers_iwd2
		]]},
		IEex_GenLuaCall("IEex_Extern_RejectGetWorldCoordinates", {
			["args"] = {
				{"!push_ecx"},
				{"!push([eax])"},
				{"!push([eax+4])"},
			},
			["returnType"] = IEex_LuaCallReturnType.Boolean,
		}),
		{[[
			!jmp_dword >no_error

			@call_error
			!xor_eax_eax

			@no_error
			!test_eax_eax
			!pop_all_registers_iwd2
			!jnz_dword >jmp_success
			!cmp(edi,ebx)
		]]},
	}))

	IEex_HookJump(0x4765DC, 0, IEex_FlattenTable({
		{[[
			!push_all_registers_iwd2
		]]},
		IEex_GenLuaCall("IEex_Extern_RejectGetWorldCoordinates", {
			["args"] = {
				{"!lea(eax,[edi+4CC]) !push_eax"},
				{"!push([ebp])"},
				{"!push([ebp+4])"},
			},
			["returnType"] = IEex_LuaCallReturnType.Boolean,
		}),
		{[[
			!jmp_dword >no_error

			@call_error
			!xor_eax_eax

			@no_error
			!test_eax_eax
			!pop_all_registers_iwd2
			!jnz_dword >jmp_success
			!cmp(ecx,edx)
		]]},
	}))

	IEex_HookJump(0x475465, 0, IEex_FlattenTable({
		{[[
			!push_all_registers_iwd2
		]]},
		IEex_GenLuaCall("IEex_Extern_RejectGetWorldCoordinates", {
			["args"] = {
				{"!lea(eax,[esi+4CC]) !push_eax"},
				{"!push([edi])"},
				{"!push([edi+4])"},
			},
			["returnType"] = IEex_LuaCallReturnType.Boolean,
		}),
		{[[
			!jmp_dword >no_error

			@call_error
			!xor_eax_eax

			@no_error
			!test_eax_eax
			!pop_all_registers_iwd2
			!jnz_dword >jmp_success
			!cmp(eax,[esi+514])
		]]},
	}))

	-----------------------------------------------------
	-- IEex_Extern_OverrideWorldScreenScrollbarFocus() --
	-----------------------------------------------------

	if not IEex_Vanilla then

		-- [Before !push_all_registers_iwd2]
		-- Don't crash in CScreenWorld_TimerSynchronousUpdate() if m_displayStale
		-- was set to 1 by the above patch when in the middle of a quickload.
		-- TODO: Review other cases of m_displayStale being used to block while
		-- waiting for another thread to finish a task.
		IEex_HookAfterRestore(0x68DECB, 0, 5, IEex_FlattenTable({
			{[[
				!cmp([ebp+4],0) ; m_UIManager->m_resLoaded ;
				!jz_dword :68DF04
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_OverrideWorldScreenScrollbarFocus", {
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor_eax_eax

				@no_error
				!test_eax_eax
				!pop_all_registers_iwd2
				!jnz_dword :68DF04
			]]},
		}))
	end

	---------------------------------------
	-- IEex_Extern_OnSetActionbarState() --
	---------------------------------------

	if not IEex_Vanilla then
		IEex_HookRestore(0x589110, 0, 5, IEex_FlattenTable({
			{[[
				!mark_esp
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_OnSetActionbarState", {
				["args"] = {
					{"!marked_esp !push([esp+4])"}, -- nState
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
			]]},
		}))
	end

	----------------------------------------------------
	-- IEex_Extern_OnActionbarUnhandledRButtonClick() --
	----------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookJumpOnSuccess(0x5947DA, 0, IEex_FlattenTable({
			{[[
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_OnActionbarUnhandledRButtonClick", {
				["args"] = {
					{"!push_esi"}, -- nIndex
				},
			}),
			{[[
				@call_error
				!pop_all_registers_iwd2
				!jmp_dword >jmp_success
			]]},
		}))
	end

	----------------------------------------
	-- IEex_Extern_RejectWorldScreenEsc() --
	----------------------------------------

	if not IEex_Vanilla then
		IEex_HookRestore(0x68785E, 0, 6, IEex_FlattenTable({
			{[[
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_RejectWorldScreenEsc", {
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor_eax_eax

				@no_error
				!test_eax_eax
				!pop_all_registers_iwd2
				!jnz_dword :689504
			]]},
		}))
	end

	------------------------
	-- Widescreen Support --
	------------------------

	-- Select resolution on game start
	IEex_HookReturnNOPs(0x42212A, 1, IEex_FlattenTable({[[
		!push_all_registers_iwd2
		]], IEex_GenLuaCall("IEex_Extern_InitResolution"), [[
		@call_error
		!pop_all_registers_iwd2
	]]}))

	-- Reject non-32-bit bit depths
	IEex_HookRestore(0x79B3DF, 0, 5, IEex_FlattenTable({[[
		!push_all_registers_iwd2
		]], IEex_GenLuaCall("IEex_Extern_CheckBitDepth", {
			["returnType"] = IEex_LuaCallReturnType.Boolean,
		}), [[
		!jmp_dword >no_error
		@call_error
		!xor_eax_eax
		@no_error
		!test_eax_eax
		!pop_all_registers_iwd2
		!jnz_dword >return
		!mov(ecx,[8CF6D8])
		!jmp_dword :79B34B
	]]}))

	-- If selected resolution is 800x600 use GUIW08, else use customized GUIW10
	IEex_HookJumpNoReturn(0x42216E, IEex_FlattenTable({[[
		!cmp(ecx,320)
		!jne_dword :422198
		!cmp(word:[8BA31E],258)
		!jne_dword :422198
		!jmp_dword :4224CC
	]]}))

	-- Don't set g_resolution[1] when using GUIW10
	IEex_WriteAssembly(0x42228C, {"!repeat(7,!nop)"})

	-- Used to tweak various GUI constants
	IEex_HookRestore(0x422848,0, 6, IEex_FlattenTable({[[
		!push_all_registers_iwd2
		]], IEex_GenLuaCall("IEex_Extern_InitGUIConstants"), [[
		@call_error
		!pop_all_registers_iwd2
	]]}))

	-- Used to tweak the high resolution panels
	IEex_HookAfterRestore(0x4229D5, 0, 7, IEex_FlattenTable({[[
		!push_all_registers_iwd2
		]], IEex_GenLuaCall("IEex_Extern_InitHighResolutionPaddingPanels", {["args"] = {{"!push(esi)"}}}), [[
		@call_error
		!pop_all_registers_iwd2
	]]}))

	-- World-HUD decorative frame off (unifies the "UI Borders" toggle). The STON10 padding panels handled
	-- above only frame the menu/record screens -- CScreenWorld never AddPanel's them, so that path can't
	-- reach the world HUD. The world HUD's stone frame is instead BAKED INTO its panel MOS (command bar,
	-- world map, container, death, travel). So when the player turns "UI Borders" off, redirect those MOS
	-- at load time to a transparent-margin (minimal) variant -- the toggle then strips the world HUD too,
	-- at BOTH 1x and 2x. Chokepoint: every MOS consumer funnels through CDimm::GetResObject(&resref, nType,
	-- bWarn) @0x786DF0 (CResHelper::SetResRef -> GetResObject; MOS nType == 1004 = 0x3EC). We repoint the
	-- incoming &resref (@[esp+4]) at a private 8-byte buffer holding the minimal resref; GetResObject only
	-- READS the resref (FindKey), so the caller's own CResRef is never mutated. Session-fixed: read once at
	-- patch time like the STON memset above (restart to apply). Minimal art ships as GCOMM11M etc. (last
	-- resref char -> 'M'); WeiDU stages the tier-correct (1x or 2x) art under that resref. The 2x de-double
	-- list (IEex_UIScale_Patch.lua mos_list) also carries the minimal resrefs so 2x stays crisp, not 4x.
	if IEex_GetPrivateProfileInt("IEex Options", "UI Borders", 1, ".\\Icewind2.ini") == 0 then

		-- {decorated dword0, decorated dword1, minimal resref}. The two dwords are the LE halves of the
		-- 8-char decorated resref (same encoding as mos_list); match either half fails -> next entry.
		local worldBorderRedirect = {
			{0x4D4F4347, 0x3831314D, "GCOMM11M"}, -- GCOMM118  command bar
			{0x4D4F4347, 0x3832314D, "GCOMM12M"}, -- GCOMM128  command bar (6-char party)
			{0x54434147, 0x3831314E, "GACTN11M"}, -- GACTN118  action dial
			{0x44574D47, 0x30424D4D, "GMWDMMBM"}, -- GMWDMMB0  world map
			{0x44574D47, 0x30424C53, "GMWDSLBM"}, -- GMWDSLB0  world map
			{0x4F435547, 0x3042544E, "GUCONTBM"}, -- GUCONTB0  container
			{0x45445547, 0x30485441, "GUDEATHM"}, -- GUDEATH0  death screen
			{0x42575547, 0x30335054, "GUWBTP3M"}, -- GUWBTP30  worldmap travel
			{0x4B513342, 0x544F4F4C, "B3QKLOOM"}, -- B3QKLOOT  quickloot (panel 611 < 1024 MOS -> composite skips left cap only)
		}

		-- Detour is entered by jmp (esp unshifted): &resref @[esp+4], nType @[esp+8]. eax/edx are dead at
		-- the function entry (the 2 displaced movs reload both), so the detour clobbers them freely -- no
		-- push/pop needed. On a MOS resref match, overwrite the &resref stack slot with the minimal-resref
		-- buffer address (raw  mov dword [esp+4], imm32 = C7 44 24 04 <imm32 LE>), then fall through to @skip.
		local function leBytes(addr)
			return string.format("%02X %02X %02X %02X",
				addr % 0x100, math.floor(addr / 0x100) % 0x100, math.floor(addr / 0x10000) % 0x100, math.floor(addr / 0x1000000) % 0x100)
		end
		local redirect = "!mov(eax,[esp+0x8]) !cmp_eax_dword #000003EC !jne_dword >skip "
		for k, e in ipairs(worldBorderRedirect) do
			local buf = IEex_Malloc(0x8)
			IEex_WriteLString(buf, e[3], 8)
			redirect = redirect
				.. "!mov(eax,[esp+0x4]) !mov(eax,[eax]) !cmp_eax_dword #" .. string.format("%08X", e[1]) .. " !jne_dword >n" .. k .. " "
				.. "!mov(eax,[esp+0x4]) !mov(eax,[eax+0x4]) !cmp_eax_dword #" .. string.format("%08X", e[2]) .. " !jne_dword >n" .. k .. " "
				.. "C7 44 24 04 " .. leBytes(buf) .. " !jmp_dword >skip @n" .. k .. " "
		end
		redirect = redirect .. "@skip"

		-- CDimm::GetResObject prologue = mov eax,[esp+0C] ; mov edx,[esp+04]  (8 bytes). Re-run after the
		-- detour: edx picks up the rewritten [esp+04] = the minimal buffer. 0x786DF0 + 8 = 0x786DF8 (push esi).
		IEex_AttemptHook(0x786DF0,
			{redirect},
			{"8B 44 24 0C 8B 54 24 04 !jmp_dword :786DF8"},
			{0x8B, 0x44, 0x24, 0x0C, 0x8B, 0x54, 0x24, 0x04})
	end

	-- Disable instances where the engine rendered the mouse at non-buffer-flip moments.
	-- This renders the mouse before everything is drawn to the screen, yet blocks
	-- the mouse from rendering again at buffer-flip, causing it to flicker.
	IEex_WriteAssembly(0x79F6A0, {[[
		!mov(eax,0)
		!ret
	]]})

	-- On opening the debug console
	IEex_HookAfterCall(0x69126A, IEex_FlattenTable({[[
		!push_all_registers_iwd2
		]], IEex_GenLuaCall("IEex_Extern_StartDebugConsole"), [[
		@call_error
		!pop_all_registers_iwd2
	]]}))

	-- On closing the debug console
	IEex_HookAfterRestore(0x6913AF, 0, 10, IEex_FlattenTable({[[
		!push_all_registers_iwd2
		]], IEex_GenLuaCall("IEex_Extern_StopDebugConsole"), [[
		@call_error
		!pop_all_registers_iwd2
	]]}))

	-- Blank the back buffer after switching engines (or on starting CCacheStatus)
	-- so that left-over junk isn't rendered
	IEex_HookRestore(0x790DC4, 0, 8, {[[
		!push_all_registers_iwd2
		!push(ecx)
		!call >IEex_Helper_BlankBackBuffer
		!pop_all_registers_iwd2
	]]})

	IEex_HookRestore(0x4408C2, 0, 5, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_BlankCCache1
		!pop_all_registers_iwd2
	]]})
	IEex_HookAfterRestore(0x44208D, 0, 6, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_BlankCCache2
		!pop_all_registers_iwd2
	]]})
	IEex_HookAfterRestore(0x4422AF, 0, 6, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_BlankCCache2
		!pop_all_registers_iwd2
	]]})
	IEex_HookAfterRestore(0x4427FF, 0, 6, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_BlankCCache2
		!pop_all_registers_iwd2
	]]})

	-- Tab should always force tooltip regardless of where the cursor is in relation to the viewport
	IEex_WriteAssembly(0x687AFB, {"!jmp_byte"})
	IEex_WriteAssembly(0x68BC16, {"!jmp_byte"})
	IEex_WriteAssembly(0x6873D5, {"!jmp_byte"})

	------------------------------------------------
	-- Disable Gamma-correction on mainscreen MOS --
	------------------------------------------------

	if not IEex_Vanilla then
		IEex_HookJumpToAutoReturn(0x4D3435, {[[
			!push(edi)
			!call >IEex_Helper__CUIPanel_Render__CVidMosaic_Render
		]]})
	end

	---------------------------------------------------------
	-- m_lPopupStack shouldn't be modified while           --
	-- CScreenSpell_TimerSynchronousUpdate is accessing it --
	---------------------------------------------------------

	if not IEex_Vanilla then

		local lock_IEex_CScreenSpell_m_lPopupStack = IEex_Helper_GetOrCreateGlobalLock("IEex_CScreenSpell_m_lPopupStack")

		for _, address in ipairs({0x66B480, 0x66B71E}) do
			IEex_HookJumpToAutoReturn(address, {[[
				!push_all_registers_iwd2
				!push_dword ]], {lock_IEex_CScreenSpell_m_lPopupStack, 4}, [[
				!call >IEex_Helper_LockGlobalDirect
				!pop_all_registers_iwd2
				!call >original_dest
				!push_all_registers_iwd2
				!push_dword ]], {lock_IEex_CScreenSpell_m_lPopupStack, 4}, [[
				!call >IEex_Helper_UnlockGlobalDirect
				!pop_all_registers_iwd2
			]]})
		end

		IEex_HookRestore(0x66A59C, 0, 6, {[[
			!push_all_registers_iwd2
			!push_dword ]], {lock_IEex_CScreenSpell_m_lPopupStack, 4}, [[
			!call >IEex_Helper_LockGlobalDirect
			!pop_all_registers_iwd2
		]]})

		IEex_HookRestore(0x66A6F5, 0, 5, {[[
			!push_all_registers_iwd2
			!push_dword ]], {lock_IEex_CScreenSpell_m_lPopupStack, 4}, [[
			!call >IEex_Helper_UnlockGlobalDirect
			!pop_all_registers_iwd2
		]]})
	end

	----------------------------------------------------------------------------------
	-- Dialog auto-scroll should be consistent for when it instantly moves viewport --
	----------------------------------------------------------------------------------

	IEex_HookRestore(0x484B94, 2, 3, IEex_FlattenTable({[[
		!push_registers_iwd2
		!push_eax
		]], IEex_GenLuaCall("IEex_Extern_AdjustAutoScrollY", {
			["args"] = {{"!push(esi)"}},
			["returnType"] = IEex_LuaCallReturnType.Number,
		}), [[
		@call_error
		!sub_[esp]_eax
		!pop_eax
		!pop_registers_iwd2
	]]}))

	-------------------------------------------------------------------------------------------------
	-- Remove 1-second "message screen" (non-functional?) when instantly moving viewport to dialog --
	-------------------------------------------------------------------------------------------------

	IEex_WriteAssembly(0x484BE1, {"!jmp_byte"})

	----------------------------------------------------------------------------
	-- Prevent portraits / health bars from flickering above inventory popups --
	----------------------------------------------------------------------------

	if not IEex_Vanilla then

		local noNeedRenderWhenInventoryPopupOpen = IEex_WriteAssemblyAuto({[[

			!mov_edx_[dword] #8CF6DC ; g_pBaldurChitin ;
			!test_edx_edx
			!jz_dword :4D4C20

			!mov_eax_[edx+dword] #1C68 ; m_pEngineInventory ;
			!test_eax_eax
			!jz_dword :4D4C20

			!mov_edx_[edx+dword] #3C4 ; pActiveEngine ;
			!test_edx_edx
			!jz_dword :4D4C20

			!cmp_eax_edx
			!jne_dword :4D4C20

			!mov_eax_[eax+dword] #49C ; m_pEngineInventory.m_lPopupStack.m_nCount ;
			!test_eax_eax
			!jz_dword :4D4C20

			!xor_eax_eax
			!ret
		]]})

		IEex_WriteDword(0x855AC8, noNeedRenderWhenInventoryPopupOpen) -- Inventory Portraits
		IEex_WriteDword(0x85C770, noNeedRenderWhenInventoryPopupOpen) -- Portrait Health Bars
	end

	--------------------------------------------------------------
	-- Allow CHU files to define panels at negative coordinates --
	--------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_WriteAssembly(0x4D2822, {"!movsx_eax_word:[edi+byte] 04"})
		IEex_WriteAssembly(0x4D2828, {"!movsx_ecx_word:[edi+byte] 06"})
		IEex_WriteAssembly(0x4D27F4, {"!movsx_eax_word:[edi+byte] 04"})
		IEex_WriteAssembly(0x4D27FA, {"!movsx_ecx_word:[edi+byte] 06"})
	end

	------------------------------------------------------------------------------
	-- Tooltips shouldn't be killed every time a character's actionbar updates, --
	-- for example, when their effect list is processed.                        --
	------------------------------------------------------------------------------

	if not IEex_Vanilla then

		local inEffectListButtonArrayUpdateMem = IEex_Malloc(0x4)
		IEex_WriteDword(inEffectListButtonArrayUpdateMem, 0x0)

		IEex_HookBeforeAndAfterCall(0x734704,
			{"!mov_[dword]_dword", {inEffectListButtonArrayUpdateMem, 4}, "#1"},
			{"!mov_[dword]_dword", {inEffectListButtonArrayUpdateMem, 4}, "#0"}
		)

		local determineTooltipKillReason = IEex_WriteAssemblyAuto({[[

			!push_registers_iwd2

			!cmp_[dword]_byte ]], {inEffectListButtonArrayUpdateMem, 4}, [[ 00
			!jz_dword >unknown

			!mov_eax ]], {IEex_TooltipKillReason.EFFECT_LIST_UPDATE, 4}, [[
			!jmp_dword >return

			@unknown
			!mov_eax ]], {IEex_TooltipKillReason.UNKNOWN, 4}, [[

			@return
			!pop_registers_iwd2
			!ret
		]]})

		local killTooltipHookMem = IEex_Malloc(0x8)

		local shouldTooltipBeRefreshedMem = killTooltipHookMem
		IEex_WriteDword(shouldTooltipBeRefreshedMem, 0x0)

		local savedTooltipUIManagerMem = killTooltipHookMem + 0x4
		IEex_WriteDword(savedTooltipUIManagerMem, 0x0)

		IEex_HookRestore(0x4D4060, 0, 7, IEex_FlattenTable({
			{[[
				!push_all_registers_iwd2
				!mov_[dword]_ecx ]], {savedTooltipUIManagerMem, 4}, [[
			]]},
			IEex_GenLuaCall("IEex_Extern_ShouldTooltipRefreshInsteadOfDying", {
				["args"] = {
					{[[
						!call ]], {determineTooltipKillReason, 4, 4}, [[
						!push(eax)
					]]},
				},
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor(eax,eax)

				@no_error
				!mov_[dword]_eax ]], {shouldTooltipBeRefreshedMem, 4}, [[

				!pop_all_registers_iwd2
			]]},
		}))

		IEex_HookAfterRestore(0x4D40A8, 0, 7, {[[

			!push_all_registers_iwd2

			!cmp_[dword]_byte ]], {shouldTooltipBeRefreshedMem, 4}, [[ 00
			!jz_dword >allow_tooltip_kill

			!mov_eax_[dword] ]], {savedTooltipUIManagerMem, 4}, [[
			!mov([eax+0x76],1) ; m_bIsForceToolTip = 1 ;

			@allow_tooltip_kill
			!pop_all_registers_iwd2
		]]})
	end

	------------------------------------------------------------------
	-- Render green overlay on scrolls that the character can learn --
	--   Hardcoded resref: B3TINTG.BAM                              --
	------------------------------------------------------------------

	if not IEex_Vanilla then

		-- CUIControlButtonItemSlot::Render()
		IEex_HookJumpOnSuccess(0x62E560, 0, {[[
			!mark_esp
			!push_all_registers_iwd2
			!push(esi)                    ; pButton ;
			!marked_esp !push([esp+0x24]) ; pItem   ;
			!marked_esp !push([esp+0x14]) ; pSprite ;
			!call >IEex_Helper_PostItemSlotRenderHook
			!pop_all_registers_iwd2
		]]})

		-- CUIControlButtonStoreItem::Render()
		IEex_HookJumpOnSuccess(0x681C3B, 3, {[[
			!mark_esp
			!push_all_registers_iwd2
			!push(esi)                    ; pButton ;
			!lea(eax,[esi+0x66E])
			!push(eax)                    ; pItem   ;
			!marked_esp !push([esp+0x20]) ; pSprite ;
			!call >IEex_Helper_PostItemSlotRenderHook
			!pop_all_registers_iwd2
		]]})

		-- CUIControlButtonStorePartyItem::Render()
		IEex_HookJumpOnSuccess(0x68278B, 3, {[[
			!mark_esp
			!push_all_registers_iwd2
			!push(esi)                    ; pButton ;
			!lea(eax,[esi+0x66E])
			!push(eax)                    ; pItem   ;
			!marked_esp !push([esp+0x20]) ; pSprite ;
			!call >IEex_Helper_PostItemSlotRenderHook
			!pop_all_registers_iwd2
		]]})

		-- CUIControlButtonWorldContainerSlot::Render()
		IEex_HookJumpOnSuccess(0x696623, 3, {[[
			!mark_esp
			!push_all_registers_iwd2
			!push(esi)                    ; pButton ;
			!marked_esp !push([esp+0x1C]) ; pItem   ;
			!marked_esp !push([esp+0x10]) ; pSprite ;
			!call >IEex_Helper_PostItemSlotRenderHook
			!pop_all_registers_iwd2
		]]})

		IEex_HookReplaceFunctionMaintainOriginal(0x7AEAD0, 5, "CVidCell::RenderIconOriginal", {[[
			!jmp_dword >IEex_Helper_CVidCell_RenderIconOverride
		]]})
		IEex_Helper_DefineAddress("CVidCell::RenderIconOriginal", IEex_Label("CVidCell::RenderIconOriginal"))
	else
		-- Silence warning from IEexHelper.dll when running in vanilla mode
		IEex_Helper_DefineAddress("CVidCell::RenderIconOriginal", -1)
	end

	----------------------------------------
	-- Allow elves to be raised by stores --
	----------------------------------------

	if not IEex_Vanilla then
		IEex_WriteAssembly(0x67E7E2, {"!jmp_byte"})
	end

	---------------------------------------------------------------
	-- Fix the animation preview during chargen running too fast --
	---------------------------------------------------------------

	if not IEex_Vanilla then

		-- Disable sync-thread advancement of the animation
		IEex_WriteAssembly(0x61DE34, {"!jmp_byte"})

		-- Override CUIControlButtonChargenAnimationPreview::TimerAsynchronousUpdateOverride()
		-- to make it perform the animation advancement instead
		IEex_DisableRDataProtection()
		IEex_WriteDword(0x85CDF0, IEex_Label("IEex_Helper_CUIControlButtonChargenAnimationPreview_TimerAsynchronousUpdateOverride"))
		IEex_EnableRDataProtection()
	end

	-------------------------------------------------------------------
	-- Extend CScreenKeys (GUIKEYS.CHU) to allow for custom keybinds --
	-------------------------------------------------------------------

	if not IEex_Vanilla then
		IEex_WriteAssembly(0x597740, { "!jmp_dword >IEex_Helper_CInfCursor_SetToolTipOverride                 !repeat(2,!nop)" })
		IEex_WriteAssembly(0x5A98F0, { "!jmp_dword >IEex_Helper_CInfGame_InitHotkeyMapOverride                !repeat(2,!nop)" })
		IEex_WriteAssembly(0x5A9B00, { "!jmp_dword >IEex_Helper_CInfGame_UpdateKeybindMappingOverride                        " })
		IEex_WriteAssembly(0x639DC0, { "!jmp_dword >IEex_Helper_CScreenKeys_InitDueToUserInteractionOverride                 " })
		IEex_WriteAssembly(0x639160, { "!jmp_dword >IEex_Helper_CScreenKeys_OnKeyDownProcessOverride          !repeat(2,!nop)" })
		IEex_WriteAssembly(0x639790, { "!jmp_dword >IEex_Helper_CScreenKeys_OnLButtonDownOverride                            " })
		IEex_WriteAssembly(0x63A480, { "!jmp_dword >IEex_Helper_CScreenKeys_OnPanel1ButtonClickOverride       !repeat(2,!nop)" })
		IEex_WriteAssembly(0x63AA60, { "!jmp_dword >IEex_Helper_CScreenKeys_SetSelectedDisplayIndexOverride             !nop " })
		IEex_WriteAssembly(0x63A910, { "!jmp_dword >IEex_Helper_CScreenKeys_SetStagedKeybindOverride          !repeat(2,!nop)" })
		IEex_WriteAssembly(0x63A7A0, { "!jmp_dword >IEex_Helper_CScreenKeys_UpdateHoverPalettesOverride                      " })
		IEex_WriteAssembly(0x63A660, { "!jmp_dword >IEex_Helper_CScreenKeys_UpdateLabelPalettesOverride       !repeat(5,!nop)" })
		IEex_WriteAssembly(0x639A50, { "!jmp_dword >IEex_Helper_CScreenKeys_UpdateMainPanelOverride           !repeat(2,!nop)" })
		IEex_WriteAssembly(0x63ACA0, { "!jmp_dword >IEex_Helper_CUIControlButtonKeys_OnLButtonClickOverride             !nop " })
	end

	---------------------------------------------
	-- Allow spontaneous casting customization --
	---------------------------------------------

	if not IEex_Vanilla then

		IEex_HookReturnNOPs(0x5915F4, 15, IEex_FlattenTable({
			{[[
				!cmp_byte:[ebp+byte] 3A 00 ; m_bDisabled ;
				!jnz_dword :59162B

				!mark_esp
				!push_all_registers_iwd2
			]]},
			IEex_GenLuaCall("IEex_Extern_AttemptSpontaneousCast", {
				["args"] = {
					{"!marked_esp !push([esp+0x10])"}, -- sprite
					{"!push(ebp)"},                    -- buttonData
				},
				["returnType"] = IEex_LuaCallReturnType.Boolean,
			}),
			{[[
				!jmp_dword >no_error

				@call_error
				!xor_eax_eax

				@no_error
				!test_eax_eax
				!pop_all_registers_iwd2

				!jz_dword :59162B
			]]},
		}))

		-- Disable cleric-enforcing asserts
		IEex_WriteAssembly(0x7167BB, {"!jmp_byte"})
		IEex_WriteAssembly(0x7167D9, {"!jmp_byte"})

		IEex_HookReturnNOPs(0x716841, 24, IEex_FlattenTable({
			{[[
				!mark_esp
				!push(eax)
				!push(ecx)
				!push(edx)
				!push(esi)
				!push(edi)

				!push(-1) ; [esp-0x18] returnValues.row ;
				!push(-1) ; [esp-0x1C] returnValues.column ;
			]]},
			IEex_GenLuaCall("IEex_Extern_GetSpontaneousCastColumnAndRow", {
				["args"] = {
					{"!marked_esp !push([esp+0x14])"},               -- sprite
					{"!marked_esp !push([esp+0x90])"},               -- buttonData
					{"!marked_esp !lea(eax,[esp-0x1C]) !push(eax)"}, -- returnValues
				},
			}),
			{[[
				@call_error
				!marked_esp !mov(ebp,[esp-0x1C]) ; ebp holds the SPONCAST.2DA column ;
				!marked_esp !mov(ebx,[esp-0x18]) ; ebx holds the SPONCAST.2DA row ;

				!add(esp,8) !adjust_marked_esp(-8)
				!pop(edi)
				!pop(esi)
				!pop(edx)
				!pop(ecx)
				!pop(eax)
			]]},
		}))
	end

	--------------------------------------------------------------------------------
	-- World-HUD refonte -- CGameSprite::RenderPortrait (0x704D40) -> DLL
	-- reimplementation with the hardcoded 42/44 geometry derived from the control
	-- size (image = szControl-4, ring = szControl-2), so the portrait slot can be
	-- rectangular (54x84). Stock control sizes (46x46) render pixel-identical, so
	-- every caller (world / map screen / arena) is safe to route through it.
	-- __thiscall, 7 stack args, ret 0x1C; marshal to the __stdcall export.
	-- NOTE: IEex_UIScale_Patch.lua's HD-UI block writes `mov [esp+0x1C],1` over
	-- these same 7 prologue bytes (force bDoubleSize) -- IEEX_HD_UI and the
	-- refonte are mutually exclusive until that forcing moves into the DLL.
	--------------------------------------------------------------------------------
	if IEex_PortraitGridEnabled then
		IEex_WriteAssembly(0x704D40, {[[
			!mark_esp
			!marked_esp !push([esp+0x1C])
			!marked_esp !push([esp+0x18])
			!marked_esp !push([esp+0x14])
			!marked_esp !push([esp+0x10])
			!marked_esp !push([esp+0x0C])
			!marked_esp !push([esp+0x08])
			!marked_esp !push([esp+0x04])
			51
			!call >IEex_Helper_RenderPortraitRect
			!ret_word 1C 00
		]]})

		-- Skip panel-1's GACTN band MOS while the refonte is installed: the band is no
		-- longer composited, but its art still landed in the layer and showed through any
		-- content-rect overlapping it (the centered action bar sampled old slot texture).
		-- Wraps the CVidMosaic::Render call inside CUIPanel::Render (ecx = &m_mosaic).
		local mosStub = IEex_WriteAssemblyAuto({[[
			51
			!call >IEex_Helper_PanelMosaicRender
			!jmp_dword :4D343A
		]]})
		IEex_WriteAssembly(0x4D3435, IEex_FlattenTable({
			{[[ !jmp_dword ]], {mosStub, 4, 4}},
		}))

		-- Swallow right-clicks landing inside the refonte bars when no control consumed
		-- them: empty action slots are INACTIVE controls (transparent to input), so the
		-- click fell through the panel walk to the fullscreen world control = a party
		-- move order THROUGH the bar. Wraps the panel dispatch in CUIManager::OnRButtonDown.
		local rclickStub = IEex_WriteAssemblyAuto({[[
			51
			!call >IEex_Helper_PanelRClickRefonte
			!jmp_dword :4D4497
		]]})
		IEex_WriteAssembly(0x4D4492, IEex_FlattenTable({
			{[[ !jmp_dword ]], {rclickStub, 4, 4}},
		}))

	end

	-- The MOVEMENT right-click path is PARALLEL to the UI walk: CScreenWorld's
	-- OnRButtonDown/Up call CGameArea::OnFormationButtonDown/Up UNCONDITIONALLY after
	-- the UI manager -- consuming the click in the panel walk does not stop the move
	-- order. Wrap both callsites; the DLL swallows the pair when the DOWN lands on a
	-- HUD bar. NOT gated on IEex_PortraitGridEnabled: the swallow must ALSO cover the
	-- STOCK (core, non-refonte) action bar / portraits / log, else a right-click there
	-- walks the party. Export_FormationRDown -> StockHudBarsHit uses the engine's own
	-- panel rects on a core install; refonte installs use RefonteBarsHit. Only requires
	-- IEex active (the exports exist when not vanilla).
	if not IEex_Vanilla then
		local formDownStub = IEex_WriteAssemblyAuto({[[
			51
			!call >IEex_Helper_FormationRDown
			!jmp_dword :68C2C5
		]]})
		IEex_WriteAssembly(0x68C2C0, IEex_FlattenTable({
			{[[ !jmp_dword ]], {formDownStub, 4, 4}},
		}))
		local formUpStub = IEex_WriteAssemblyAuto({[[
			51
			!call >IEex_Helper_FormationRUp
			!jmp_dword :68C325
		]]})
		IEex_WriteAssembly(0x68C320, IEex_FlattenTable({
			{[[ !jmp_dword ]], {formUpStub, 4, 4}},
		}))
	end

	IEex_EnableCodeProtection()

end)()
