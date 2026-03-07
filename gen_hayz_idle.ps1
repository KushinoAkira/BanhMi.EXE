Add-Type -AssemblyName System.Drawing

$base = "c:\Users\WIN11\Documents\FPT\PRU213\BanhMi.EXE\assets\sprites\npc"
$imgPath = Join-Path $base "hayz_full.png"

if (-not (Test-Path $imgPath)) {
    Write-Host "hayz_full.png not found"
    exit 1
}

$bmp = [System.Drawing.Bitmap]::FromFile($imgPath)
$w = $bmp.Width
$h = $bmp.Height

# Values for 8 frames: (offset_y_percent, scale_x, scale_y)
# We add squash (wider + shorter) when moving down, and stretch (thinner + taller) when moving up.
$frames = @(
    @( 0.00,  1.00,  1.00 ), # F1: Rest
    @( 0.03,  1.03,  0.97 ), # F2: Squash down
    @( 0.06,  1.06,  0.93 ), # F3: Squash lowest
    @( 0.01,  0.98,  1.02 ), # F4: Going up fast
    @(-0.04,  0.96,  1.05 ), # F5: Stretch highest
    @(-0.02,  0.97,  1.03 ), # F6: Coming down
    @( 0.00,  1.00,  1.00 ), # F7: Rest
    @( 0.01,  1.01,  0.99 )  # F8: Slight prep
)

for ($i=0; $i -lt 8; $i++) {
    $f = $frames[$i]
    $offsetYPct = $f[0]
    $scaleX = $f[1]
    $scaleY = $f[2]
    
    # Scale down base by 0.9 to ensure no clipping when stretching or translating
    $baseScale = 0.9
    $finalScaleX = $baseScale * $scaleX
    $finalScaleY = $baseScale * $scaleY
    
    $new_w = [int]($w * $finalScaleX)
    $new_h = [int]($h * $finalScaleY)
    
    $outBmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($outBmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    
    # Center horizontally
    $xOffset = [int](($w - $new_w) / 2)
    
    # Base anchor at bottom with 5% margin to avoid clipping
    $baseYOffset = $h - $new_h - [int]($h * 0.05)
    
    # Apply vertical bobbing
    $yOffset = $baseYOffset + [int]($h * $offsetYPct)
    
    $rect = New-Object System.Drawing.Rectangle($xOffset, $yOffset, $new_w, $new_h)
    $g.DrawImage($bmp, $rect)
    $g.Dispose()
    
    $outFile = Join-Path $base "hayz_idle_$($i+1).png"
    $outBmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $outBmp.Dispose()
    Write-Host "Saved $outFile"
}
$bmp.Dispose()
