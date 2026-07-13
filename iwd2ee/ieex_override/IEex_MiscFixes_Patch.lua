
(function()

	IEex_DisableCodeProtection()

	--------------------------------------------------------------------------------------------------------
	-- The engine attempts to flag bought store items as Identified. This makes little sense, as the item --
	-- transferred to the party is still unidentified. This also causes a crash, as the store cannot find --
	-- the bought item to remove it from its stock due to the identify flag suddenly changing.            --
	--------------------------------------------------------------------------------------------------------

	IEex_WriteAssembly(0x54C2A5, {"!repeat(3,!nop)"})

	--------------------------------------------------------------------------------------------------------
	-- Character creation, spell MEMORISE panels: the title is one level too high -- you pick your level-1  --
	-- spells on "Arcane Spell Selection: Level 1" and the very next screen says "Memorize Arcane Spells:   --
	-- Level 2", for those same level-1 spells.                                                             --
	--                                                                                                      --
	-- CScreenCreateChar::m_nSpellLevel (BYTE @ this+0x14A2) is not just a display value: it doubles as the --
	-- loop counter of the spell-level walk in sub_617D80, written as                                       --
	--     for (m_nSpellLevel = 1; m_nSpellLevel <= field_14A3; ++m_nSpellLevel)                            --
	-- with the counter kept in the MEMBER instead of a local. The increment is stored back before the      --
	-- bound test (0x618B54 inc dl / 0x618B5A mov [esi+14A2],dl / 0x618B60 ja exit), so once the loop ends  --
	-- the member holds max+1. field_14A3 is a constant 1 -- written once, in the ctor at 0x606B3E, and     --
	-- never updated -- so chargen walks exactly one spell level and m_nSpellLevel is left at 2.            --
	--                                                                                                      --
	-- ResetArcaneSpellsPanel (0x60A5C0) is immune only because it happens to re-init m_nSpellLevel = 1 at  --
	-- its top. The three MEMORISE panels print the member verbatim and never re-init it, so all three show --
	-- the stale counter (arcane, divine and domain alike -- clerics/druids/paladins get it too).           --
	--                                                                                                      --
	-- Fix: do what the learn panel does -- force m_nSpellLevel = 1 on entry. Chargen only ever memorises   --
	-- level 1 (field_14A3 == 1), and the panels do not use the member to choose WHICH spells to list (they --
	-- already list the level-1 ones while it reads 2), so this only corrects the printed number.           --
	-- __thiscall: ecx = this at the entry, before the SEH prologue runs.                                   --
	--------------------------------------------------------------------------------------------------------

	IEex_AttemptHook(0x60A920,  -- CScreenCreateChar::ResetMemorizeArcaneSpellsPanel
		{"C6 81 A2 14 00 00 01"},  -- mov byte ptr [ecx+0x14A2], 1
		{"6A FF 68 08 9F 82 00 !jmp_dword :60A927"},
		{0x6A, 0xFF, 0x68, 0x08, 0x9F, 0x82, 0x00})

	IEex_AttemptHook(0x60AF60,  -- CScreenCreateChar::ResetMemorizeDivineSpellsPanel
		{"C6 81 A2 14 00 00 01"},
		{"6A FF 68 38 9F 82 00 !jmp_dword :60AF67"},
		{0x6A, 0xFF, 0x68, 0x38, 0x9F, 0x82, 0x00})

	IEex_AttemptHook(0x60B610,  -- CScreenCreateChar::ResetMemorizeDomainSpellsPanel
		{"C6 81 A2 14 00 00 01"},
		{"6A FF 68 68 9F 82 00 !jmp_dword :60B617"},
		{0x6A, 0xFF, 0x68, 0x68, 0x9F, 0x82, 0x00})

	--------------------------------------------------------------------------------------------------------
	-- Character creation, spell MEMORISE panels: the spell icons sit 16px right and 16px down of their     --
	-- slot, and the slot then clips them -- only the icon's top-left corner shows. Invisible at 1x; it     --
	-- only surfaces once the UI runs at the engine's 2x tier.                                              --
	--                                                                                                      --
	-- CIcon::RenderIcon (0x4E66E0) centres the icon in the control rect against a HARDCODED 32x32 basis,   --
	-- scaled by its bDoubleSize ARGUMENT:                                                                  --
	--     scale = bDoubleSize ? 2 : 1;  x += (width - 32*scale) / 2;  y += (height - 32*scale) / 2;        --
	-- The chargen spell buttons are 40x39 at 1x -> 80x78 at 2x, and the well in SPLBUT.BAM is 64x64 at     --
	-- (8,7). With the right bDoubleSize the inset is ((80-64)/2, (78-64)/2) = (8,7) -- exactly the well.    --
	--                                                                                                      --
	-- The LEARN panel's render (CUIControlButtonCharGenKnownArcaneSpellSelection::Render, 0x61B750) passes --
	-- the real m_pPanel->m_pManager->m_bDoubleSize:                                                         --
	--     61B893  push eax             ; dwFlags     = disabled ? 1 : 0                                     --
	--     61B894  mov  eax,[edx]       ; edx = m_pPanel -> m_pManager                                       --
	--     61B896  mov  ecx,[eax+0xAA]  ; m_bDoubleSize                                                      --
	--     61B89C  push ecx             ; bDoubleSize                                                        --
	-- The two MEMORISE renders never load m_bDoubleSize at all. They push a literal 0 into dwFlags and the --
	-- DISABLED flag into the bDoubleSize slot -- the two arguments are simply wrong:                        --
	--     620AB0  push 0x0             ; dwFlags                                                            --
	--     620AB2  push eax             ; bDoubleSize = disabled ? 1 : 0                                     --
	-- A slot that holds a spell is enabled, so eax = 0 -> scale = 1 -> inset = ((80-32)/2, (78-32)/2) =     --
	-- (24,23) = well + (16,16). At 1x the correct m_bDoubleSize is 0 as well, so the wrong argument happens --
	-- to equal the right one and nothing shows. Original Black Isle bug: the pristine pre-mod exe is        --
	-- byte-identical at both call sites.                                                                    --
	--                                                                                                      --
	-- Fix: push the real m_bDoubleSize, exactly as the learn panel does. esi = this in both renders (each   --
	-- opens with mov esi,ecx) and m_pPanel is at this+0x6. eax is left untouched. dwFlags stays at its      --
	-- vanilla 0: a memorise slot with no spell has an empty resref and draws no icon at all (CIcon.cpp:29), --
	-- so the missing TINT_DISABLED has nothing to tint -- not worth changing 1x behaviour for.              --
	--------------------------------------------------------------------------------------------------------

	-- push 0 ; push 0 (dwFlags) ; edx = m_pPanel ; edx = m_pManager ; ecx = m_bDoubleSize ; push ecx
	-- Replaces "6A 00 6A 00 50" outright (3 pushes in, 3 pushes out -- esp is unchanged at the jump back).

	IEex_AttemptHook(0x620AAE,  -- CUIControlButtonCharGenMemorizedArcaneSpellSelection::Render (0x620970)
		{"6A 00 6A 00 8B 56 06 8B 12 8B 8A AA 00 00 00 51"},
		{"!jmp_dword :620AB3"},
		{0x6A, 0x00, 0x6A, 0x00, 0x50})

	IEex_AttemptHook(0x62140E,  -- CUIControlButtonCharGenMemorizedDivineSpellSelection::Render (0x6212D0; divine + domain)
		{"6A 00 6A 00 8B 56 06 8B 12 8B 8A AA 00 00 00 51"},
		{"!jmp_dword :621413"},
		{0x6A, 0x00, 0x6A, 0x00, 0x50})

	IEex_EnableCodeProtection()

end)()
