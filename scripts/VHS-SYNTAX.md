# VHS Syntax Quick Reference

## Basic Commands

### Configuration
```tape
Output demo.gif              # Output filename
Set FontSize 14              # Font size
Set Width 1200               # Terminal width
Set Height 700               # Terminal height
Set Theme "Catppuccin Mocha" # Color theme (see: vhs themes)
Set TypingSpeed 50ms         # Typing speed
```

### Typing and Input
```tape
Type "text"                  # Type text
Enter                        # Press Enter
Ctrl+C                       # Press Ctrl+C
Ctrl+L                       # Clear screen (alternative to clear command)
Tab                          # Press Tab
Space                        # Press Space
Backspace                    # Press Backspace
```

### Control Flow
```tape
Sleep 2s                     # Wait 2 seconds
Sleep 500ms                  # Wait 500 milliseconds
```

### Shell Commands
```tape
Type "clear"                 # Clear terminal (via shell command)
Enter
Type "echo 'Hello'"          # Execute echo command
Enter
```

## Common Patterns

### Show a Title
```tape
Type "echo '🚀 Title'"
Enter
Sleep 2s
```

### Clear Screen
```tape
Type "clear"
Enter
Sleep 0.5s
```

### Run a Command
```tape
Type "dockup version"
Enter
Sleep 1s
```

### Multi-line Commands
```tape
Type "docker compose up -d"
Enter
Sleep 3s
```

## Themes

List available themes:
```bash
vhs themes
```

Popular themes:
- `Catppuccin Mocha`
- `Dracula`
- `Nord`
- `One Dark`
- `Tokyo Night`

## Tips

1. **Always add `Enter` after `Type`** - VHS needs explicit Enter key presses
2. **Use `Sleep` between commands** - Gives time to see output
3. **Use `clear` command** - Not `Clear` (case-sensitive)
4. **Test with `vhs validate`** - Check syntax before recording
5. **Adjust `TypingSpeed`** - Faster for demos, slower for tutorials

## Example

```tape
Output demo.gif
Set FontSize 14
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

Type "echo 'Hello World'"
Enter
Sleep 1s
Type "clear"
Enter
Sleep 0.5s
```

