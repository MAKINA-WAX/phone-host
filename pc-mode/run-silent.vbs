' Silently run watch-reconnect.bat (window style 0 = no console flash)
Set sh = CreateObject("WScript.Shell")
sh.Run "cmd /c """"" & Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "watch-reconnect.bat""""", 0, False