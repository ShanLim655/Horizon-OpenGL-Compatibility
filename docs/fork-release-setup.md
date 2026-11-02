# Fork release setup

This fork publishes its own launcher and game releases. The launcher reads releases from `ShanLim655/Horizon-OpenGL-Compatibility`; the upstream `horizon-rust/horizon` repository is used only for upstream game resources and source material.

## One-time signing key setup

The launcher verifies every new game and launcher archive with an Ed25519 key compiled into it. A fork must use its own private key: the upstream private key is not available to this repository.

Run this from the repository root on a trusted computer with Rust and GitHub CLI installed and authenticated:

```powershell
cargo run --locked -p horizon-release-sign -- keygen --public-out crates/horizon-release-sign/release-keys.txt | gh secret set RELEASE_SIGNING_KEY --repo ShanLim655/Horizon-OpenGL-Compatibility
```

The command writes the public key to `crates/horizon-release-sign/release-keys.txt` and pipes the private key directly to GitHub as the repository Actions secret. It refuses to print the private key to an interactive terminal.

Commit and push the updated public key:

```powershell
git add crates/horizon-release-sign/release-keys.txt
git commit -m "chore(release): trust fork signing key"
git push
```

Do not publish game or launcher releases before this commit and secret exist. The public key compiled into the launcher must match the private key used by the release workflows.

## Publish the patched game client

After the signing key is configured and the public-key commit is pushed:

1. Open **Actions** in this repository.
2. Select the **game** workflow.
3. Choose **Run workflow** on `fix/opengl-40-shader-portability`.
4. Keep the upstream input as `nightly`, then run it.
5. Wait for all platform builds and the signed `nightly` release to finish.

The workflow builds this fork's `horizon-client`, replaces the client binary inside the upstream Horizon platform bundles, signs the resulting archives, and publishes them as this fork's Nightly release.

## Build and install the launcher

The **renderer** pull-request workflow builds a Windows installer after renderer tests and Clippy pass. The **launcher** workflow also builds the launcher and Windows installer. Download the `Horizon-OpenGL-Compatibility-Setup` or `Horizon-Offline-Launcher-Setup.exe` artifact from the successful run.

The installed launcher checks this fork for its game and launcher releases. The first game installation is available after the fork's signed Nightly has been published.
