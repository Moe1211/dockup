# Quick Start: Create DockUp Demo GIF

## Fastest Method (VHS - Recommended)

1. **Install VHS:**
   ```bash
   brew install vhs  # macOS
   # or
   go install github.com/charmbracelet/vhs@latest
   ```

2. **Edit the demo script:**
   ```bash
   # Edit scripts/demo.tape to match your setup
   # Update VPS IP, commands, etc.
   ```

3. **Record:**
   ```bash
   ./scripts/record-demo.sh vhs demo.gif
   # or directly:
   vhs scripts/demo.tape
   ```

4. **Optimize (optional):**
   ```bash
   gifsicle -O3 --colors 256 demo.gif -o demo-optimized.gif
   ```

## Manual Recording (asciinema)

If you prefer to type commands manually:

1. **Install tools:**
   ```bash
   brew install asciinema agg
   ```

2. **Record:**
   ```bash
   ./scripts/record-demo.sh asciinema demo.gif
   # Type your commands, press Ctrl+D when done
   ```

3. **The script will automatically convert to GIF**

## Demo Workflow to Record

1. **Global Install** (~30s)
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash
   dockup version
   ```

2. **VPS Setup** (~60s)
   ```bash
   dockup setup user@vps-ip
   ```

3. **GitHub App Config** (~30s)
   ```bash
   dockup configure-github-app user@vps-ip
   # Enter: App ID, Installation ID, Private Key
   ```

4. **Deploy App** (~60s)
   ```bash
   cd my-app
   dockup deploy user@vps-ip
   ```

5. **Auto-Deploy on Push** (~30s)
   ```bash
   git push origin main
   ssh user@vps-ip 'journalctl -u dockup -n 10 -f'
   ```

**Total: ~3-4 minutes**

## Tips

- Use a clean terminal theme (dark background)
- Set terminal size: 1200x700 or 80x24
- Test all commands beforehand
- Have VPS and GitHub App ready
- Keep demo under 4 minutes

## Troubleshooting

**VHS not found:**
```bash
# Install via Homebrew (macOS)
brew install vhs

# Or via Go
go install github.com/charmbracelet/vhs@latest
```

**GIF too large:**
```bash
# Optimize with gifsicle
brew install gifsicle
gifsicle -O3 --colors 256 demo.gif -o demo-optimized.gif
```

**Need to edit timing:**
- VHS: Edit `scripts/demo.tape` and re-record
- asciinema: Use `agg` with speed options: `agg --speed 2 demo.cast demo.gif`

