-- IEex_HDSprites_Patch.lua -- HD Creature Sprites: registered resrefs ship native-2x
-- BAMs; the GL renderer composites their layers into the FX scratch as stock, then the
-- final composite quad is drawn at HALF scale (MODELVIEW wrap inside the RenderTexture
-- trampoline) so the logical world size is unchanged and camera zoom samples 2x texels.
-- Three MaintainOriginal trampolines (bodies in IEexHelper.dll render.cpp):
--   0x7C5330 CVidCell::FXRender3d(7)  arm when the cell's BAM resref is registered
--   0x79CC90 CVidInf::FXBltToBack     halve the ref-point subtraction (mirror-aware)
--   0x7C4240 CVidCell::RenderTexture  wrap original draw in scale(0.5) about the anchor
-- IEEX_HD_SPRITES is WeiDU-managed (the HD Creature Sprites component flips it on
-- install, like IEEX_HD_UI); the 2x BAMs only exist in override/ when installed.

local IEEX_HD_SPRITES = false

local function IEex_HDSprites_DefineOff()
	IEex_Helper_DefineAddress("CVidCell::FXRender3dOriginal", -1)
	IEex_Helper_DefineAddress("CVidInf::FXBltToBackOriginal", -1)
	IEex_Helper_DefineAddress("CVidCell::RenderTextureOriginal", -1)
end

if not IEEX_HD_SPRITES then
	IEex_HDSprites_DefineOff()
	return
end

-- Software-renderer opt-out (stock ini key [Program Options] "3D Acceleration" = 0):
-- the half-scale draw is a GL-path concept; unhooked, the engine runs stock bytes and
-- 1x BAMs from the biffs keep working (the component only adds override/ 2x files).
if IEex_GetPrivateProfileInt("Program Options", "3D Acceleration", 1, ".\\Icewind2.ini") == 0 then
	IEex_HDSprites_DefineOff()
	return
end

IEex_HookReplaceFunctionMaintainOriginal(0x7C5330, 6, "CVidCell::FXRender3dOriginal", {[[
	!jmp_dword >IEex_Helper_CVidCell_FXRender3dHD
]]})
IEex_Helper_DefineAddress("CVidCell::FXRender3dOriginal", IEex_Label("CVidCell::FXRender3dOriginal"))

IEex_HookReplaceFunctionMaintainOriginal(0x79CC90, 6, "CVidInf::FXBltToBackOriginal", {[[
	!jmp_dword >IEex_Helper_CVidInf_FXBltToBackHD
]]})
IEex_Helper_DefineAddress("CVidInf::FXBltToBackOriginal", IEex_Label("CVidInf::FXBltToBackOriginal"))

IEex_HookReplaceFunctionMaintainOriginal(0x7C4240, 6, "CVidCell::RenderTextureOriginal", {[[
	!jmp_dword >IEex_Helper_CVidCell_RenderTextureHD
]]})
IEex_Helper_DefineAddress("CVidCell::RenderTextureOriginal", IEex_Label("CVidCell::RenderTextureOriginal"))

-- Registered HD set: every resref here must have a native-2x BAM in override/.
-- POC: FULL anim sets of the two test creatures -- goblin MGO2 (incl. E mirrors) and
-- unarmed dwarf CDMB1 (walk/stand G1x, attacks A1-9, cast CA, SA/SS/SX) -- a single
-- action anim alone (the first attempt) is invisible on an idle/walking creature.
-- (Phase E replaces this hand list with the generated IEex_HDSprites_List.lua.)
for _, resref in ipairs({
	"MGO2A1", "MGO2A1E", "MGO2A4", "MGO2A4E", "MGO2DE", "MGO2DEE", "MGO2GH", "MGO2GHE",
	"MGO2GU", "MGO2GUE", "MGO2SC", "MGO2SCE", "MGO2SD", "MGO2SDE", "MGO2SL", "MGO2SLE",
	"MGO2TW", "MGO2TWE", "MGO2WK", "MGO2WKE",
	"CDMB1A1", "CDMB1A2", "CDMB1A3", "CDMB1A4", "CDMB1A5", "CDMB1A6", "CDMB1A7",
	"CDMB1A8", "CDMB1A9", "CDMB1CA", "CDMB1G1", "CDMB1G11", "CDMB1G12", "CDMB1G13",
	"CDMB1G14", "CDMB1G15", "CDMB1G16", "CDMB1G17", "CDMB1G18", "CDMB1G19",
	"CDMB1SA", "CDMB1SS", "CDMB1SX",
}) do
	IEex_Helper_RegisterHDSprite(resref)
end
