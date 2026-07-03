
-- IEex_Pathfinding_Patch.lua — GemRB-inspired pathfinding behavior improvements.
--
-- Master gate: [IEex Options] "Improved Pathfinding" (Icewind2.ini), default 1.
--
-- Phase 1 — constants pack (this file, lua-only). Byte-verified in-place patches;
-- any site whose original bytes mismatch is skipped (logged), never blind-poked.
--
--   VA        | fn                          | original                | patched                 | effect
--   ----------+-----------------------------+-------------------------+-------------------------+---------------------------------------------
--   0x73F706  | CGameSprite::MoveToPoint    | 0F BF 0D A6 BB 85 00    | B9 08 00 00 00 90 90    | give-up retries 4 -> 8
--             |                             | (movsx ecx,[0x85BBA6])  | (mov ecx,8)             | NOTE: word .rdata 4 @0x85BBA6 is SHARED with
--             |                             |                         |                         | CGameSprite::Turn (0x75B15B) -> patch the
--             |                             |                         |                         | instruction, never the global.
--   0x73F321  | CGameSprite::MoveToObject   | 0F BF 0D A4 BB 85 00    | B9 04 00 00 00 90 90    | pursuit re-path throttle 8 -> 4 ticks
--             |                             | (movsx ecx,[0x85BBA4])  | (mov ecx,4)             | single site: 2nd arm (idiv @0x73F40B)
--             |                             |                         |                         | reuses ecx.
--   0x549480  | SearchThreadMain            | 75 19 (jne)             | 90 90                   | collision re-searches keep path smoothing
--             |                             |                         |                         | (request carries GetPathSmooth(); the jne
--             |                             |                         |                         | forced m_pathSmooth=FALSE for them).
--   0x707B05  | SetTarget(CPoint&,BOOL)     | 0F (imm32 lo of         | 08                      | collision stand-still rand()%15 -> rand()%8
--   0x707E2A  | SetTarget(CSearchRequest*,) |     mov ecx,0xF)        | 08                      | (less dead time when two walkers meet)
--
-- Phase 2+ (DLL): whole-function port of CGameSprite::AIUpdateWalk @0x6F9040
-- (installed below when the helper export exists).

(function()

	if IEex_Vanilla then
		return
	end

	if IEex_GetPrivateProfileInt("IEex Options", "Improved Pathfinding", 1, ".\\Icewind2.ini") == 0 then
		return
	end

	-- Verify original bytes at address before patching; skip + log on mismatch
	-- (exe drift / foreign mod protection).
	local function IEex_PF_VerifyBytes(address, expectedBytes)
		for i = 1, #expectedBytes do
			local actual = IEex_ReadByte(address + i - 1, 0)
			if actual ~= expectedBytes[i] then
				print(string.format(
					"[IEex_Pathfinding] SKIP patch @0x%X: byte %d is 0x%02X, expected 0x%02X",
					address, i - 1, actual, expectedBytes[i]))
				return false
			end
		end
		return true
	end

	IEex_DisableCodeProtection()

	---------------------------------------------------------------
	-- MoveToPoint give-up retries 4 -> 8                        --
	--   (m_curAction.m_specificID2 > N -> ACTION_ERROR;         --
	--    GemRB uses MAX_PATH_TRIES = 8)                         --
	---------------------------------------------------------------

	if IEex_PF_VerifyBytes(0x73F706, {0x0F, 0xBF, 0x0D, 0xA6, 0xBB, 0x85, 0x00}) then
		IEex_WriteAssembly(0x73F706, {"B9 08 00 00 00 90 90"})
	end

	---------------------------------------------------------------
	-- MoveToObject pursuit re-path throttle 8 -> 4 ticks        --
	--   (tighter chase of moving targets)                       --
	---------------------------------------------------------------

	if IEex_PF_VerifyBytes(0x73F321, {0x0F, 0xBF, 0x0D, 0xA4, 0xBB, 0x85, 0x00}) then
		IEex_WriteAssembly(0x73F321, {"B9 04 00 00 00 90 90"})
	end

	---------------------------------------------------------------
	-- Keep path smoothing on collision re-searches              --
	--   (vanilla forces m_pathSmooth=FALSE for them -> jagged   --
	--    panic paths after every bump)                          --
	---------------------------------------------------------------

	if IEex_PF_VerifyBytes(0x549480, {0x75, 0x19}) then
		IEex_WriteAssembly(0x549480, {"90 90"})
	end

	---------------------------------------------------------------
	-- Collision stand-still delay rand()%15 -> rand()%8         --
	--   (both SetTarget variants; GemRB backoff is RAND(8,16)   --
	--    ticks but its tick is denser - %8 keeps the jitter     --
	--    de-sync purpose with half the dead time)               --
	---------------------------------------------------------------

	if IEex_PF_VerifyBytes(0x707B04, {0xB9, 0x0F, 0x00, 0x00, 0x00}) then
		IEex_WriteAssembly(0x707B05, {"08"})
	end

	if IEex_PF_VerifyBytes(0x707E29, {0xB9, 0x0F, 0x00, 0x00, 0x00}) then
		IEex_WriteAssembly(0x707E2A, {"08"})
	end

	IEex_EnableCodeProtection()

end)()
