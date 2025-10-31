#!/bin/bash
#
# Setup Cloud Shell for Backfill
# Run this once to prepare Cloud Shell environment
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Cloud Shell Setup for Q1 2020 Backfill${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Step 1: Check if repo exists
if [ -d "$HOME/chicago-bi-app" ]; then
    echo -e "${YELLOW}ℹ️  Repository already exists, pulling latest...${NC}"
    cd $HOME/chicago-bi-app
    git pull
else
    echo -e "${YELLOW}ℹ️  Cloning repository...${NC}"
    cd $HOME

    # Option 1: If you have a GitHub repo
    # git clone https://github.com/YOUR_USERNAME/chicago-bi-app.git

    # Option 2: If no GitHub repo, upload the backfill script manually
    echo -e "${YELLOW}ℹ️  No git repo configured.${NC}"
    echo ""
    echo "Please upload the backfill script manually:"
    echo "1. Click the 3-dot menu in Cloud Shell"
    echo "2. Select 'Upload'"
    echo "3. Upload: ~/Desktop/chicago-bi-app/backfill/quarterly_backfill_q1_2020.sh"
    echo ""
    echo "Or copy-paste the script content when ready."
    exit 0
fi

# Step 2: Make script executable
cd $HOME/chicago-bi-app/backfill
chmod +x quarterly_backfill_q1_2020.sh

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Start tmux session:"
echo "     tmux new -s backfill"
echo ""
echo "  2. Run backfill:"
echo "     cd ~/chicago-bi-app/backfill"
echo "     ./quarterly_backfill_q1_2020.sh all"
echo ""
echo "  3. Detach from tmux:"
echo "     Press: Ctrl+B, then D"
echo ""
echo "  4. Reattach later:"
echo "     tmux attach -t backfill"
echo ""
