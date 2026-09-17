$bytes = [System.IO.File]::ReadAllBytes($args[0])
$peOffset = [BitConverter]::ToInt32($bytes, 60)
$machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
if ($machine -eq 0x14c) { Write-Output "Win32/x86 (32-bit)" }
elseif ($machine -eq 0x8664) { Write-Output "x64 (64-bit)" }
else { Write-Output "Unknown: $($machine.ToString('X4'))" }
