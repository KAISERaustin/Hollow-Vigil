[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskDocs = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs'
$taskHtml = (ConvertFrom-Markdown -LiteralPath (Join-Path $taskDocs 'UI_STYLE_GUIDE.md')).Html
$taskShell = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hollow Vigil UI Standard · Pickard / Moonlit iron</title>
<style>
:root { --ink: #000; --text: #e8ddbd; --panel: #2b3533; --inset: #222a29; --outline: 3px; }
* { box-sizing: border-box; }
body { margin: 0; background: #141b1a; color: var(--text); font: 16px/1.6 "Segoe UI", sans-serif; }
main { max-width: 1040px; margin: 24px auto; padding: 32px; background: var(--panel); border: var(--outline) solid var(--ink); border-radius: 4px; }
h1 { font-size: 32px; line-height: 1.2; } h2 { margin-top: 32px; font-size: 24px; } h3 { margin-top: 24px; font-size: 18px; }
p, li { max-width: 88ch; } li + li { margin-top: 8px; }
a { color: var(--text); text-underline-offset: 3px; }
img { display: block; width: 100%; max-width: 479px; height: auto; margin: 16px auto; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
th, td { padding: 8px 12px; text-align: left; vertical-align: top; border: var(--outline) solid var(--ink); }
th { background: var(--inset); } code { overflow-wrap: anywhere; font-size: .9em; }
@media (max-width: 640px) { main { margin: 12px; padding: 12px; } table { display: block; overflow-x: auto; } h1 { font-size: 26px; } }
</style>
</head>
<body><main>
'@
$taskPage = $taskShell + "`n" + $taskHtml + "`n</main></body></html>`n"
[IO.File]::WriteAllText((Join-Path $taskDocs 'UI_STYLE_GUIDE.html'), $taskPage)
Write-Output 'Regenerated docs/UI_STYLE_GUIDE.html from UI_STYLE_GUIDE.md.'
