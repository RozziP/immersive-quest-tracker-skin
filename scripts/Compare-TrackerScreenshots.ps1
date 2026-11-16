# Compare the same unscaled rectangle in two lossless screenshots.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $StockPath,
    [Parameter(Mandatory)] [string] $PresetPath,
    [Parameter(Mandatory)] [ValidateRange(0, 2147483647)] [int] $X,
    [Parameter(Mandatory)] [ValidateRange(0, 2147483647)] [int] $Y,
    [Parameter(Mandatory)] [ValidateRange(1, 2147483647)] [int] $Width,
    [Parameter(Mandatory)] [ValidateRange(1, 2147483647)] [int] $Height,
    [Parameter(Mandatory)] [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing.Common

$stockFile = (Resolve-Path -LiteralPath $StockPath).ProviderPath
$presetFile = (Resolve-Path -LiteralPath $PresetPath).ProviderPath
$outputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ([IO.Path]::GetExtension($outputFile) -ne '.png' -or $outputFile -in @($stockFile, $presetFile)) {
    throw 'Choose a separate PNG file for the comparison output.'
}

$stock = $preset = $comparison = $canvas = $null
try {
    $stock = [System.Drawing.Bitmap]::new($stockFile)
    $preset = [System.Drawing.Bitmap]::new($presetFile)
    if ($stock.RawFormat.Guid -ne [System.Drawing.Imaging.ImageFormat]::Png.Guid -or
        $preset.RawFormat.Guid -ne [System.Drawing.Imaging.ImageFormat]::Png.Guid) {
        throw 'Use PNG screenshots captured without lossy compression.'
    }
    if ($stock.Width -ne $preset.Width -or $stock.Height -ne $preset.Height) {
        throw 'Both screenshots must have the same pixel dimensions.'
    }
    if (($X + $Width) -gt $stock.Width -or ($Y + $Height) -gt $stock.Height) {
        throw 'The comparison rectangle extends outside the screenshots.'
    }

    $comparison = [System.Drawing.Bitmap]::new(3 * $Width, $Height)
    $canvas = [System.Drawing.Graphics]::FromImage($comparison)
    $canvas.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $canvas.Clear([System.Drawing.Color]::Black)

    $crop = [System.Drawing.Rectangle]::new($X, $Y, $Width, $Height)
    $left = [System.Drawing.Rectangle]::new(0, 0, $Width, $Height)
    $middle = [System.Drawing.Rectangle]::new($Width, 0, $Width, $Height)
    $canvas.DrawImage($stock, $left, $crop, [System.Drawing.GraphicsUnit]::Pixel)
    $canvas.DrawImage($preset, $middle, $crop, [System.Drawing.GraphicsUnit]::Pixel)
    $canvas.Dispose()
    $canvas = $null

    $changedPixels = 0L
    $diffLeft = 2 * $Width
    $difference = [System.Drawing.Color]::Magenta
    for ($row = 0; $row -lt $Height; $row++) {
        for ($column = 0; $column -lt $Width; $column++) {
            $before = $stock.GetPixel($X + $column, $Y + $row).ToArgb()
            $after = $preset.GetPixel($X + $column, $Y + $row).ToArgb()
            if ($before -ne $after) {
                $changedPixels++
                $comparison.SetPixel($diffLeft + $column, $row, $difference)
            }
        }
    }

    $comparison.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $totalPixels = [long] $Width * $Height
    [pscustomobject] @{
        Identical = $changedPixels -eq 0
        ChangedPixels = $changedPixels
        TotalPixels = $totalPixels
        OutputPath = $outputFile
    }
} finally {
    foreach ($resource in @($canvas, $comparison, $preset, $stock)) {
        if ($null -ne $resource) { $resource.Dispose() }
    }
}

if ($changedPixels -gt 0) { exit 1 }
