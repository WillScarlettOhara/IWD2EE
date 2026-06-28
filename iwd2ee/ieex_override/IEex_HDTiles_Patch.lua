
(function()

	IEex_DisableCodeProtection()

	-- Software-renderer opt-out (stock ini key [Program Options] "3D Acceleration" = 0): the GL
	-- tile-texture cache (CreateSurfaces3d / Render3d) is unused under the software renderer -- skip
	-- both patches. See IEex_Render_Patch.lua. Default 1 = GL on (current behaviour, unchanged).
	if IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") == 0 then
		return
	end

	--------------------------------------------------------------------------------
	-- HD tiles: enlarge the GL tile-texture cache for high resolutions (up to 4K)
	--
	-- The OpenGL renderer caches each visible map tile as a GL texture, keyed by a
	-- fixed pool slot. CVidInf::CreateSurfaces3d hardcodes the pool to 780 tiles
	-- (m_nVRamSurfaces = 780). When more tiles are visible than the pool holds
	-- (1440p ~984, 4K ~2135), the overflow tiles fall to the slow path in
	-- CInfTileSet::Render3d and are re-uploaded with glTexImage2D EVERY frame ->
	-- heavy lag that scales with resolution.
	--
	-- The pool-size bump itself is a plain exe patch (m_nVRamSurfaces = 4096). But
	-- the tiles' GL texture ids are computed as `m_nVRamTile + 9` (base 9), and the
	-- engine's fonts / UI use DYNAMIC ids (glGenTextures) that pack just above the
	-- old 780 pool. Growing the pool extends the fixed tile-id range (9..N) into
	-- those dynamic ids -> tiles overwrite font textures -> garbled text. So we also
	-- relocate the tile-id base far above any dynamic id.
	--
	-- CInfTileSet::Render3d @0x5D2A2F:  lea ebx,[ecx+9]   (ecx = m_nVRamTile)
	-- Replace the +9 with +0x2000 (8192) so tile ids sit at 8192..(8192+pool),
	-- well clear of the low dynamic font/UI ids. Detour because disp8 (+9) can't
	-- hold a large base in place; re-run the displaced `test [eax+0x70],2` and
	-- continue at 0x5D2A36.
	--------------------------------------------------------------------------------

	IEex_AttemptHook(0x5D2A2F, {[[
		8D 99 00 20 00 00
	]]}, {[[
		F6 40 70 02 !jmp_dword :5D2A36
	]]}, {0x8D, 0x59, 0x09, 0xF6, 0x40})

	-- Pool SIZE bump (the other half): CVidInf::CreateSurfaces3d @0x7BE023 hardcodes
	--   mov [esi+0x67c], 780   (m_nVRamSurfaces = the tile-texture cache slot count)
	-- 780 overflows above ~1440p (1440p ~984-1476 visible tiles, 4K ~2135 + scroll/anim
	-- churn), and overflow tiles take the per-frame glTexImage2D re-upload path -> heavy
	-- world lag scaling with resolution. Raise the imm32 (VA 0x7BE029) to 4096 -> covers
	-- 4K with headroom. In-memory (survives verify+repair). Safe with the tile-id base
	-- relocation above (ids 8192..8192+pool stay clear of dynamic font/UI texture ids).
	IEex_WriteDword(0x7BE029, 4096)

	--------------------------------------------------------------------------------
	-- FOG-OF-WAR -> TEXTURE -- the 4K perf fix (~47.7% of frame -> a few GL calls).
	-- Stock fog draws the visibility grid as ~8000 per-cell quads/fans via FillRect3d
	-- (0x7BD140) + RenderFan (0x7BD740) (only callers = CVisibility). SKIP both, and at
	-- the tiles->sprites boundary in CGameArea::Render (0x47785b, esi=CGameArea) read
	-- CVisibilityMap::m_pMap directly, decode to a tiny (W+1)x(H+1) corner texture, and
	-- draw ONE bilinear quad over the map rect + hard-black off-map margins. Inline hook
	-- passes esi; pushad/popad preserves eax for the displaced RENDER_MESSAGESCREEN cmp.
	-- FogSkip = __cdecl ret 0 (binary ABI, both callers).
	--------------------------------------------------------------------------------
	IEex_WriteAssembly(0x7BD140, {[[
		!jmp_dword >IEex_Helper_FogSkip
	]]})
	IEex_WriteAssembly(0x7BD740, {[[
		!jmp_dword >IEex_Helper_FogSkip
	]]})
	IEex_HookRestore(0x47785B, 0, 6, {[[
		!push_all_registers_iwd2
		!push_esi
		!call >IEex_Helper_FogTexDraw
		!pop_all_registers_iwd2
	]]})

	--------------------------------------------------------------------------------
	-- Stop feeding the now-dead stock fog tile list (fixes the 4K exit crash + the
	-- per-frame .data corruption behind it).
	--
	-- CInfTileSet::RenderTexture @0x5D2D20 appends one TEXTURE record per visible
	-- 64px tile to the FIXED array m_aTextures[2700] @0x8E7E40 via the UNBOUNDED
	-- counter m_nTextures @0x8F2700 (iwd2-re flags it: "the number of elements is not
	-- validated"). At 4K ~3000+ tiles/frame > 2700 -> the appends spill past the array
	-- end (0x8E7E40 + 2700*16 = 0x8F2700) into the const CString globals that follow;
	-- element 3096 zeroes CScreenInventory::OPTION_PAUSE_WARNING.m_pchData @0x8F3FC0,
	-- so the CRT's static ~CString at process exit runs InterlockedDecrement(0 - 12)
	-- -> write AV at 0xFFFFFFF4 (the 4K-only IEex crash dump in <game>\crash). <=1440p
	-- (~1350 tiles) stays under 2700, hence no crash there.
	--
	-- The array's ONLY consumer is CInfTileSet::RenderFogOfWar @0x5D2DE0, whose draw
	-- chain (BltFogOWar3d -> BltVisibility3d/BltExploration3d -> FillRect3d 0x7BD140 /
	-- RenderFan 0x7BD740) is FogSkip'd just above -> the records are DEAD in GL mode
	-- (our corner-grid fog texture replaced them). So skip the append outright: the
	-- tile still draws (CVidTile::RenderTexture runs at 0x5D2D70, BEFORE the append),
	-- then jump from the append site @0x5D2D75 straight to the function epilogue
	-- @0x5D2DCC (pop edi/esi/ebx; ret 0x18). The append region net-pushes nothing and
	-- the cull path already jumps to 0x5D2DCC, so esp is balanced. Net: m_nTextures
	-- stays 0 -> RenderFogOfWar loops zero times, no overflow, and ~3000 dead stores/
	-- frame are saved. 6->6 byte overwrite: mov ecx,[0x8F2700] (8B 0D 00 27 8F 00) ->
	-- jmp rel32 (E9 52 00 00 00) + nop.
	--------------------------------------------------------------------------------
	IEex_WriteAssembly(0x5D2D75, {[[
		!jmp_dword :5D2DCC
		!nop
	]]})

	--------------------------------------------------------------------------------
	-- TILE ATLAS (perf, GL 1.1 only) -- gated by [IEex Options] "Tile Atlas" (off by
	-- default). Pack the per-tile textures into one 4096x4096 atlas and draw all visible
	-- tiles in ~2 batched glDrawArrays instead of ~3295 per-tile bind + immediate-mode
	-- quad. Measured bottleneck (warm cache, ~0 uploads/frame) = those bind+draws.
	-- (1) Replace the per-tile draw CVidTile::RenderTexture (0x7C64F0) -> batch. It is
	--     __thiscall(this, nTextureId, rDest&, x, y, dwFlags); marshal nTextureId/x/y/
	--     dwFlags to the __stdcall export (mark_esp adjusts for the pushes), then ret 0x14.
	-- (2) Populate the atlas: after the engine's per-tile glTexImage2D inside ReadyTexture
	--     (@0x7C6187, displaces `mov edx,[0x8CF6D8]` = 6 bytes), copy m_pPixels (0xA09FC8)
	--     into the tile's atlas cell. Fires only on cold/lighting re-uploads (~0/frame).
	-- Flush is driven from Export_FogTexDraw (tiles->sprites boundary), before the fog.
	if IEex_GetPrivateProfileInt("IEex Options", "Tile Atlas", 0, ".\\Icewind2.ini") ~= 0 then
		IEex_WriteAssembly(0x7C64F0, {[[
			!mark_esp
			!marked_esp !push([esp+0x14])
			!marked_esp !push([esp+0x10])
			!marked_esp !push([esp+0x0C])
			!marked_esp !push([esp+0x04])
			!call >IEex_Helper_TileAtlasDraw
			!ret_word 14 00
		]]})
		IEex_HookRestore(0x7C6187, 0, 6, {[[
			!push_all_registers_iwd2
			!call >IEex_Helper_TileAtlasUpload
			!pop_all_registers_iwd2
		]]})
	end

end)()
