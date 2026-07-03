
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
	-- Zoom + resolution-scaled positional-SFX audible radius. CSoundImp::Construct
	-- (0x7A8BB0) hardcodes m_nRange (+0x20)=768 with `mov [esi+0x20],0x300` @0x7A8C57
	-- (7 bytes). Play (0x7A9DB0) + ResetVolume (0x7AA110) mute a world sound past
	-- m_nRange world-units from the viewport centre, so the fixed 768 both mutes edge
	-- casts at hi-res and (once widened) lets you hear the whole map when zoomed in.
	-- Replace the store with a call to IEex_Helper_ScaleSoundRange, which sets m_nRange
	-- to SFX-Audible-Percent of the visible world width (render width / g_fCameraZoom):
	-- per-construction, so casts pick up the live zoom; software renderer keeps zoom=1.0.
	-- Ambient sounds override via CSound::SetRange after construction. The paired
	-- m_nPanRange resolution patch stays in IEex_Extern_InitResolution; do NOT also patch
	-- 0x7A8C5A there (this region is now the jmp below).
	--
	-- Stub bytes: 56 = push esi (CSound* this) as the __stdcall arg; then call helper;
	-- resume at 0x7A8C5E (just past the replaced 7-byte store).
	-- WARNING: never put `--` comments INSIDE a [[ ]] asm block -- the IEex assembler
	-- turns the comment text into 0x00 padding bytes (stray `add [eax],al`), which
	-- corrupts the stub and crashes. Keep asm blocks pure hex + `!` directives.
	--------------------------------------------------------------------------------
	local scaleSoundRangeStub = IEex_WriteAssemblyAuto({[[
		!push_all_registers_iwd2
		56
		!call >IEex_Helper_ScaleSoundRange
		!pop_all_registers_iwd2
		!jmp_dword :7A8C5E
	]]})
	IEex_WriteAssembly(0x7A8C57, IEex_FlattenTable({
		{[[ !jmp_dword ]], {scaleSoundRangeStub, 4, 4}},
		{[[ 90 90 ]]},
	}))

	--------------------------------------------------------------------------------
	-- Elliptical falloff. Play (0x7A9DB0) + ResetVolume (0x7AA110) attenuate by
	-- CIRCULAR world distance dx^2+dy^2 vs m_nRange^2, which over-covers vertically on
	-- a wide screen (you hear further above/below than to the sides). Replace the inline
	-- dx^2+dy^2 at both sites with IEex_Helper_EllipticalSoundDist(dx,dy), which stretches
	-- dy by the live viewport aspect so the audible region matches the screen rectangle
	-- at any aspect (16:9 / 21:9 / 32:9 / 16:10 / 4:3 -- reads live SCREENWIDTH/HEIGHT).
	--
	-- Play @0x7A9ED5 displaces 10 bytes (mov esi,edx; imul eax,eax; imul edx,esi; add
	--   eax,edx); at entry eax=dy, edx=dx, ecx=m_nRange^2. Stub: 8B F2 = mov esi,edx
	--   (dx into esi, callee-saved so it survives the call for the pan divide); 51 = push
	--   ecx (save m_nRange^2, caller-saved); 50 = push eax (arg2 dy); 56 = push esi
	--   (arg1 dx); call helper -> eax=dist; 59 = pop ecx (restore m_nRange^2); jmp to the
	--   cmp @0x7A9EDF. dx is arg1 because __stdcall reads args low-to-high (dx pushed last).
	-- Reset @0x7AA1FA displaces 10 bytes (mov ecx,edi; imul eax,eax; imul ecx,edi; add
	--   eax,ecx); at entry eax=dy, edi=dx (callee-saved so it survives for the pan divide).
	--   Stub: 50 = push eax (arg2 dy); 57 = push edi (arg1 dx); call helper -> eax=dist;
	--   jmp to the cdq @0x7AA204. (No m_nRange^2 live in a register here, nothing to save.)
	--------------------------------------------------------------------------------
	local playDistStub = IEex_WriteAssemblyAuto({[[
		8B F2
		51
		50
		56
		!call >IEex_Helper_EllipticalSoundDist
		59
		!jmp_dword :7A9EDF
	]]})
	IEex_WriteAssembly(0x7A9ED5, IEex_FlattenTable({
		{[[ !jmp_dword ]], {playDistStub, 4, 4}},
		{[[ 90 90 90 90 90 ]]},
	}))

	local resetDistStub = IEex_WriteAssemblyAuto({[[
		50
		57
		!call >IEex_Helper_EllipticalSoundDist
		!jmp_dword :7AA204
	]]})
	IEex_WriteAssembly(0x7AA1FA, IEex_FlattenTable({
		{[[ !jmp_dword ]], {resetDistStub, 4, 4}},
		{[[ 90 90 90 90 90 ]]},
	}))

	--------------------------------------------------------------------------------
	-- PC voices fall off with viewport distance (match positional SFX + NPC voices).
	-- CGameSprite::VerbalConstant (0x702900) plays soundset speech two ways, keyed on
	-- the speaker's alignment:
	--   * EA_PC branch @0x702C3D:  cSound.Play(FALSE)                    -> GLOBAL (full volume)
	--   * else/NPC     @0x702D25:  cSound.Play(m_pos.x, m_pos.y, 0, FALSE) -> POSITIONAL
	-- So vanilla holds your own party's barks at full volume everywhere while NPC/enemy
	-- voices already attenuate as the (zoomed or not) viewport pulls away. Route the PC
	-- branch through the same positional CSound::Play (0x7A9DB0) so PC voices fade with
	-- viewport distance -- but with a WIDER voice range than SFX (see
	-- VOICE_RANGE_SCREEN_WIDTHS below) so a PC at the screen edge is still clearly heard.
	-- strRes.cSound is built by the default CSound ctor (0x7A8BB0) so it inherits the
	-- elliptical falloff for free; the stub overrides m_nRange for audibility.
	--
	-- Replaced region @0x702C37 (11 bytes): 6A00 push 0 (bReplay); 8D4C2434 lea ecx,
	-- [esp+0x34] (&strRes.cSound); E8.. call 0x7A9B10 (global Play). It is immediately
	-- followed by `test al,al` @0x702C42, which consumes Play's BOOL return.
	--
	-- The stub reproduces the NPC branch verbatim: this=esi across the whole function, so
	-- m_pos.x=[esi+6], m_pos.y=[esi+0xA]; push order builds Play(x, y, z=0, bReplay=0);
	-- lea ecx,[esp+0x40] reloads &cSound after the 4 arg pushes (esp is identical at both
	-- branch entries -- PC lea +0x34 after 1 push and NPC lea +0x40 after 4 pushes both
	-- resolve &cSound = entry_esp+0x30). Instead of a call it pushes 0x702C42 as the return
	-- address then jmps into positional Play, whose `ret 0x10` pops that address (landing on
	-- `test al,al`) and cleans the 4 args -> esp is balanced exactly as the original call
	-- left it, with eax = Play's BOOL return. 68 42 2C 70 00 = push 0x00702C42.
	-- WARNING (see above): keep the [[ ]] asm block pure hex + `!` directives, no `--`.
	--------------------------------------------------------------------------------

	-- Voice audible radius = SCREENWIDTH * VOICE_RANGE_SCREEN_WIDTHS, in world units, SET
	-- absolutely each play from the live SCREENWIDTH (USHORT @0x8BA31C). Voices need a much
	-- wider radius than SFX (~0.6 screen) so a PC at the screen edge stays clearly audible:
	-- the quadratic falloff 100*(1-(d/range)^2) leaves the horizontal edge (d ~= 0.5*width)
	-- at ~1-0.25/K^2 -- K=2 => ~94%, reaching silence ~1 screen past the edge. SET (not
	-- multiply) so the sprite's persistent member cSound ([esi+0x4F2C], PlaySound sites 2/3)
	-- can't compound across repeated plays. Not zoom-scaled (IWD2 zoom is >=1, so a fixed
	-- 2*width radius always blankets the visible screen). Raise this to carry voices further.
	-- asm to widen a cSound (its address in a reg R): movzx eax,word[0x8BA31C];
	-- imul eax,eax,K; mov [R+0x20],eax. 0F B7 05 1C A3 8B 00 = movzx from SCREENWIDTH.
	local VOICE_RANGE_SCREEN_WIDTHS = 2
	local voiceKLE = string.format("%02X %02X %02X %02X",
		VOICE_RANGE_SCREEN_WIDTHS % 0x100,
		math.floor(VOICE_RANGE_SCREEN_WIDTHS / 0x100) % 0x100,
		math.floor(VOICE_RANGE_SCREEN_WIDTHS / 0x10000) % 0x100,
		math.floor(VOICE_RANGE_SCREEN_WIDTHS / 0x1000000) % 0x100)

	-- VerbalConstant stub: &strRes.cSound = [esp+0x30] at entry -> edx (scratch); widen its
	-- m_nRange, then run the positional-Play sequence (this cSound already carries a real
	-- m_nArea from its SetChannel, so no area fixup needed here -- unlike PlaySound below).
	local pcVoicePosStub = IEex_WriteAssemblyAuto({[[
		8D 54 24 30
		0F B7 05 1C A3 8B 00
		69 C0 ]] .. voiceKLE .. [[
		89 42 20
		8B 46 0A
		8B 4E 06
		6A 00
		6A 00
		50
		51
		8D 4C 24 40
		68 42 2C 70 00
		!jmp_dword :7A9DB0
	]]})
	IEex_WriteAssembly(0x702C37, IEex_FlattenTable({
		{[[ !jmp_dword ]], {pcVoicePosStub, 4, 4}},
		{[[ 90 90 90 90 90 90 ]]},
	}))

	--------------------------------------------------------------------------------
	-- Same fix for the OTHER PC-voice path: CGameSprite::PlaySound(BYTE soundID,...)
	-- (0x7011E0) is the creature-soundset dispatcher (SELECT=9, SELECT_ACTION=11,
	-- attack/hurt/die, ...) -- this is what a portrait click / selection uses via
	-- CInfGame::SelectCharacter. It has the SAME party-PC vs. other split as
	-- VerbalConstant (routes on CInfGame::GetCharacterPortraitNum): party PCs hit a
	-- GLOBAL CSound::Play(BOOL) (0x7A9B10) while non-PCs hit positional Play (0x7A9DB0).
	-- Three PC global sites, all identical shape:  6A00 push 0 (bReplay); 8BCF mov
	-- ecx,edi (edi = &cSound: a stack strRes at site 1, the sprite's embedded CSound at
	-- [esi+0x4F2C] at sites 2/3); E8.. call 0x7A9B10  (9 bytes). Each is followed by a
	-- `test al,al` (directly, or after a `jmp 0x7027D0`) that consumes Play's BOOL return.
	--
	-- Route each through positional Play so PC selection/action voices fade like the SFX.
	-- this=esi throughout the fn (CGameObject: m_pos @0x06 so x=[esi+6]/y=[esi+0xA],
	-- m_pArea @0x12); &cSound is already in edi.
	--
	-- CRITICAL: unlike VerbalConstant (which SetChannel's its cSound with nArea = m_pArea),
	-- PlaySound's PC branch SetChannel's with nArea = 0 (e.g. @0x70255B: push 0 = nArea).
	-- Positional Play (0x7A9DB0) bails with `ret 0x10` when m_nArea (+0x60) == 0
	-- (@0x7A9DCF) or when m_nArea != m_pSoundMixer->m_nActiveArea (+0xF0, @0x7A9DDA) -- so
	-- calling it as-is made every PC voice SILENT. The stub first writes the speaker's own
	-- m_pArea ([esi+0x12]) into cSound.m_nArea ([edi+0x60]) so the guard passes for an
	-- on-screen PC exactly as it does for the non-PC branch (whose cSound carries a real
	-- area). m_nChannel is left as SetChannel set it; only the area was zero.
	--
	-- Then build Play(x, y, 0, 0), reload this from edi (unclobbered by the pushes), push
	-- the site's own return address, jmp into Play whose `ret 0x10` lands back on `test
	-- al,al` with esp balanced and eax = Play's return. 9-byte site -> 5-byte jmp + 4 NOP.
	-- WARNING (see above): keep the [[ ]] asm block pure hex + `!` directives, no `--`.
	--------------------------------------------------------------------------------
	local function IEex_HookPCVoicePositional(hookAddress, returnAddress)
		local retLE = string.format("%02X %02X %02X %02X",
			returnAddress % 0x100,
			math.floor(returnAddress / 0x100) % 0x100,
			math.floor(returnAddress / 0x10000) % 0x100,
			math.floor(returnAddress / 0x1000000) % 0x100)
		-- Stub: fix m_nArea (edi+0x60) from the sprite (esi+0x12); widen m_nRange (edi+0x20)
		-- to VOICE_RANGE_SCREEN_WIDTHS * SCREENWIDTH; then Play(x, y, 0, 0) with this=edi.
		local stub = IEex_WriteAssemblyAuto({[[
			8B 56 12
			89 57 60
			0F B7 05 1C A3 8B 00
			69 C0 ]] .. voiceKLE .. [[
			89 47 20
			8B 46 0A
			8B 4E 06
			6A 00
			6A 00
			50
			51
			8B CF
			68 ]] .. retLE .. [[
			!jmp_dword :7A9DB0
		]]})
		IEex_WriteAssembly(hookAddress, IEex_FlattenTable({
			{[[ !jmp_dword ]], {stub, 4, 4}},
			{[[ 90 90 90 90 ]]},
		}))
	end
	IEex_HookPCVoicePositional(0x70238F, 0x702398)
	IEex_HookPCVoicePositional(0x70256B, 0x702574)
	IEex_HookPCVoicePositional(0x7027BE, 0x7027C7)

	IEex_EnableCodeProtection()

end)()
