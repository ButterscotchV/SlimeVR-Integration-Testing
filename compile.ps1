$sourceDir = "src"
$targetDir = "dist"

$htmlPath = "/"
$targetHtmlPath = "/"

Write-Host "Copying to target folder..."
Remove-Item –Path "./$targetDir" -Recurse -ErrorAction Ignore
Copy-Item –Path "./$sourceDir" -Destination "./$targetDir" -Recurse

Write-Host "Hashing static assets..."
$assets = Get-ChildItem –Path "./$targetDir/assets" -File –Recurse
foreach ($asset in $assets) {
    # Get an 8 character lowercase SHA256 hash, this is what most use
    $assetHash = (Get-FileHash -Algorithm "SHA256" $asset).Hash.ToLower().Remove(8)

    # Get an HTML friendly relative path
    $relativeAssetPath = (Resolve-Path -Relative $asset).TrimStart('.').Replace('\', '/').TrimStart('/').Substring($targetDir.Length)
    # Add the hash to the HTML friendly relative path
    $relativeAssetPathHashed = $relativeAssetPath.Remove($relativeAssetPath.Length - $asset.Extension.Length) + "-$assetHash" + $asset.Extension

    # Update the start of the paths
    $relativeAssetPath = $htmlPath + $relativeAssetPath.TrimStart('/')
    $relativeAssetPathHashed = $targetHtmlPath + $relativeAssetPathHashed.TrimStart('/')

    # Rename the file to be hashed
    $assetPathHashed = $asset.FullName.Remove($asset.FullName.Length - $asset.Extension.Length) + "-$assetHash" + $asset.Extension
    $asset.MoveTo($assetPathHashed)

    Write-Host "Replacing ""$relativeAssetPath"" with ""$relativeAssetPathHashed"":"

    $sourceFiles = Get-ChildItem –Path "./$targetDir" -File -Include @("*.html", "*.htm", "*.css", "*.js", "*.ts") –Recurse
    foreach ($sourceFile in $sourceFiles) {
        Write-Host "  > Updating ""$sourceFile""..."
        (Get-Content -Path $sourceFile).Replace($relativeAssetPath, $relativeAssetPathHashed) | Set-Content -Path $sourceFile
    }
}

Write-Host "Done!"
