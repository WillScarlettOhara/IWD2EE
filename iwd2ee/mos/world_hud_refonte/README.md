# mos/world_hud_refonte

MOS assets owned by the World HUD Refonte component (DESIGNATED 103) -- mirror of
bam/world_hud_refonte for the MOS type. EMPTY today by design:

* B3QKLOOT.MOS (quickloot bar bg) is CORE -- shipped since 2023-11-18, the stock
  quickloot bar renders it without the refonte.
* B3QKLOOM.MOS (minimal variant) is consumed by the runtime "UI Borders = 0" toggle
  (IEex_Gui_Patch.lua GetResObject redirect), which is also core -- moving it here
  would black out the quickloot bar on non-refonte installs.

When the first refonte-ONLY MOS lands, put it here and add
`COPY ~%mod_folder%/mos/world_hud_refonte~ ~override~` to
components/world_hud_refonte.tpa (a COPY of a README-only dir would leak the README
into override, so the COPY line waits for real content).
