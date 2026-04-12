# setup-script

macOS setup scripts for a fresh machine or a rebuild.

## Files

- `setup-macos.sh`: main setup script using Oh My Zsh and Powerlevel10k
- `setup-macos-starship.sh`: alternate setup script using Starship
- `starship-powerlevel10k.toml`: Starship prompt config styled to match the Powerlevel10k setup

## Run

Make the script executable if needed:

```bash
chmod +x setup-macos.sh
```

Run the main setup:

```bash
./setup-macos.sh
```

Skip Mac App Store installs:

```bash
./setup-macos.sh --skip-app-store
```

Preview commands without making changes:

```bash
DRY_RUN=1 ./setup-macos.sh --skip-app-store
```

## Notes

- The script installs apps with Homebrew and `mas`
- Language runtimes are managed with `mise`
- Install failures are reported, but the full run continues
- Use `setup-macos-starship.sh` if you want Starship instead of Powerlevel10k
