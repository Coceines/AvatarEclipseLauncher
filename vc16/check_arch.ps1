$lib = "vc16\ultralight-sdk\lib\Ultralight.lib"
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $lib).Path)
$peOffset = [BitConverter]::ToInt32($bytes, 60)
$machine = [BitConverter]::ToInt16($bytes, $peOffset + 4)
Write-Host "Machine type: 0x$($machine.ToString('X4'))"
if ($machine -eq 0x14C) { Write-Host "Architecture: x86 (32-bit)" }
elseif ($machine -eq 0x8664) { Write-Host "Architecture: x64 (64-bit)" }
else { Write-Host "Architecture: Unknown ($machine)" }
