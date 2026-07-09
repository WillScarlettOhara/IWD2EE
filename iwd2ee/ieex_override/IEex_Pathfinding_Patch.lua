
-- IEex_Pathfinding_Patch.lua — GemRB-inspired pathfinding behavior improvements.
--
-- Master gate: [IEex Options] "Improved Pathfinding" (Icewind2.ini), default 1.
-- Boot-gates the raw byte patches only; the DLL policy seams install always
-- and self-gate at runtime (vanilla-exact when 0).
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

	-- Master toggle. The DLL policies re-read this key at runtime and return
	-- exact vanilla decisions when 0, so the detour seams (phases 2-5) are
	-- installed UNCONDITIONALLY — that keeps the "Path Log" walk-timing
	-- instrumentation available in vanilla mode for A/B travel-time runs, and
	-- makes the in-game toggle live in both directions. Only the raw byte
	-- patches below (phase-1 constants, phase-4b), which have no runtime gate,
	-- honor the toggle at boot.
	local IEex_PF_MasterEnabled =
		IEex_GetPrivateProfileInt("IEex Options", "Improved Pathfinding", 1, ".\\Icewind2.ini") ~= 0

	-- Verify original bytes at address before patching; skip + log on mismatch
	-- (exe drift / foreign mod protection).
	local IEex_PF_Patched = 0
	local IEex_PF_Total = 0
	local function IEex_PF_VerifyBytes(address, expectedBytes)
		IEex_PF_Total = IEex_PF_Total + 1
		for i = 1, #expectedBytes do
			local actual = IEex_ReadByte(address + i - 1, 0)
			if actual ~= expectedBytes[i] then
				print(string.format(
					"[IEex_Pathfinding] SKIP patch @0x%X: byte %d is 0x%02X, expected 0x%02X",
					address, i - 1, actual, expectedBytes[i]))
				return false
			end
		end
		IEex_PF_Patched = IEex_PF_Patched + 1
		return true
	end

	IEex_DisableCodeProtection()

	if IEex_PF_MasterEnabled then

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

	end

	--------------------------------------------------------------------------
	-- Phases 2+3 — behavior-policy detours inside CGameSprite::AIUpdateWalk --
	-- (0x6F9040). Two decision seams route through IEexHelper policies; the --
	-- rest of the function stays engine bytes. Policies return the exact    --
	-- vanilla decision when "IP Behavior Flags"=0 or in multiplayer.        --
	--                                                                       --
	-- Seam 1 @0x6F9651 (waypoint-arrival test, reached only when the        --
	-- half-cell check failed):                                              --
	--     cmp ecx,edi        ; ecx = distSq(pos,posDest)                    --
	--     jl  0x6F9AB3       ; edi = distSq(posOld,posDest)                 --
	--   eax route: 0 = continue movement (0x6F9AB3)                         --
	--              1 = waypoint transition/arrival (0x6F9659)               --
	--              2 = return from function (SEH slot -1, epilogue 0x6FA7E7)--
	--                                                                       --
	-- Seam 2 @0x6F9CF7 (next-cell mobile-cost check; old cell already       --
	-- RemoveObject'd, al = GetMobileCost result):                           --
	--     cmp al,[0x84D6A3]  ; COST_IMPASSABLE                              --
	--     jne 0x6F9F22                                                      --
	--   eax route: 0 = vanilla (engine ClearBumpPath + revert, 0x6F9D03)    --
	--              1 = cell usable (AddObject + sounds, 0x6F9F22)           --
	--              2 = handled by policy (visibility/exit, 0x6FA665)        --
	--              3 = vanilla revert, skip engine ClearBumpPath (0x6F9D1C) --
	--------------------------------------------------------------------------

	if IEex_LabelDefault("IEex_Helper_PF_ArrivalPolicy", nil) then

		-- Cave bytes (raw hex kept minimal; NO comments inside [[ ]] - assembler footgun):
		--   51 52 53 55 56 57       push ecx/edx/ebx/ebp/esi/edi (ebx is LIVE into both
		--                           arrival and continue paths: 0x6F972C / 0x6F9B48 read [ebx])
		--   57 51 56                push edi (distPrevSq), ecx (distNowSq), esi (this) - stdcall args
		--   5F 5E 5D 5B 5A 59       pop edi/esi/ebp/ebx/edx/ecx (eax = route survives)
		--   83 F8 01/02             cmp eax,1 / cmp eax,2
		--   C7 44 24 60 FF..        mov dword [esp+0x60],-1 (SEH unwind slot, as 0x6FA7DF does)
		-- All three routing targets re-establish their own flags (mov+test/cmp at entry).
		if IEex_PF_VerifyBytes(0x6F9651, {0x3B, 0xCF, 0x0F, 0x8C, 0x5A, 0x04, 0x00, 0x00}) then
			local arrivalCave = IEex_WriteAssemblyAuto({[[
				51 52 53 55 56 57
				57
				51
				56
				!call >IEex_Helper_PF_ArrivalPolicy
				5F 5E 5D 5B 5A 59
				83 F8 01
				!je_dword :6F9659
				83 F8 02
				!jne_dword :6F9AB3
				C7 44 24 60 FF FF FF FF
				!jmp_dword :6FA7E7
			]]})
			IEex_WriteAssembly(0x6F9651, IEex_FlattenTable({
				{"!jmp_dword", {arrivalCave, 4, 4}},
				{"!repeat(3,!nop)"},
			}))
		end

		--   0F B6 C0                movzx eax,al (al = GetMobileCost result at the seam)
		--   50 56                   push eax (cost), esi (this) - stdcall args
		--   rest as seam-1 cave; all four targets set their own flags at entry.
		if IEex_PF_VerifyBytes(0x6F9CF7, {0x3A, 0x05, 0xA3, 0xD6, 0x84, 0x00, 0x0F, 0x85, 0x1F, 0x02, 0x00, 0x00}) then
			local collisionCave = IEex_WriteAssemblyAuto({[[
				51 52 53 55 56 57
				0F B6 C0
				50
				56
				!call >IEex_Helper_PF_CollisionPolicy
				5F 5E 5D 5B 5A 59
				83 F8 01
				!je_dword :6F9F22
				83 F8 02
				!je_dword :6FA665
				83 F8 03
				!je_dword :6F9D1C
				!jmp_dword :6F9D03
			]]})
			IEex_WriteAssembly(0x6F9CF7, IEex_FlattenTable({
				{"!jmp_dword", {collisionCave, 4, 4}},
				{"!repeat(7,!nop)"},
			}))
		end

	else
		print("[IEex_Pathfinding] helper policies not exported by IEexHelper.dll - detours skipped (constants pack still active)")
	end

	--------------------------------------------------------------------------
	-- Phase 4 — enemy unstick (ClearBumpPath @0x6FA900, combat conga fix).  --
	-- Gate seam @0x6FA929 replaces "cmp al,[EA_GOODCUTOFF] / jbe proceed":  --
	-- with [IEex Options] "IP Enemy Bumping"=1 (default), EA>30 sprites may --
	-- bump too, but PF_BumpObstaclePolicy (seam @0x6FACBB, replaces the     --
	-- m_bBumpable/field_54B8 skip pair) forbids shoving EA<=30 obstacles -- --
	-- enemies displace their own side only, never PCs.                      --
	-- Cave regs: ebx=bumper(this), esi=obstacle; both callee-saved by the   --
	-- stdcall policies; eax/ecx/edx dead at all four targets (verified).    --
	--------------------------------------------------------------------------

	if IEex_LabelDefault("IEex_Helper_PF_BumpGatePolicy", nil) then

		if IEex_PF_VerifyBytes(0x6FA929, {0x3A, 0x05, 0x3B, 0x7C, 0x84, 0x00, 0x76, 0x07}) then
			local bumpGateCave = IEex_WriteAssemblyAuto({[[
				0F B6 C0
				50
				53
				!call >IEex_Helper_PF_BumpGatePolicy
				85 C0
				!jne_dword :6FA938
				33 C0
				!jmp_dword :6FB417
			]]})
			IEex_WriteAssembly(0x6FA929, IEex_FlattenTable({
				{"!jmp_dword", {bumpGateCave, 4, 4}},
				{"!repeat(3,!nop)"},
			}))
		end

		if IEex_PF_VerifyBytes(0x6FACBB, {
			0x8B, 0x86, 0xA8, 0x54, 0x00, 0x00, 0x85, 0xC0, 0x0F, 0x84, 0xC4, 0x06, 0x00, 0x00,
			0x8B, 0x86, 0xB8, 0x54, 0x00, 0x00, 0x85, 0xC0, 0x0F, 0x85, 0xB6, 0x06, 0x00, 0x00,
		}) then
			local bumpObstacleCave = IEex_WriteAssemblyAuto({[[
				56
				53
				!call >IEex_Helper_PF_BumpObstaclePolicy
				85 C0
				!je_dword :6FB38D
				!jmp_dword :6FACD7
			]]})
			IEex_WriteAssembly(0x6FACBB, IEex_FlattenTable({
				{"!jmp_dword", {bumpObstacleCave, 4, 4}},
				{"!repeat(23,!nop)"},
			}))
		end

	end

	--------------------------------------------------------------------------
	-- Phase 6 — combat slide ("IP Combat Slide", default 1). Seam @0x6FAFF5 --
	-- in ClearBumpPath's shove-destination loop replaces the candidate      --
	-- validation "cmp al,[COST_IMPASSABLE] / jne place" (al = GetCost of a   --
	-- neighbor cell; policy consulted only for vanilla-rejected candidates). --
	-- A same-side ally mid melee attack may slide onto a cell rejected only  --
	-- for personal-space ring overlap — the cells around its own target —    --
	-- so corridor fights stop jamming single-file. The policy re-validates   --
	-- statics (GetLOSCost: terrain+doors, no actor bits) and refuses any     --
	-- cell that is the CENTER cell of a nearby live sprite.                  --
	-- Cave regs: ebx = bumper(this); [esp+0x48/0x4C] = candidate cell;       --
	-- [esp+0x14] = pObstacle; esi/edi = jump destination (preserved).        --
	-- Routes: accept -> 0x6FB014 (AddObject + JumpToPoint), reject ->        --
	-- 0x6FAFFD (next candidate); both targets re-establish their own flags.  --
	--------------------------------------------------------------------------

	if IEex_LabelDefault("IEex_Helper_PF_BumpSlidePolicy", nil) then

		if IEex_PF_VerifyBytes(0x6FAFF5, {0x3A, 0x05, 0xA3, 0xD6, 0x84, 0x00, 0x75, 0x17}) then
			local slideCave = IEex_WriteAssemblyAuto({[[
				3A 05 A3 D6 84 00
				!jne_dword :6FB014
				51 52 53 55 56 57
				8B 44 24 64
				50
				8B 44 24 64
				50
				8B 44 24 34
				50
				53
				!call >IEex_Helper_PF_BumpSlidePolicy
				5F 5E 5D 5B 5A 59
				85 C0
				!jne_dword :6FB014
				!jmp_dword :6FAFFD
			]]})
			IEex_WriteAssembly(0x6FAFF5, IEex_FlattenTable({
				{"!jmp_dword", {slideCave, 4, 4}},
				{"!repeat(3,!nop)"},
			}))
		end

		-- CanAnimate @0x6FB5D7: the weapon ability-type branch keeps only
		-- RANGED attackers (type 2/4) bumpable during ATTACK actions; melee
		-- falls to the WAIT/FACE-only list and turns non-bumpable the moment
		-- it swings -- the front fighter is ungatherable, so combat shoves
		-- never happen. Route the melee fallthrough through the policy: party
		-- melee uses the attack whitelist too (combat slide gated). esi = the
		-- sprite (this), bx = weapon ability type; both loop targets set
		-- their own registers/flags.
		if IEex_PF_VerifyBytes(0x6FB5D7, {
			0x66, 0x83, 0xFB, 0x04, 0x74, 0x2B, 0x66, 0x83, 0xFB, 0x02, 0x74, 0x25,
		}) then
			local canAnimCave = IEex_WriteAssemblyAuto({[[
				66 83 FB 04
				!je_dword :6FB608
				66 83 FB 02
				!je_dword :6FB608
				51 52 53 55 56 57
				0F B7 C3
				50
				56
				!call >IEex_Helper_PF_CanAnimatePolicy
				5F 5E 5D 5B 5A 59
				85 C0
				!jne_dword :6FB608
				!jmp_dword :6FB5E3
			]]})
			IEex_WriteAssembly(0x6FB5D7, IEex_FlattenTable({
				{"!jmp_dword", {canAnimCave, 4, 4}},
				{"!repeat(7,!nop)"},
			}))
		end

		-- Crowd gate @0x6FAB7B: "count = dynByte>>1; if (count > 7) return FALSE"
		-- on the goal cell. Any adjacent NON-bumpable stamp (the enemy being
		-- fought!) adds 8, so melee shoves aborted here before ever reaching
		-- the destination loop above. The cave keeps the vanilla store to
		-- [esp+0x13] (the raw count still feeds the end-of-function checks)
		-- and only overrides the abort decision. ebx = bumper (stable).
		if IEex_PF_VerifyBytes(0x6FAB7B, {
			0xD0, 0xE8, 0x3C, 0x07, 0x88, 0x44, 0x24, 0x13, 0x0F, 0x87, 0xEB, 0xFE, 0xFF, 0xFF,
		}) then
			local crowdCave = IEex_WriteAssemblyAuto({[[
				D0 E8
				88 44 24 13
				3C 07
				!jbe_dword :6FAB89
				51 52 53 55 56 57
				0F B6 C0
				50
				53
				!call >IEex_Helper_PF_BumpCrowdPolicy
				5F 5E 5D 5B 5A 59
				85 C0
				!jne_dword :6FAB89
				!jmp_dword :6FAA74
			]]})
			IEex_WriteAssembly(0x6FAB7B, IEex_FlattenTable({
				{"!jmp_dword", {crowdCave, 4, 4}},
				{"!repeat(9,!nop)"},
			}))
		end

	end

	--------------------------------------------------------------------------
	-- Phase 4b (optional, default OFF) — search-side soft-block: keep       --
	-- m_bBump for EA>30 search requests too (enemy searches then soft-cost  --
	-- through bumpable allies instead of hard-blocking). @0x54961E jbe->jmp --
	-- skips the bBump=FALSE forcing in SearchThreadMain. Risk: enemies path --
	-- through the party line then grind (4a refuses to shove PCs).          --
	--------------------------------------------------------------------------

	if IEex_PF_MasterEnabled
	and IEex_GetPrivateProfileInt("IEex Options", "IP Enemy Soft Block", 0, ".\\Icewind2.ini") ~= 0 then
		if IEex_PF_VerifyBytes(0x54961E, {0x76, 0x0F}) then
			IEex_WriteAssembly(0x54961E, {"EB"})
		end
	end

	--------------------------------------------------------------------------
	-- Phase 5 — directed destination adjust. Whole-replace of               --
	-- CGameArea::SnapshotAdjustTarget @0x46A630 (worker thread, ret 0x14).  --
	-- Vanilla line-probe first (exact port); on failure, expanding ring     --
	-- search (r=1..6) around the goal picks the nearest passable snapshot   --
	-- cell, tie-broken toward the approach side ("stop just before" an      --
	-- occupied destination). Gated by "IP Directed Adjust" (default 1)      --
	-- inside the DLL; vanilla-exact when off.                               --
	--------------------------------------------------------------------------

	if IEex_LabelDefault("IEex_Helper_PF_SnapshotAdjustTarget", nil) then
		if IEex_PF_VerifyBytes(0x46A630, {0x83, 0xEC, 0x14, 0x8B, 0x44, 0x24, 0x20}) then
			IEex_WriteAssembly(0x46A630, {"!jmp_dword >IEex_Helper_PF_SnapshotAdjustTarget !nop !nop"})
		end
	end

	IEex_EnableCodeProtection()

	print(string.format("[IEex_Pathfinding] loaded (%d/%d sites patched)", IEex_PF_Patched, IEex_PF_Total))

end)()
