Add-Type -Name FG -Namespace NFG -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);' -ErrorAction SilentlyContinue
$p = Get-Process duckstation* | Select-Object -First 1
[NFG.FG]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
