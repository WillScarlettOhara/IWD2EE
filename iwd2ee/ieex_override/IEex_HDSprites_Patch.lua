-- IEex_HDSprites_Patch.lua -- HD Creature Sprites: registered resrefs ship native-2x
-- BAMs; the GL renderer composites their layers into the FX scratch as stock, then the
-- final composite quad is drawn at HALF scale (MODELVIEW wrap inside the RenderTexture
-- trampoline) so the logical world size is unchanged and camera zoom samples 2x texels.
-- Two MaintainOriginal trampolines (bodies in IEexHelper.dll render.cpp):
--   0x7C5330 CVidCell::FXRender3d(7)  arm when the cell's BAM resref is registered
--   0x79CC90 CVidInf::FXBltToBack     halve the ref-point subtraction (mirror-aware)
-- The third link -- 0x7C4240 CVidCell::RenderTexture, which wraps the original draw in
-- scale(0.5) about the anchor -- is hooked unconditionally by IEex_UIScale_Patch.lua (it
-- also serves the sub-4K world tooltip), so this file must NOT re-hook it or redefine
-- CVidCell::RenderTextureOriginal; UIScale loads first (IEex_IWD2_Patch.lua file list).
-- IEEX_HD_SPRITES is WeiDU-managed (the HD Creature Sprites component flips it on
-- install, like IEEX_HD_UI); the 2x BAMs only exist in override/ when installed.

local IEEX_HD_SPRITES = false

local function IEex_HDSprites_DefineOff()
	IEex_Helper_DefineAddress("CVidCell::FXRender3dOriginal", -1)
	IEex_Helper_DefineAddress("CVidInf::FXBltToBackOriginal", -1)
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

-- the hook writes below land in .text -- protection must be off (crash at the first
-- IEex_WriteAssembly otherwise; every patch file brackets its writes like this)
IEex_DisableCodeProtection()

IEex_HookReplaceFunctionMaintainOriginal(0x7C5330, 6, "CVidCell::FXRender3dOriginal", {[[
	!jmp_dword >IEex_Helper_CVidCell_FXRender3dHD
]]})
IEex_Helper_DefineAddress("CVidCell::FXRender3dOriginal", IEex_Label("CVidCell::FXRender3dOriginal"))

IEex_HookReplaceFunctionMaintainOriginal(0x79CC90, 6, "CVidInf::FXBltToBackOriginal", {[[
	!jmp_dword >IEex_Helper_CVidInf_FXBltToBackHD
]]})
IEex_Helper_DefineAddress("CVidInf::FXBltToBackOriginal", IEex_Label("CVidInf::FXBltToBackOriginal"))

-- (0x7C4240 CVidCell::RenderTexture is hooked by IEex_UIScale_Patch.lua -- see the header.)

IEex_EnableCodeProtection()

-- Registered HD set: every resref here must have a native-2x BAM in override/.
-- POC roster (GENERATED from hd_sprites_wip/poc/): goblin MGO2 (incl. E mirrors),
-- dwarf male CDMB1, human male+female CHMB/CHFB armor tiers 1-3 -- full anim sets;
-- a single action anim alone is invisible on an idle/walking creature.
-- (Phase E replaces this list with the generated IEex_HDSprites_List.lua.)
for _, resref in ipairs({
	"CDMB1A1", "CDMB1A2", "CDMB1A3", "CDMB1A4", "CDMB1A5", "CDMB1A6", "CDMB1A7",
	"CDMB1A8", "CDMB1A9", "CDMB1CA", "CDMB1G1", "CDMB1G11", "CDMB1G12", "CDMB1G13",
	"CDMB1G14", "CDMB1G15", "CDMB1G16", "CDMB1G17", "CDMB1G18", "CDMB1G19", "CDMB1SA",
	"CDMB1SS", "CDMB1SX", "CHFB1A1", "CHFB1A2", "CHFB1A3", "CHFB1A4", "CHFB1A5",
	"CHFB1A6", "CHFB1A7", "CHFB1A8", "CHFB1A9", "CHFB1CA", "CHFB1G1", "CHFB1G11",
	"CHFB1G12", "CHFB1G13", "CHFB1G14", "CHFB1G15", "CHFB1G16", "CHFB1G17", "CHFB1G18",
	"CHFB1G19", "CHFB1SA", "CHFB1SS", "CHFB1SX", "CHFB2A1", "CHFB2A2", "CHFB2A3",
	"CHFB2A4", "CHFB2A5", "CHFB2A6", "CHFB2A7", "CHFB2A8", "CHFB2A9", "CHFB2CA",
	"CHFB2G1", "CHFB2G11", "CHFB2G12", "CHFB2G13", "CHFB2G14", "CHFB2G15", "CHFB2G16",
	"CHFB2G17", "CHFB2G18", "CHFB2G19", "CHFB2SA", "CHFB2SS", "CHFB2SX", "CHFB3A1",
	"CHFB3A2", "CHFB3A3", "CHFB3A4", "CHFB3A5", "CHFB3A6", "CHFB3A7", "CHFB3A8",
	"CHFB3A9", "CHFB3CA", "CHFB3G1", "CHFB3G11", "CHFB3G12", "CHFB3G13", "CHFB3G14",
	"CHFB3G15", "CHFB3G16", "CHFB3G17", "CHFB3G18", "CHFB3G19", "CHFB3SA", "CHFB3SS",
	"CHFB3SX", "CHMB1A1", "CHMB1A2", "CHMB1A3", "CHMB1A4", "CHMB1A5", "CHMB1A6",
	"CHMB1A7", "CHMB1A8", "CHMB1A9", "CHMB1CA", "CHMB1G1", "CHMB1G11", "CHMB1G12",
	"CHMB1G13", "CHMB1G14", "CHMB1G15", "CHMB1G16", "CHMB1G17", "CHMB1G18", "CHMB1G19",
	"CHMB1SA", "CHMB1SS", "CHMB1SX", "CHMB2A1", "CHMB2A2", "CHMB2A3", "CHMB2A4",
	"CHMB2A5", "CHMB2A6", "CHMB2A7", "CHMB2A8", "CHMB2A9", "CHMB2CA", "CHMB2G1",
	"CHMB2G11", "CHMB2G12", "CHMB2G13", "CHMB2G14", "CHMB2G15", "CHMB2G16", "CHMB2G17",
	"CHMB2G18", "CHMB2G19", "CHMB2SA", "CHMB2SS", "CHMB2SX", "CHMB3A1", "CHMB3A2",
	"CHMB3A3", "CHMB3A4", "CHMB3A5", "CHMB3A6", "CHMB3A7", "CHMB3A8", "CHMB3A9",
	"CHMB3CA", "CHMB3G1", "CHMB3G11", "CHMB3G12", "CHMB3G13", "CHMB3G14", "CHMB3G15",
	"CHMB3G16", "CHMB3G17", "CHMB3G18", "CHMB3G19", "CHMB3SA", "CHMB3SS", "CHMB3SX",
	"MGO2A1", "MGO2A1E", "MGO2A4", "MGO2A4E", "MGO2DE", "MGO2DEE", "MGO2GH",
	"MGO2GHE", "MGO2GU", "MGO2GUE", "MGO2SC", "MGO2SCE", "MGO2SD", "MGO2SDE",
	"MGO2SL", "MGO2SLE", "MGO2TW", "MGO2TWE", "MGO2WK", "MGO2WKE",
}) do
	IEex_Helper_RegisterHDSprite(resref)
end
