
(function()

	IEex_DisableCodeProtection()

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

end)()
