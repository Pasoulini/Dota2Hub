Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
scriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
ps = "powershell.exe"
args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & scriptPath & "\Generate-Dota2Hub.ps1" & Chr(34)
objShell.Run ps & " " & args, 0, False
