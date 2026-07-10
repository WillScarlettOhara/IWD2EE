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
-- (Phase E replaces this hand list with the generated IEex_HDSprites_List.lua.)
IEex_Helper_RegisterHDSprite("MGO2A1")
IEex_Helper_RegisterHDSprite("CDMB1A1")
