# PowerShell Script to Export ADMIN MODULE Source Code
# This consolidates all Admin-related Dart files for PDF export

$outputFile = "ADMIN_MODULE_SOURCE_CODE.txt"
$projectPath = "d:\flutter project\prostock"

# Define Admin Module files and directories
$adminPaths = @(
    "lib\screens\admin\*.dart",
    "lib\screens\admin\components\*.dart",
    "lib\screens\settings\*.dart",
    "lib\screens\settings\components\*.dart",
    "lib\services\firestore\user_service.dart",
    "lib\services\firestore\activity_service.dart",
    "lib\services\firestore\backup_service.dart",
    "lib\providers\auth_provider.dart",
    "lib\models\user.dart",
    "lib\models\activity_log.dart"
)

# Header
@"
========================================
PROSTOCK - ADMIN MODULE SOURCE CODE
Generated: $(Get-Date)
========================================

MODULE DESCRIPTION:
This module contains all administrator functionality including:
- Admin Dashboard & Screen
- User Management
- Activity Monitoring & Logs
- System Settings
- Backup & Restore
- Security & Authentication
- Role-based Access Control

========================================

"@ | Out-File -FilePath $outputFile -Encoding UTF8

$fileCount = 0

foreach ($pattern in $adminPaths) {
    $fullPath = Join-Path $projectPath $pattern
    $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue
    
    foreach ($file in $files) {
        if ($file.PSIsContainer) { continue }
        
        $fileCount++
        $relativePath = $file.FullName.Replace("$projectPath\", "")
        
        # Add file header
        $fileHeader = @"

================================================================
FILE #$fileCount`: $relativePath
SIZE: $([math]::Round($file.Length/1KB, 2)) KB
MODIFIED: $($file.LastWriteTime)
================================================================

"@
        $fileHeader | Out-File -FilePath $outputFile -Append -Encoding UTF8
        
        # Add file content
        Get-Content $file.FullName -Encoding UTF8 | Out-File -FilePath $outputFile -Append -Encoding UTF8
        
        # Add separator
        "`n`n" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    }
}

# Footer
@"

========================================
EXPORT SUMMARY
========================================
Total Admin Module Files: $fileCount
Export Date: $(Get-Date)
Project: ProStock Inventory Management
Module: ADMIN
========================================

"@ | Out-File -FilePath $outputFile -Append -Encoding UTF8

Write-Host "[SUCCESS] ADMIN MODULE Export Complete!" -ForegroundColor Green
Write-Host "[INFO] Output saved to: $outputFile" -ForegroundColor Cyan
Write-Host "[INFO] Total files processed: $fileCount" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open $outputFile in VS Code"
Write-Host "2. Press Ctrl+Shift+P"
Write-Host "3. Type Print and select Print: Print"
Write-Host "4. Choose Save as PDF or Microsoft Print to PDF"
Write-Host "5. Save as ProStock Admin Module.pdf"
