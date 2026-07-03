
(function()

	IEex_DisableCodeProtection()

	--------------------------------------------------------------------
	-- Fix crash involving sound system not properly clearing invalid --
	-- sounds from various internal lists when they are destructed    --
	--------------------------------------------------------------------

	IEex_HookRestore(0x7A8E20, 0, 7, {[[
		!push_all_registers_iwd2
		!call >IEex_Helper_CSoundImp_DestructHook
		!pop_all_registers_iwd2
	]]})

	------------------------------------------------------------------------------------------------------------
	-- Fix crash involving sound system not properly initializing CSoundMixer's pDirectSound ([+0x4]) member. --
	-- pDirectSound is expected to be initialized to nullptr, but the engine never assigns it a value in      --
	-- CSoundMixer's constructor. Thus, it starts as whatever value existed in its memory location. The       --
	-- engine crashes if this memory location happens to hold a non-zero value during launch!                 --
	------------------------------------------------------------------------------------------------------------

	IEex_HookRestore(0x7AAD80, 0, 6, {[[
		!mov([ecx+0x4],0x0)
	]]})

	-----------------------------------------------------------------------------------------------------------
	-- Start CSoundMixer::nMaxChannelSlot as -1 so IEexHelper.dll's CSoundImp::Export_DestructHook() doesn't --
	-- crash when icewind2.ini's [Alias] fields aren't properly updated. The game still crashes when this    --
	-- happens, but displays the proper assertion.                                                           --
	-----------------------------------------------------------------------------------------------------------

	IEex_HookReturnNOPs(0x7AAE62, 1, {[[
		!mov([esi+0xD8],-1)
	]]})

	--------------------------------------------------------------------------------
	-- Resolution-scaled positional-SFX attenuation.                              --
	-- CSoundImp::Construct (0x7A8BB0) hardcodes m_nRange (+0x20)=768; init calls  --
	-- CSoundMixer::SetPanRange(1024) -> m_nPanRange (mixer+0xE0). Play (0x7A9DB0) --
	-- & ResetVolume (0x7AA110) attenuate world SFX by squared world-distance from --
	-- the viewport centre, gated by m_nRange, and divide pan by m_nPanRange.      --
	-- Neither scales with resolution, so above 800-wide the viewport half-width   --
	-- outruns 768 and edge sounds hard-mute (960>768 @1920). Scale both by        --
	-- renderWidth/800 (live width @0x8BA31C, same global the HD-UI reads).        --
	-- Overwrite ONLY the imm32 operands so ambient ranges set via CSound::SetRange--
	-- after construction stay intact.                                            --
	--------------------------------------------------------------------------------
	local renderWidth = IEex_ReadWord(0x8BA31C, 0)   -- CVideo::SCREENWIDTH / g_resolution_x
	if renderWidth and renderWidth > 800 then
		local ratio    = renderWidth / 800
		local newRange = math.floor(768  * ratio + 0.5)
		local newPan   = math.floor(1024 * ratio + 0.5)
		IEex_WriteDword(0x7A8C5A, newRange)  -- imm32 of `C7 46 20 <imm32>` (movl [esi+0x20],768) @0x7A8C57 +3
		IEex_WriteDword(0x42629E, newPan)    -- imm32 of `68 <imm32>` (push 1024) @0x42629D +1
	end

	IEex_EnableCodeProtection()

end)()
