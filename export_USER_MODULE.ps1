# PowerShell Script to Export USER MODULE Source Code
# This consolidates all User-related Dart files for PDF export

$outputFile = "USER_MODULE_SOURCE_CODE.txt"
$projectPath = "d:\flutter project\prostock"

# Define User Module files and directories
$userPaths = @(
    "lib\screens\user\*.dart",
    "lib\screens\user\dashboard\*.dart",
    "lib\screens\user\stock\*.dart",
    "lib\screens\user\profile\*.dart",
    "lib\screens\pos\*.dart",
    "lib\screens\inventory\*.dart",
    "lib\screens\customers\*.dart",
    "lib\screens\report_tabs\*.dart",
    "lib\services\firestore\stock_service.dart",
    "lib\services\firestore\product_service.dart",
    "lib\services\firestore\customer_service.dart",
    "lib\services\firestore\sales_service.dart",
    "lib\services\firestore\purchase_service.dart",
    "lib\services\report_service.dart",
    "lib\services\pdf_report_service.dart",
    "lib\services\printing_service.dart",
    "lib\models\product.dart",
    "lib\models\stock.dart",
    "lib\models\customer.dart",
    "lib\models\sale.dart",
    "lib\models\purchase.dart"
)

# Header
@"
========================================
PROSTOCK - USER MODULE SOURCE CODE
Generated: $(Get-Date)
========================================

MODULE DESCRIPTION:
This module contains all user/staff functionality including:
- User Dashboard
- Stock Management (View, Add, Update)
- Point of Sale (POS)
- Inventory Management
- Customer Management
- Sales & Purchase Records
- Report Generation
- Receipt Printing
- Product Search & Filtering

========================================

"@ | Out-File -FilePath $outputFile -Encoding UTF8

$fileCount = 0

foreach ($pattern in $userPaths) {
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
Total User Module Files: $fileCount
Export Date: $(Get-Date)
Project: ProStock Inventory Management
Module: USER
========================================

"@ | Out-File -FilePath $outputFile -Append -Encoding UTF8

Write-Host "[SUCCESS] USER MODULE Export Complete!" -ForegroundColor Green
Write-Host "[INFO] Output saved to: $outputFile" -ForegroundColor Cyan
Write-Host "[INFO] Total files processed: $fileCount" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open $outputFile in VS Code"
Write-Host "2. Press Ctrl+Shift+P"
Write-Host "3. Type Print and select Print: Print"
Write-Host "4. Choose Save as PDF or Microsoft Print to PDF"
Write-Host "5. Save as ProStock User Module.pdf"
