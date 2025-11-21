# Creating a DockUp Demo GIF

This guide explains how to create a demo GIF showing the DockUp workflow: global install, VPS setup, and repo deployment.

## Recommended Tools

### Option 1: VHS (Terminal GIF Recorder) - Recommended
**Best for:** Automated, scripted recordings with perfect timing

```bash
# Install VHS
brew install vhs  # macOS
# or
go install github.com/charmbracelet/vhs@latest

# VHS uses .tape files to script terminal sessions
# See scripts/demo.tape for example
```

**Pros:**
- Scriptable (no manual typing)
- Consistent results
- Built-in GIF export
- Supports typing simulation
- Great for demos

**Cons:**
- Requires learning .tape syntax
- Less "natural" than real typing

### Option 2: asciinema + agg
**Best for:** High-quality recordings with manual control

```bash
# Install asciinema
brew install asciinema  # macOS
sudo apt install asciinema  # Linux

# Install agg (asciicast to gif converter)
cargo install --git https://github.com/asciinema/agg
# or
brew install agg  # macOS

# Record
asciinema rec demo.cast

# Convert to GIF
agg demo.cast demo.gif
```

**Pros:**
- Natural typing
- High quality
- Can edit timing
- Supports playback speed

**Cons:**
- Manual recording (need to type commands)
- May require multiple takes

### Option 3: ttyrec + ttygif
**Best for:** Simple, lightweight option

```bash
# Install
brew install ttyrec ttygif  # macOS
sudo apt install ttyrec ttygif  # Linux

# Record
ttyrec demo.tty

# Convert to GIF
ttygif demo.tty
```

### Option 4: Screen Recording + Conversion
**Best for:** Full control, any OS

1. Use screen recording tool (QuickTime on macOS, OBS, etc.)
2. Record terminal window
3. Convert video to GIF using:
   - `ffmpeg -i demo.mov -vf "fps=10,scale=800:-1:flags=lanczos" demo.gif`
   - Online tools (ezgif.com, etc.)

## Demo Script Workflow

The demo should show:

1. **Global Install** (30-60 seconds)
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash
   dockup version
   ```

2. **VPS Setup** (60-90 seconds)
   ```bash
   dockup setup user@vps-ip
   # Show Docker installation, agent build, systemd setup
   ```

3. **GitHub App Configuration** (30-45 seconds)
   ```bash
   dockup configure-github-app user@vps-ip
   # Interactive prompts (can be scripted with expect)
   ```

4. **Repository Deployment** (30-60 seconds)
   ```bash
   cd my-app
   dockup deploy user@vps-ip
   # Show cloning, building, deploying
   ```

5. **Auto-Deploy on Push** (20-30 seconds)
   ```bash
   git push origin main
   # Show webhook trigger, rebuild, restart
   ```

## Tips for Best Results

1. **Terminal Setup:**
   - Use a clean terminal theme (dark background, good contrast)
   - Set terminal size: 80x24 or 120x30
   - Use a monospace font (Fira Code, JetBrains Mono, etc.)
   - Increase font size for readability

2. **Timing:**
   - Add small delays between commands (1-2 seconds)
   - Speed up long-running commands in post-processing
   - Keep total demo under 3-4 minutes

3. **Visual Polish:**
   - Add a title slide at the start
   - Use consistent colors
   - Highlight important output
   - Add captions if needed

4. **Preparation:**
   - Have a test VPS ready
   - Pre-configure GitHub App (or script the prompts)
   - Use a test repository
   - Test all commands beforehand

## Example VHS Script

See `scripts/demo.tape` for a complete VHS script example.

## Post-Processing

After recording, you may want to:
- Optimize GIF size: `gifsicle -O3 --colors 256 demo.gif -o demo-optimized.gif`
- Add captions: Use tools like `ffmpeg` or online editors
- Trim timing: Use `gifsicle` or video editing tools
- Resize: `convert demo.gif -resize 800x600 demo-resized.gif` (ImageMagick)

