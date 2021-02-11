powershell -ExecutionPolicy ByPass -Command "Stop-DscConfiguration -Force"
powershell -ExecutionPolicy ByPass -Command "Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Force"
powershell -ExecutionPolicy ByPass -Command "Get-ChildItem C:\Windows\Temp\ | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
