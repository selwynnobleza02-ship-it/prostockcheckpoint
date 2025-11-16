# PowerShell Script to Consolidate All Dart Files for PDF Export
# This creates a single text file with all your Dart source code

$outputFile = "ALL_DART_SOURCE_CODE.txt"
$projectPath = "d:\flutter project\prostock\lib"

# Header
@"
========================================
PROSTOCK - COMPLETE DART SOURCE CODE
Generated: $(Get-Date)
========================================

"@ | Out-File -FilePath $outputFile -Encoding UTF8

# Get all .dart files in lib directory
$dartFiles = Get-ChildItem -Path $projectPath -Filter *.dart -Recurse

Write-Host "Found $($dartFiles.Count) Dart files in lib directory"
Write-Host "Creating consolidated source code file..."

foreach ($file in $dartFiles) {
    $relativePath = $file.FullName.Replace("d:\flutter project\prostock\", "")
    
    # Add file header
    @"

╔════════════════════════════════════════════════════════════════
║ FILE: $relativePath
║ SIZE: $([math]::Round($file.Length/1KB, 2)) KB
║ MODIFIED: $($file.LastWriteTime)
╚════════════════════════════════════════════════════════════════

"@ | Out-File -FilePath $outputFile -Append -Encoding UTF8
    
    # Add file content
    Get-Content $file.FullName -Encoding UTF8 | Out-File -FilePath $outputFile -Append -Encoding UTF8
    
    # Add separator
    "`n`n" | Out-File -FilePath $outputFile -Append -Encoding UTF8
}

Write-Host "✓ Complete! Output saved to: $outputFile"
Write-Host "✓ Total files processed: $($dartFiles.Count)"
Write-Host "`nNow you can:"
Write-Host "1. Open $outputFile in VS Code"
Write-Host "2. Press Ctrl+Shift+P"
Write-Host "3. Type 'Print' and select 'Print: Print'"
Write-Host "4. Choose 'Save as PDF'"
