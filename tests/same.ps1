# same.ps1 a.png b.png : prints how many pixels differ.
param([string]$a, [string]$b)
Add-Type -AssemblyName System.Drawing
$A = [System.Drawing.Bitmap]::FromFile($a); $B = [System.Drawing.Bitmap]::FromFile($b)
if ($A.Width -ne $B.Width -or $A.Height -ne $B.Height) { "size differs: $($A.Width)x$($A.Height) vs $($B.Width)x$($B.Height)"; exit }
$d = 0
for ($y = 0; $y -lt $A.Height; $y += 1) { for ($x = 0; $x -lt $A.Width; $x += 1) { if ($A.GetPixel($x, $y).ToArgb() -ne $B.GetPixel($x, $y).ToArgb()) { $d++ } } }
"differing pixels: $d"
