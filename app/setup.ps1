# Run this ONCE inside the "app" folder (PowerShell):  .\setup.ps1
# It generates the Flutter platform folders (android, web, windows), allows
# plain-HTTP to your local backend on Android, and installs packages.

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter is not installed or not in PATH. See README.md, section 'Prerequisites'." -ForegroundColor Red
  exit 1
}

flutter create . --project-name noticebridge --platforms=android,web,windows

$manifest = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
  $text = Get-Content $manifest -Raw
  if ($text -notmatch "usesCleartextTraffic") {
    $text = $text -replace "<application", '<application android:usesCleartextTraffic="true"'
    Set-Content $manifest $text
    Write-Host "Android: enabled HTTP access to local backend." -ForegroundColor Green
  }
}

flutter pub get
Write-Host "`nDone. Start the backend first, then run:  flutter run -d chrome" -ForegroundColor Green
