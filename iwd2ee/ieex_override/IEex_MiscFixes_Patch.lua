
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

	IEex_EnableCodeProtection()

end)()
