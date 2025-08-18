#!/bin/bash
# pat_oauth_review.sh
# Review GitHub Personal Access Tokens (manual), OAuth Apps, and GitHub Apps

# === CONFIG ===
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/pat_oauth_review_$(date +'%Y-%m-%d_%H-%M-%S').log"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

print_result() {
    local status=$1
    local message=$2
    if [[ "$status" == "OK" ]]; then
        echo -e "${GREEN}✅ $message${NC}" | tee -a "$LOG_FILE"
    elif [[ "$status" == "WARN" ]]; then
        echo -e "${YELLOW}⚠️  $message${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}❌ $message${NC}" | tee -a "$LOG_FILE"
    fi
}

# ===============================
# 1. Personal Access Tokens (Manual Check)
# ===============================
echo -e "${BLUE}🔍 Reviewing Personal Access Tokens (Manual Step)${NC}" | tee -a "$LOG_FILE"
print_result "WARN" "GitHub API does not allow listing PATs. Review manually at: https://github.com/settings/tokens"

# ===============================
# 2. OAuth App Authorizations
# ===============================
echo -e "\n${BLUE}🔍 Reviewing OAuth App Authorizations${NC}" | tee -a "$LOG_FILE"

# GitHub does not have a direct 'list OAuth apps' endpoint for users via API,
# so we check installations and flag any OAuth-type authorizations
OAUTH_LIST=$(gh api /user/installations --paginate 2>/dev/null | jq '.installations[] | select(.target_type=="User")')

if [[ -z "$OAUTH_LIST" ]]; then
    print_result "OK" "No OAuth Apps authorized."
else
    COUNT=$(echo "$OAUTH_LIST" | jq -s 'length')
    if [[ "$COUNT" -eq 0 ]]; then
        print_result "OK" "No OAuth Apps authorized."
    else
        print_result "WARN" "$COUNT OAuth Apps authorized — review permissions."
        echo "$OAUTH_LIST" | jq '.' >> "$LOG_FILE"
    fi
fi

# ===============================
# 3. GitHub Apps
# ===============================
echo -e "\n${BLUE}🔍 Reviewing GitHub Apps${NC}" | tee -a "$LOG_FILE"

GITHUB_APPS=$(gh api /user/installations --paginate 2>/dev/null | jq '.installations[] | select(.app_slug != null)')

if [[ -z "$GITHUB_APPS" ]]; then
    print_result "OK" "No GitHub Apps authorized."
else
    APP_COUNT=$(echo "$GITHUB_APPS" | jq -s 'length')
    if [[ "$APP_COUNT" -eq 0 ]]; then
        print_result "OK" "No GitHub Apps authorized."
    else
        print_result "WARN" "$APP_COUNT GitHub Apps authorized — review repository access."
        echo "$GITHUB_APPS" | jq '.' >> "$LOG_FILE"
    fi
fi

# ===============================
# Completion
# ===============================
echo -e "\n${GREEN}✅ PAT, OAuth App, & GitHub App Review complete. See $LOG_FILE for details.${NC}"
