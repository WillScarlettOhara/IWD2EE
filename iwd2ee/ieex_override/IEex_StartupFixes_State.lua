
IEex_AbsoluteOnce("IEex_StartupFixes_Once", function()

	--------------------------------------------------
	-- Detect and fix incorrectly set [Alias] paths --
	--------------------------------------------------

	local hd0Path = IEex_Helper_GetGameDirectory()
	local iniPath = hd0Path.."icewind2.ini"
	IEex_WritePrivateProfileString("Alias", "HD0:", hd0Path, iniPath)

	local cd1Path = hd0Path.."Data\\"
	if IEex_Helper_DirectoryExists(cd1Path) then
		IEex_WritePrivateProfileString("Alias", "CD1:", cd1Path, iniPath)
	end

	local cd2Path = hd0Path.."CD2\\"
	if IEex_Helper_DirectoryExists(cd2Path) then
		IEex_WritePrivateProfileString("Alias", "CD2:", cd2Path, iniPath)
	end

	------------------------------------------------------------------
	-- Make INTRO/MIDDLE/END movies skippable on the very first view --
	------------------------------------------------------------------
	-- Stock engine: CBaldurProjector::PlayMovieInternal forces these
	-- movies non-skippable (field_144=0) unless their [Movies] flag is
	-- already 1 in icewind2.ini. The flag is written by AddPlayedMovie
	-- DURING the first play, but the in-memory skip flag (field_145) is
	-- read before that write and never re-read mid-play -> the intro is
	-- unskippable on a fresh install until the second launch. Pre-seed
	-- the flags so a click skips from the first launch on. (Only enables
	-- skipping; movies still play unless the user clicks.)
	IEex_WritePrivateProfileString("Movies", "INTRO", "1", iniPath)
	IEex_WritePrivateProfileString("Movies", "MIDDLE", "1", iniPath)
	IEex_WritePrivateProfileString("Movies", "END", "1", iniPath)

end)
