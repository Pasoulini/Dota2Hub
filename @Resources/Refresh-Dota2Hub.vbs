Set objShell = CreateObject("WScript.Shell")
scriptPath = objShell.ExpandEnvironmentStrings("%USERPROFILE%") & "\Documents\Rainmeter\Skins\Dota2Hub\@Resources"
ps = "powershell.exe"
args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & scriptPath & "\Generate-Dota2Hub.ps1" & Chr(34) & " -RefreshRainmeter"
objShell.Run ps & " " & args, 0, True
