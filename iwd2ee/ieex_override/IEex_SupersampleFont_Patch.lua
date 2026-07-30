-- =====================================================================================
-- SUPERSAMPLE FLOATING-TEXT FONT  (2x UI "non-pixelated fonts" option)
-- =====================================================================================
-- CGameText's floating world text is a CPU Blt8To32 into the world surface -> pixelated 1-bit
-- glyphs, and AA at the stock ~8px cap is too coarse to look smooth. The option instead ships
-- IEEXFLT.BAM as a NATIVE-2x AA atlas (Play Bold), and IEex_Helper_CGameText_RenderHD takes over
-- CGameText::Render entirely: each line is redrawn as sharp GL quads (cached atlas path) plus a
-- translucent readability panel. The block FOLLOWS the world (its anchor is mapped through the
-- camera zoom) but its SIZE does not: one atlas texel per screen pixel at every zoom level, with
-- the block snapped to whole pixels, so the glyphs are texel-exact and look the same zoomed out as
-- zoomed in. The draw used to be half scale UNDER the zoom matrix, which minified the 2x atlas at
-- zoom 1-2 and gave back the mush the option exists to remove. [IEex Options] "Floating Text Size"
-- (percent) scales it for players who want the text bigger than the atlas. The metric hooks below
-- keep the engine's SetText word-wrap and cull rect consistent with the size actually drawn (a
-- no-op at the default). GL only (the whole path is OpenGL).
if IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") == 0 then
	return
end

IEex_DisableCodeProtection()

-- CVidFont::TextOut3d @0x7A1210 -- wrap a registered font's draw in a MODELVIEW scale about the
-- anchor (7-byte prologue: push -1 / push 0x845028). The overlay itself calls the TRAMPOLINE (no
-- re-entry); this wrap only protects any other cached-path consumer of a registered font, and it
-- is inert unless "Floating Text Size" is off 100.
IEex_HookReplaceFunctionMaintainOriginal(0x7A1210, 7, "CVidFont::TextOut3dOriginal", {[[
	!jmp_dword >IEex_Helper_CVidFont_TextOut3dHD
]]})
IEex_Helper_DefineAddress("CVidFont::TextOut3dOriginal", IEex_Label("CVidFont::TextOut3dOriginal"))

-- CVidFont::CreateTexture @0x7A0F00 -- force LINEAR on a registered font's 2x atlas (5-byte
-- prologue: lea eax,[esp+8] / push esi). NEAREST would drop or duplicate texels at any scale that
-- is not exactly 1.0, which "Floating Text Size" above 100 is.
IEex_HookReplaceFunctionMaintainOriginal(0x7A0F00, 5, "CVidFont::CreateTextureOriginal", {[[
	!jmp_dword >IEex_Helper_CVidFont_CreateTextureHD
]]})
IEex_Helper_DefineAddress("CVidFont::CreateTextureOriginal", IEex_Label("CVidFont::CreateTextureOriginal"))

-- CGameText::Render @0x4CBB20 -- OWN the floating-text render for registered fonts: sharp GL
-- overlay + readability panel, stock path skipped (7-byte prologue: push -1 / push 0x813e88).
IEex_HookReplaceFunctionMaintainOriginal(0x4CBB20, 7, "CGameText::RenderOriginal", {[[
	!jmp_dword >IEex_Helper_CGameText_RenderHD
]]})
IEex_Helper_DefineAddress("CGameText::RenderOriginal", IEex_Label("CGameText::RenderOriginal"))

-- The engine word-wraps floating text at SetText time from the FONT's metrics, and that layout is
-- rendered at "Floating Text Size" -- so report the DRAWN size here or the wrap is computed against
-- the wrong width (when the draw was 0.5x, lines broke ~2x too early and m_nMaxLines came out half,
-- dumping the overflow onto one long last line). Both are 5-byte prologues (mov eax,ds:0x8cf6d8).
IEex_HookReplaceFunctionMaintainOriginal(0x793050, 5, "CVidFont::GetFontHeightOriginal", {[[
	!jmp_dword >IEex_Helper_CVidFont_GetFontHeightHD
]]})
IEex_Helper_DefineAddress("CVidFont::GetFontHeightOriginal", IEex_Label("CVidFont::GetFontHeightOriginal"))

IEex_HookReplaceFunctionMaintainOriginal(0x792D40, 5, "CVidFont::GetStringLengthOriginal", {[[
	!jmp_dword >IEex_Helper_CVidFont_GetStringLengthHD
]]})
IEex_Helper_DefineAddress("CVidFont::GetStringLengthOriginal", IEex_Label("CVidFont::GetStringLengthOriginal"))

IEex_EnableCodeProtection()

-- Only IEEXFLT (CGameText floating world text) ships a native-2x atlas here. A registered resref
-- WITHOUT a 2x BAM would be drawn at the size of its own 1x cells, i.e. half of what it is meant to
-- be -- so register exactly the fonts this option ships 2x BAMs for.
IEex_Helper_RegisterSupersampleFont("IEEXFLT")
