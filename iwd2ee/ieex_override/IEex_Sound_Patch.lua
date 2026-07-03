
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
	-- Zoom + resolution-scaled positional-SFX audible radius. CSoundImp::Construct  --
	-- @0x7A8BB0 hardcodes m_nRange (+0x20)=768 (`mov [esi+0x20],0x300` @0x7A8C57,    --
	-- 7 bytes). Play (0x7A9DB0) + ResetVolume (0x7AA110) mute a world sound past     --
	-- m_nRange world-units from the viewport centre, so the fixed 768 both mutes     --
	-- edge casts at hi-res AND (once widened for resolution) lets you hear the whole --
	-- map when zoomed in. Replace the store with a call to IEex_Helper_ScaleSoundRange,--
	-- which sets m_nRange = 768 * SCREENWIDTH / (800 * g_fCameraZoom) -- the faithful --
	-- 800x600 falloff re-based onto the VISIBLE world width (render width / zoom).    --
	-- Per-construction, so casts/combat pick up the live zoom; software renderer keeps--
	-- zoom=1.0 (pure resolution scaling). Ambient sounds override via CSound::SetRange--
	-- after construction, keeping their authored range. Paired m_nPanRange resolution --
	-- patch stays in IEex_Extern_InitResolution; do NOT also patch 0x7A8C5A there now --
	-- (this region is a jmp to the stub below).                                      --
	--------------------------------------------------------------------------------
	local scaleSoundRangeStub = IEex_WriteAssemblyAuto({[[
		!push_all_registers_iwd2
		56                                          -- push esi (CSound* this) -> __stdcall arg
		!call >IEex_Helper_ScaleSoundRange
		!pop_all_registers_iwd2
		!jmp_dword :7A8C5E                            -- resume after the replaced 7-byte store
	]]})
	IEex_WriteAssembly(0x7A8C57, IEex_FlattenTable({
		{[[ !jmp_dword ]], {scaleSoundRangeStub, 4, 4}},
		{[[ 90 90 ]]},                                -- pad the 5-byte jmp to the 7-byte store
	}))

	--------------------------------------------------------------------------------
	-- Elliptical falloff. Play (0x7A9DB0) + ResetVolume (0x7AA110) attenuate by      --
	-- CIRCULAR world distance dx^2+dy^2 vs m_nRange^2, which over-covers vertically   --
	-- on a wide screen (hear further above/below than sideways). Replace the inline   --
	-- dx^2+dy^2 at both sites with IEex_Helper_EllipticalSoundDist(dx,dy), which       --
	-- stretches dy by the live viewport aspect so the audible region matches the       --
	-- screen rectangle at any aspect (16:9 / 21:9 / 32:9 / 16:10 / 4:3 -- live res).  --
	--                                                                                 --
	-- Play  @0x7A9ED5: displaced 10B (mov esi,edx; imul eax,eax; imul edx,esi; add    --
	--   eax,edx); at entry eax=dy, edx=dx, ecx=m_nRange^2. Set esi=dx (callee-saved,  --
	--   used by the pan divide), save/restore ecx, call helper -> eax=dist, resume    --
	--   at the cmp @0x7A9EDF.                                                          --
	-- Reset @0x7AA1FA: displaced 10B (mov ecx,edi; imul eax,eax; imul ecx,edi; add    --
	--   eax,ecx); at entry eax=dy, edi=dx (callee-saved, used by the pan divide);     --
	--   call helper -> eax=dist, resume at the cdq @0x7AA204.                          --
	--------------------------------------------------------------------------------
	local playDistStub = IEex_WriteAssemblyAuto({[[
		8B F2                                       -- mov esi,edx (dx -> esi, callee-saved for pan)
		51                                          -- push ecx (save m_nRange^2)
		50                                          -- push eax (arg2: dy)
		56                                          -- push esi (arg1: dx)
		!call >IEex_Helper_EllipticalSoundDist
		59                                          -- pop ecx (restore m_nRange^2)
		!jmp_dword :7A9EDF
	]]})
	IEex_WriteAssembly(0x7A9ED5, IEex_FlattenTable({
		{[[ !jmp_dword ]], {playDistStub, 4, 4}},
		{[[ 90 90 90 90 90 ]]},                     -- pad the 5-byte jmp to the 10-byte displaced region
	}))

	local resetDistStub = IEex_WriteAssemblyAuto({[[
		50                                          -- push eax (arg2: dy)
		57                                          -- push edi (arg1: dx, callee-saved for pan)
		!call >IEex_Helper_EllipticalSoundDist
		!jmp_dword :7AA204
	]]})
	IEex_WriteAssembly(0x7AA1FA, IEex_FlattenTable({
		{[[ !jmp_dword ]], {resetDistStub, 4, 4}},
		{[[ 90 90 90 90 90 ]]},                     -- pad the 5-byte jmp to the 10-byte displaced region
	}))

	IEex_EnableCodeProtection()

end)()
