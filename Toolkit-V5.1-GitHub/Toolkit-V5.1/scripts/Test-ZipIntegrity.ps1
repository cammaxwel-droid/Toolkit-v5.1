#requires -Version 5.1
# ZIP integrity scan; reads and decompresses every entry but writes no extracted files.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$p=(Read-Host 'Full path to ZIP to validate').Trim('"')
if(-not (Test-Path -LiteralPath $p -PathType Leaf)){Write-Host 'File not found.' -ForegroundColor Yellow;return}
$z=$null
try{
 $z=[IO.Compression.ZipFile]::OpenRead($p)
 $count=0
 foreach($entry in $z.Entries){
   if($entry.Name){
     $stream=$entry.Open()
     try{$stream.CopyTo([IO.Stream]::Null);$count++}
     finally{$stream.Dispose()}
   }
 }
 Write-Host "Readable ZIP. Verified $count file streams (no extraction)." -ForegroundColor Green
}catch{Write-Host "Invalid, incomplete or unreadable ZIP: $($_.Exception.Message)" -ForegroundColor Red}
finally{if($null -ne $z){$z.Dispose()}}
