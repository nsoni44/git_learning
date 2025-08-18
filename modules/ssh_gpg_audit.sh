#!/bin/bash
# ssh_gpg_audit.sh
# Review GitHub SSH & GPG keys

# === CONFIG ===
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ssh_gpg_audit_$(date +'%Y-%m-%d_%H-%M-%S').log"

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

echo -e "${BLUE}🔍 Reviewing SSH Keys${NC}" | tee -a "$LOG_FILE"
SSH_KEYS=$(gh api user/keys 2>/dev/null)

if [[ -z "$SSH_KEYS" ]]; then
    print_result "OK" "No SSH keys found for this GitHub account."
else
    COUNT=$(echo "$SSH_KEYS" | jq '. | length')
    print_result "OK" "$COUNT SSH keys found."
    echo "$SSH_KEYS" | jq '.' >> "$LOG_FILE"

    # Check for old keys (>1 year)
    for i in $(seq 0 $(($COUNT - 1))); do
        key_date=$(echo "$SSH_KEYS" | jq -r ".[$i].created_at")
        key_title=$(echo "$SSH_KEYS" | jq -r ".[$i].title")
        key_epoch=$(date -d "$key_date" +%s)
        one_year_ago=$(date -d "1 year ago" +%s)
        if [[ "$key_epoch" -lt "$one_year_ago" ]]; then
            print_result "WARN" "SSH key '$key_title' is older than 1 year."
        fi
    done
fi

echo -e "\n${BLUE}🔍 Reviewing GPG Keys${NC}" | tee -a "$LOG_FILE"
GPG_KEYS=$(gh api user/gpg_keys 2>/dev/null)

if [[ -z "$GPG_KEYS" ]]; then
    print_result "OK" "No GPG keys found for this GitHub account."
else
    COUNT=$(echo "$GPG_KEYS" | jq '. | length')
    print_result "OK" "$COUNT GPG keys found."
    echo "$GPG_KEYS" | jq '.' >> "$LOG_FILE"
fi

echo -e "\n${GREEN}✅ SSH & GPG key audit complete. See $LOG_FILE for details.${NC}"
COUNT