Set fso = CreateObject("Scripting.FileSystemObject")
Set WshShell = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
exePath = scriptDir & "\NetSpeedTaskbar.exe"
If fso.FileExists(exePath) Then
    WshShell.Run """" & exePath & """", 0, False
Else
    WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File """ & scriptDir & "\NetSpeedTaskbar.ps1""", 0, False
End If
