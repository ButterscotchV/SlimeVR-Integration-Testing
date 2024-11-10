$sourceDir = "src"
$targetDir = "dist"

$htmlPath = "/"
$targetHtmlPath = "/"

Write-Host "Copying to target folder..."
Remove-Item –Path "./$targetDir" -Recurse -ErrorAction Ignore
Copy-Item –Path "./$sourceDir" -Destination "./$targetDir" -Recurse

Write-Host "Compiling markdown checklist(s)..."
$markdownAssets = Get-ChildItem –Path "./$targetDir" -File -Include @("*.checkmd") –Recurse
foreach ($asset in $markdownAssets) {
    $htmlContent = ""
    $testId = 0
    $headerLevel = 0

    $markdownContent = Get-Content -Path $asset
    foreach ($line in $markdownContent) {
        $line = $line.Trim()
        if ($line.Length -le 0) {
            continue
        }

        # Start of a new header
        if ($line.StartsWith("#")) {
            $headerEnd = $line.IndexOf(" ")
            if ($headerEnd -le 0) {
                continue
            }

            $header = $line.Remove($headerEnd)
            # +1 to remove space
            $headerLabel = $line.Substring($headerEnd + 1)

            if ($header.Length -gt $headerLevel) {
                # Increment the actual header level
                $headerLevel++
            }
            else {
                # If there's 0 difference, that means it's a new section on the same level, so we need to add 1 to handle it
                $headerLevelDiff = ($headerLevel - $header.Length) + 1

                # Close each header over the difference
                foreach ($i in 1..$headerLevelDiff) {
                    $htmlContent += "</fieldset>"
                }

                # Now the header level is what was defined
                $headerLevel = $header.Length
            }

            # Write the header
            $htmlContent += "<fieldset><legend>$headerLabel</legend>"
        }
        # Return to header level (a little hacky but required for formatting)
        elseif ($line.StartsWith("/#")) {
            # Remove "/"
            $header = $line.Substring(1)
            $headerLevelDiff = $headerLevel - $header.Length

            if ($headerLevelDiff -le 0) {
                # Targeting higher headers than the current will break and going to the same one is useless
                continue
            }

            # Close each header over the difference
            foreach ($i in 1..$headerLevelDiff) {
                $htmlContent += "</fieldset>"
            }

            # Now the header level is what was defined
            $headerLevel = $header.Length
        }
        # New checkbox in current header
        else {
            $htmlContent += "<div><input type=""checkbox"" id=""test$testId"" name=""test$testId""/><label for=""test$testId"">$line</label></div>"
            $testId++
        }
    }

    # Close any remaining headers
    foreach ($i in 1..$headerLevel) {
        $htmlContent += "</fieldset>"
    }

    # Replace requested sections with the compiled markdown
    $replaceToken = "{checklist}$((Resolve-Path -Relative $asset).TrimStart('.').Replace('\', '/').TrimStart('/').Substring($targetDir.Length)){/checklist}"
    Write-Host "Replacing ""$replaceToken"" with compiled markdown:"

    $sourceFiles = Get-ChildItem –Path "./$targetDir" -File -Include @("*.html", "*.htm", "*.css", "*.js", "*.ts") –Recurse
    foreach ($sourceFile in $sourceFiles) {
        Write-Host "  > Updating ""$sourceFile""..."
        (Get-Content -Path $sourceFile -Raw).Replace($replaceToken, $htmlContent) | Set-Content -Path $sourceFile
    }

    # The markdown source is no longer needed, delete it
    $asset.Delete()
}

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
        (Get-Content -Path $sourceFile -Raw).Replace($relativeAssetPath, $relativeAssetPathHashed) | Set-Content -Path $sourceFile
    }
}

Write-Host "Minifying HTML..."
$minifyFiles = Get-ChildItem –Path "./$targetDir" -File -Include @("*.html", "*.htm") –Recurse
foreach ($minifyFile in $minifyFiles) {
    Write-Host "  > Updating ""$minifyFile""..."
    (Get-Content -Path $minifyFile -Raw).ReplaceLineEndings("").Replace("    ", "") | Set-Content -Path $minifyFile
}

Write-Host "Done!"
