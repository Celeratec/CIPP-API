function Compress-CIPPImage {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Re-encodes a JPEG image in-memory at a target quality to reduce file size.
    .DESCRIPTION
        Server-side JPEG compression for the SharePoint Image Optimizer. The function
        decodes the supplied byte array to a raw bitmap and re-encodes it as a JPEG at
        the requested quality. Re-encoding inherently drops EXIF/metadata (camera, GPS,
        creation info) which is the desired behaviour when -StripMetadata is requested.

        Two engines are supported, tried in order:
          1. SkiaSharp  - cross-platform, reliable on Windows/Linux/container hosts.
          2. System.Drawing.Common - built-in fallback, Windows-only (Microsoft does not
             support it on Linux). Used only when SkiaSharp is unavailable.

        If neither engine can be loaded the function returns Success = $false with a
        descriptive error so the caller can surface an actionable per-file message.

        This function NEVER performs any network/SharePoint operation. It only transforms
        bytes in memory, so it is safe to unit test in isolation.
    .PARAMETER ImageBytes
        The original JPEG content as a byte array.
    .PARAMETER Quality
        Target JPEG quality (1-100). Defaults to 82. Values are clamped to 1-100.
    .PARAMETER StripMetadata
        When $true (default) the re-encode drops EXIF/metadata. When $false the function
        still re-encodes (both engines lose most metadata on re-encode) and records a
        warning that metadata preservation is not supported.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [byte[]]$ImageBytes,

        [Parameter(Mandatory = $false)]
        [int]$Quality = 82,

        [Parameter(Mandatory = $false)]
        [bool]$StripMetadata = $true
    )

    # Clamp quality to a sane range.
    if ($Quality -lt 1) { $Quality = 1 }
    if ($Quality -gt 100) { $Quality = 100 }

    $Result = [PSCustomObject]@{
        Success         = $false
        Engine          = $null
        OriginalBytes   = if ($null -eq $ImageBytes) { [long]0 } else { [long]$ImageBytes.Length }
        CompressedBytes = [long]0
        Data            = $null
        Warning         = $null
        Error           = $null
    }

    if (-not $StripMetadata) {
        $Result.Warning = 'Metadata preservation is not supported; re-encoding removes EXIF/metadata.'
    }

    if ($null -eq $ImageBytes -or $ImageBytes.Length -eq 0) {
        $Result.Error = 'No image data supplied.'
        return $Result
    }

    # --- Engine 1: SkiaSharp -------------------------------------------------
    $SkiaAvailable = $false
    try {
        if (-not ('SkiaSharp.SKBitmap' -as [type])) {
            # Attempt to load a SkiaSharp assembly that may be bundled with the Function app.
            $Candidates = @()
            foreach ($Root in @($PSScriptRoot, $env:HOME, $env:FUNCTIONS_WORKER_RUNTIME_PATH, $PWD.Path)) {
                if ($Root) { $Candidates += $Root }
            }
            foreach ($Root in $Candidates) {
                $Dll = Get-ChildItem -Path $Root -Filter 'SkiaSharp.dll' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($Dll) {
                    Add-Type -Path $Dll.FullName -ErrorAction Stop
                    break
                }
            }
        }
        if ('SkiaSharp.SKBitmap' -as [type]) { $SkiaAvailable = $true }
    } catch {
        $SkiaAvailable = $false
    }

    if ($SkiaAvailable) {
        $Bitmap = $null
        $Image = $null
        $EncodedData = $null
        try {
            $Bitmap = [SkiaSharp.SKBitmap]::Decode($ImageBytes)
            if ($null -eq $Bitmap) {
                throw 'SkiaSharp could not decode the image (not a valid/supported JPEG).'
            }
            $Image = [SkiaSharp.SKImage]::FromBitmap($Bitmap)
            $EncodedData = $Image.Encode([SkiaSharp.SKEncodedImageFormat]::Jpeg, $Quality)
            if ($null -eq $EncodedData) {
                throw 'SkiaSharp failed to encode the image.'
            }
            $Bytes = $EncodedData.ToArray()
            $Result.Success = $true
            $Result.Engine = 'SkiaSharp'
            $Result.Data = $Bytes
            $Result.CompressedBytes = [long]$Bytes.Length
            return $Result
        } catch {
            $Result.Error = "SkiaSharp compression failed: $($_.Exception.Message)"
            # fall through to System.Drawing fallback
        } finally {
            if ($EncodedData) { try { $EncodedData.Dispose() } catch {} }
            if ($Image) { try { $Image.Dispose() } catch {} }
            if ($Bitmap) { try { $Bitmap.Dispose() } catch {} }
        }
    }

    # --- Engine 2: System.Drawing.Common (Windows only) ----------------------
    $DrawingAvailable = $false
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        if ('System.Drawing.Bitmap' -as [type]) { $DrawingAvailable = $true }
    } catch {
        $DrawingAvailable = $false
    }

    if ($DrawingAvailable) {
        $InStream = $null
        $OutStream = $null
        $Img = $null
        $EncoderParams = $null
        try {
            $InStream = [System.IO.MemoryStream]::new($ImageBytes)
            $Img = [System.Drawing.Image]::FromStream($InStream, $false, $true)

            $JpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
            if (-not $JpegCodec) {
                throw 'No JPEG codec available in System.Drawing.'
            }

            $QualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
            $EncoderParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
            $EncoderParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($QualityEncoder, [long]$Quality)

            # Removing property items strips EXIF/metadata on save.
            if ($StripMetadata) {
                foreach ($PropId in @($Img.PropertyIdList)) {
                    try { $Img.RemovePropertyItem($PropId) } catch {}
                }
            }

            $OutStream = [System.IO.MemoryStream]::new()
            $Img.Save($OutStream, $JpegCodec, $EncoderParams)
            $Bytes = $OutStream.ToArray()

            $Result.Success = $true
            $Result.Engine = 'System.Drawing'
            $Result.Data = $Bytes
            $Result.CompressedBytes = [long]$Bytes.Length
            # If SkiaSharp had failed earlier we still succeeded; clear that error.
            $Result.Error = $null
            return $Result
        } catch {
            $Result.Error = "System.Drawing compression failed: $($_.Exception.Message)"
            return $Result
        } finally {
            if ($EncoderParams) { try { $EncoderParams.Dispose() } catch {} }
            if ($Img) { try { $Img.Dispose() } catch {} }
            if ($OutStream) { try { $OutStream.Dispose() } catch {} }
            if ($InStream) { try { $InStream.Dispose() } catch {} }
        }
    }

    if (-not $Result.Error) {
        $Result.Error = 'No supported image compression engine is available (SkiaSharp or System.Drawing). See docs/SHAREPOINT_IMAGE_OPTIMIZER.md for deployment requirements.'
    }
    return $Result
}
