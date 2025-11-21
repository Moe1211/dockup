#!/bin/bash
# Helper script to record DockUp test using different tools
# Usage: ./scripts/record-test.sh [tool] [output-file]

set -e

TOOL="${1:-vhs}"
OUTPUT="${2:-test.gif}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎬 DockUp Test Recording${NC}"
echo ""

case "$TOOL" in
    vhs)
        if ! command -v vhs &> /dev/null; then
            echo -e "${YELLOW}⚠️  VHS not found. Install with:${NC}"
            echo "   brew install vhs"
            echo "   or"
            echo "   go install github.com/charmbracelet/vhs@latest"
            exit 1
        fi
        echo -e "${GREEN}📹 Recording with VHS...${NC}"
        echo -e "${YELLOW}Note: Edit scripts/test.tape to customize the test${NC}"
        vhs scripts/test.tape
        if [ -f "test.gif" ]; then
            mv test.gif "$OUTPUT"
            echo -e "${GREEN}✅ Test saved to: $OUTPUT${NC}"
        fi
        ;;
    
    asciinema)
        if ! command -v asciinema &> /dev/null; then
            echo -e "${YELLOW}⚠️  asciinema not found. Install with:${NC}"
            echo "   brew install asciinema"
            echo "   or"
            echo "   sudo apt install asciinema"
            exit 1
        fi
        CAST_FILE="${OUTPUT%.gif}.cast"
        echo -e "${GREEN}📹 Recording with asciinema...${NC}"
        echo -e "${YELLOW}Press Ctrl+D when done recording${NC}"
        asciinema rec "$CAST_FILE"
        
        if command -v agg &> /dev/null; then
            echo -e "${GREEN}🔄 Converting to GIF...${NC}"
            agg "$CAST_FILE" "$OUTPUT"
            echo -e "${GREEN}✅ Test saved to: $OUTPUT${NC}"
        else
            echo -e "${YELLOW}⚠️  agg not found. Install to convert to GIF:${NC}"
            echo "   cargo install --git https://github.com/asciinema/agg"
            echo "   or"
            echo "   brew install agg"
            echo ""
            echo "Cast file saved to: $CAST_FILE"
        fi
        ;;
    
    ttyrec)
        if ! command -v ttyrec &> /dev/null; then
            echo -e "${YELLOW}⚠️  ttyrec not found. Install with:${NC}"
            echo "   brew install ttyrec ttygif"
            echo "   or"
            echo "   sudo apt install ttyrec ttygif"
            exit 1
        fi
        TTY_FILE="${OUTPUT%.gif}.tty"
        echo -e "${GREEN}📹 Recording with ttyrec...${NC}"
        echo -e "${YELLOW}Press Ctrl+D when done recording${NC}"
        ttyrec "$TTY_FILE"
        
        if command -v ttygif &> /dev/null; then
            echo -e "${GREEN}🔄 Converting to GIF...${NC}"
            ttygif "$TTY_FILE"
            if [ -f "${TTY_FILE%.tty}.gif" ]; then
                mv "${TTY_FILE%.tty}.gif" "$OUTPUT"
                echo -e "${GREEN}✅ Test saved to: $OUTPUT${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  ttygif not found${NC}"
            echo "TTY file saved to: $TTY_FILE"
        fi
        ;;
    
    *)
        echo "Usage: $0 [vhs|asciinema|ttyrec] [output-file.gif]"
        echo ""
        echo "Tools:"
        echo "  vhs       - Scripted recording (recommended)"
        echo "  asciinema - Manual recording with high quality"
        echo "  ttyrec    - Simple terminal recording"
        exit 1
        ;;
esac

