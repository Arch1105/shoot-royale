# Generates spoken voice-line WAV assets for Shoot Royale using the built-in
# Windows speech synthesizer (System.Speech). No internet or extra install needed.
# Run once (or whenever lines change): powershell -File tools/generate_voice.ps1

Add-Type -AssemblyName System.Speech

$outDir = Join-Path $PSScriptRoot "..\audio\voice"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Rate = 1
$synth.Volume = 100

$lines = @{
    "match_start"        = "Fight! Bats are up."
    "you_died"            = "You were eliminated."
    "you_respawned"       = "You respawned."
    "eliminated_bot_1"    = "You eliminated Bot 1."
    "eliminated_bot_2"    = "You eliminated Bot 2."
    "eliminated_bot_3"    = "You eliminated Bot 3."
    "eliminated_bot_4"    = "You eliminated Bot 4."
    "eliminated_generic"  = "You eliminated an opponent."
    "score_prefix"        = "Score check."
    "elim_singular"       = "elimination,"
    "elim_plural"         = "eliminations,"
    "death_singular"      = "death."
    "death_plural"        = "deaths."
    "zone_incline"        = "Incline. Climbing up."
    "zone_summit"         = "You're at the top."
    "zone_decline"        = "Decline. Heading down."
    "zone_flat"           = "Flat ground."
    "fall_damage"         = "You fell and were eliminated."
    "shootout_start"      = "Match started. Six minutes. Most eliminations wins."
    "locked_on"           = "Locked on."
    "match_created"       = "Match created. Your code is"
    "connected"           = "Connected."
    "no_match_found"      = "No match found with that code."
    "searching_for_match" = "Searching for match."
    "match_time_low"      = "One minute remaining."
    "match_over"          = "Match over."
    "you_win"             = "You win!"
    "opponent_wins"       = "Opponent wins."
    "match_tie"           = "It's a tie."
    "reload_start"        = "Reloading."
}

for ($i = 0; $i -le 20; $i++) {
    $lines["num_$i"] = "$i"
}

foreach ($key in $lines.Keys) {
    $path = Join-Path $outDir "$key.wav"
    $synth.SetOutputToWaveFile($path)
    $synth.Speak($lines[$key])
    $synth.SetOutputToDefaultAudioDevice()
    Write-Host "wrote $path"
}

$synth.Dispose()
Write-Host "Done."
