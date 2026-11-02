$ErrorActionPreference = "Stop"
$repo = "ShanLim655/Horizon-OpenGL-Compatibility"
$publicKey = "crates/horizon-release-sign/release-keys.txt"
if (-not (Test-Path $publicKey)) { throw "Run this from the repository root." }
gh auth status
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI is not authenticated." }
cargo run --locked -p horizon-release-sign -- keygen --public-out $publicKey | gh secret set RELEASE_SIGNING_KEY --repo $repo
if ($LASTEXITCODE -ne 0) { throw "Could not save the signing secret to GitHub." }
Write-Host "Signing key created. Commit and push $publicKey before publishing releases."
