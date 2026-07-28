
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

	--------------------------------------------------------------------------------------------------------
	-- Action bar: the uses-remaining digit sits in the MIDDLE of the button instead of its bottom-right    --
	-- corner. Invisible at 1x; it only surfaces once the UI runs at the engine's 2x tier.                   --
	--                                                                                                      --
	-- CIcon::RenderIcon (0x4E66E0) anchors the count at icon_origin + LAST_DIGIT_OFFSET * scale, where      --
	-- LAST_DIGIT_OFFSET = (25,25) @0x8D7E68/0x8D7E6C and scale = bDoubleSize ? 2 : 1. It has TWO count      --
	-- branches and only one of them applies that scale:                                                     --
	--     wCount > 0    4E693F  imul eax,[8D7E68]      4E698A  imul eax,[8D7E6C]     -- correct             --
	--     bForceCount   4E6A67  mov  ecx,[8D7E6C]      4E6A6D  mov  eax,[8D7E68]     -- no imul, plain 25   --
	-- So a forced digit always lands at +25,+25. Inside the 32px icon box of the 1x tier that IS the        --
	-- bottom-right corner; at 2x the box is 64px and +25,+25 is its centre. Original Black Isle bug -- the  --
	-- pristine pre-mod exe is byte-identical, and the sibling branch four hundred bytes earlier shows the   --
	-- intent. The glyph itself is already right: NUMBER.BAM ships at 2x and is de-doubled, so only the      --
	-- offset is stuck at 1x.                                                                                --
	--                                                                                                      --
	-- The action bar builds its own geometry rather than reading the CHU -- CInfButtonArray::RenderButton   --
	-- (0x5950F0) passes size = ICON_SIZE_SM * nScale and ptIcon = pt + 3*nScale -- so RenderIcon's          --
	-- centering step is a no-op there and the anchor is exactly pt + (3 + 25) * nScale once scaled: 28 at   --
	-- 1x in a 38px button, 56 at 2x in a 76px one. The same 74% of the button either way.                    --
	--                                                                                                      --
	-- This cannot move the inventory stack count, which is what makes it different from the obvious fix.    --
	-- Retuning NUMBER.BAM's cx/cy reaches every count in the game and drags the inventory and dragged-item  --
	-- ones off their slots with it. This branch does not: 4E69E4 loads bForceCount and 4E69ED skips the     --
	-- whole thing when it is zero, and of the fourteen RenderIcon call sites exactly one passes TRUE --     --
	-- 0x595790, the spell/ability slot of the action bar, when the slot art is STONSPEL/STONSPEC. Inventory --
	-- (0x62E30E), stores, ground containers (0x6963F8) and chargen all pass FALSE and take the already      --
	-- correct wCount branch; the dragged-item cursor is not CIcon at all (CVidInf::RenderPointerImage,      --
	-- 0x79FBA0, which carries its own 1x NUMBER and its own anchor).                                        --
	--                                                                                                      --
	-- Fix: mirror the wCount branch and scale both offsets by ebx, the scale register the function already  --
	-- keeps (the sibling branch reads it identically, and 4E69C7 lea eax,[ebx+ebx*4] is its 5px digit       --
	-- pitch). ebx is callee-saved across the intervening calls; eax and ecx are dead on entry here. imul's  --
	-- flag writes are harmless -- 4E6A72 add ebp,ecx overwrites them before anything branches. Left         --
	-- ungated: the bug is in the stock engine's own 1600/2048-width tiers too, and at 1x imul by 1 is a     --
	-- no-op, so 1x behaviour stays bit-identical.                                                           --
	--------------------------------------------------------------------------------------------------------

	-- mov ecx,[8D7E6C] ; imul ecx,ebx ; mov eax,[8D7E68] ; imul eax,ebx
	-- Both movs are replicated: the 5-byte jmp only covers the first, so resume past the second at 4E6A72.

	IEex_AttemptHook(0x4E6A67,  -- CIcon::RenderIcon (0x4E66E0), bForceCount branch
		{"8B 0D 6C 7E 8D 00 0F AF CB A1 68 7E 8D 00 0F AF C3"},
		{"!jmp_dword :4E6A72"},
		{0x8B, 0x0D, 0x6C, 0x7E, 0x8D})

	--------------------------------------------------------------------------------------------------------
	-- The combat log / message window flickers during cutscenes and dialogues -- in single player only.    --
	--                                                                                                      --
	-- CScreenWorld::AsynchronousUpdate (0x68C3D0) applies eight CheckPanelInputMode(panelId, mask) rules    --
	-- per AI tick, each of them "if (active || inactiveRender) panel->SetEnabled((m_mode & mask) != 0)".    --
	-- Three of those rules resolve their panel through GetPanel_22_0 (mask 0x8), GetPanel_19_0 (0x100) and  --
	-- GetPanel_21_0 (0x100) -- and all three return panel 0 unless a network session is open. So in single  --
	-- player the message window gets three contradictory rules in the SAME tick: 0x8 fails in cutscene      --
	-- (m_mode 0x142) and in dialogue (0x182 / 0x502) and disables the panel, then the two 0x100 rules pass  --
	-- and re-enable it.                                                                                     --
	--                                                                                                      --
	-- Every edge runs the full body of CUIPanel::SetEnabled (0x4D29D0): SetActive over every control -- and --
	-- CUIControlTextDisplay::SetActive unloads and re-registers the combat-log CVidFont, so the log's font  --
	-- texture is destroyed and rebuilt once per tick -- plus SetInactiveRender and InvalidateRect(NULL).    --
	-- CUIPanel::Render (0x4D3100) then draws RenderDither, a 50% black quad, over any frame that samples    --
	-- the FALSE half of the toggle (the flip runs on the AI thread, Render reads m_bEnabled on the main     --
	-- thread without the manager's critical section). That is the flicker. Original Black Isle bug: the     --
	-- stock UI pulses too, it is simply small and low-contrast there, while the floating HUD puts the log   --
	-- AND the whole command band on panel 0.                                                                --
	--                                                                                                      --
	-- Fix: skip the aliased 0x8 rule in single player. Both single-player branches of the inlined           --
	-- GetPanel_22_0 jump to the "panel 0" xor eax,eax at 0x68C6D1; retarget them to the next rule at        --
	-- 0x68C730 instead (both fit in rel8, so no length change).                                             --
	--                                                                                                      --
	-- End-of-tick state is unchanged in every mode. CheckPanelInputMode gates on (m_bActive ||              --
	-- m_bInactiveRender), and SetEnabled(x) sets m_bActive = x and m_bInactiveRender = !x, so it can never  --
	-- close that gate: within a tick the two 0x100 rules fire exactly when the removed 0x8 rule would have, --
	-- and -- running last -- they already decided the final value. Only the intra-tick FALSE excursion is   --
	-- gone. SetEnabled's unconditional tail (m_pManager->field_2E) keeps the same last writer, since the    --
	-- 0x8 rule only ever wrote it when it passed TRUE, which is exactly when the 0x100 rules do too.        --
	--                                                                                                      --
	-- Multiplayer is untouched: there GetPanel_22_0/19_0/21_0 give 22 / 19 / 21, three distinct panels, and --
	-- panel 22 keeps its own 0x8 rule.                                                                      --
	--------------------------------------------------------------------------------------------------------

	if IEex_ReadWord(0x68C6B5, 0) == 0x1A74 and IEex_ReadWord(0x68C6C8, 0) == 0x0774 then
		IEex_WriteAssembly(0x68C6B5, {"!jz_byte", {0x68C730, 1, 1}})  -- je 0x68C6D1 -> je 0x68C730
		IEex_WriteAssembly(0x68C6C8, {"!jz_byte", {0x68C730, 1, 1}})  -- je 0x68C6D1 -> je 0x68C730
	else
		print("[?] Unexpected bytes at 0x68C6B5 / 0x68C6C8 - cutscene panel-0 flap fix not applied.")
	end

	IEex_EnableCodeProtection()

end)()
