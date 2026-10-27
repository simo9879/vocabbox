#requires -Version 5.1
<#
  Launches the Vocab Box Windows prototype with the speech API keys set for this
  process only. Nothing is written to your user or machine environment, and no
  key is printed. Close the window and the keys are gone.

  If PowerShell refuses to run the file, start it like this instead:
      powershell -ExecutionPolicy Bypass -File .\run-with-speech.ps1

  Expected layout: this script, vocab-box.exe and vocab-box.pck in one folder.
#>

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paste the keys between the quotes. Leave a value as-is to use a key that is
# already set in this PowerShell session instead.
# ---------------------------------------------------------------------------
$ElevenLabsApiKey = 'REPLACE_WITH_ELEVENLABS_KEY'
$DeepSeekApiKey   = 'REPLACE_WITH_DEEPSEEK_KEY'
# ---------------------------------------------------------------------------

$folder = $PSScriptRoot
$exe = Join-Path $folder 'vocab-box.exe'
$pck = Join-Path $folder 'vocab-box.pck'
$log = Join-Path $folder 'vocab-speech.log'

foreach ($required in @($exe, $pck)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing $required. Keep vocab-box.exe and vocab-box.pck in the same folder as this script."
    }
}

function Get-Key([string] $value, [string] $name, [string] $label) {
    $trimmed = $value.Trim()
    if ($trimmed.Length -gt 0 -and -not $trimmed.StartsWith('REPLACE_WITH_')) {
        return $trimmed
    }
    $fromSession = [Environment]::GetEnvironmentVariable($name, 'Process')
    if (-not [string]::IsNullOrWhiteSpace($fromSession)) {
        return $fromSession.Trim()
    }
    throw "$label is not set. Edit this script and replace the placeholder, or set $name in this terminal first."
}

$ElevenLabsApiKey = Get-Key $ElevenLabsApiKey 'ELEVENLABS_API_KEY' 'ElevenLabs API key'
$DeepSeekApiKey = Get-Key $DeepSeekApiKey 'AI_API_KEY' 'DeepSeek API key'

# Process scope only: the game reads these with OS.get_environment().
$env:ELEVENLABS_API_KEY = $ElevenLabsApiKey
$env:AI_API_KEY = $DeepSeekApiKey

Write-Host 'Speech keys are set for this run only.'
Write-Host "  ElevenLabs : $($ElevenLabsApiKey.Length) characters"
Write-Host "  DeepSeek   : $($DeepSeekApiKey.Length) characters"
Write-Host "  Log        : $log"
Write-Host ''
Write-Host 'In game, an encounter should now show the speaking prompt instead of answer buttons.'
Write-Host 'If it still shows answer buttons, the fallback is reported in the log below.'
Write-Host ''

Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue

& $exe --verbose --log-file $log
$code = $LASTEXITCODE

Write-Host ''
Write-Host "Game exited with code $code."
if (Test-Path -LiteralPath $log) {
    Write-Host ''
    Write-Host 'Last log lines:'
    Get-Content -LiteralPath $log -Tail 30
}

if ($code -ne 0) {
    exit $code
}
