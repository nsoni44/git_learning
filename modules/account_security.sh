#!/bin/bash

# ==========================================
# GitHub Account Security Audit - Module 1
# With Auto Scope Refresh
# ==========================================

LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/account_security_$(date +%F).log"

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# ===========================
# Prerequisite Checks
# ===========================
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        log "${RED}[ERROR] GitHub CLI (gh) is not installed. Install it: https://cli.github.com/${NC}"
        exit 1
    fi
}

check_auth_and_scopes() {
    log "${YELLOW}[*] Checking GitHub CLI authentication...${NC}"
    if ! gh auth status -h github.com &>/dev/null; then
        log "${RED}[ERROR] gh CLI is NOT authenticated. Run: gh auth login${NC}"
        exit 1
    fi

    log "${YELLOW}[*] Refreshing authentication with required scopes...${NC}"
    REQUIRED_SCOPES=(read:user user admin:public_key admin:gpg_key)
    SCOPE_ARGS=()
    for scope in "${REQUIRED_SCOPES[@]}"; do
        SCOPE_ARGS+=("-s" "$scope")
    done
    gh auth refresh -h github.com "${SCOPE_ARGS[@]}" || {
        log "${RED}[ERROR] Failed to refresh scopes. Check your authentication.${NC}"
        exit 1
    }
    log "${GREEN}[OK] All required scopes granted.${NC}"
}

# ===========================
# Security Checks
# ===========================
check_2fa() {
    log "${YELLOW}[*] Checking Two-Factor Authentication (2FA) status...${NC}"
    if gh api user --jq '.two_factor_authentication' | grep -q true; then
        log "${GREEN}[OK] 2FA is enabled.${NC}"
    else
        log "${RED}[ALERT] 2FA is NOT enabled! Enable it at: https://github.com/settings/security${NC}"
    fi
}

check_primary_email() {
    log "${YELLOW}[*] Checking primary email verification...${NC}"
    EMAIL_INFO=$(gh api user/emails --jq '.[] | select(.primary == true)')
    PRIMARY_EMAIL=$(echo "$EMAIL_INFO" | jq -r '.email')
    VERIFIED=$(echo "$EMAIL_INFO" | jq -r '.verified')
    
    if [[ "$VERIFIED" == "true" && "$PRIMARY_EMAIL" != "null" ]]; then
        log "${GREEN}[OK] Primary email '$PRIMARY_EMAIL' is verified.${NC}"
    else
        log "${RED}[ALERT] Primary email '$PRIMARY_EMAIL' is NOT verified.${NC}"
    fi
}

check_recovery_codes() {
    log "${YELLOW}[*] Reminder: Ensure recovery codes are securely stored.${NC}"
    log "${YELLOW}    Visit: https://github.com/settings/security${NC}"
}

check_ssh_keys() {
    log "${YELLOW}[*] Listing SSH keys...${NC}"
    SSH_KEYS=$(gh api user/keys --jq '.[] | {id: .id, key: .key, created_at: .created_at}')
    if [[ -z "$SSH_KEYS" ]]; then
        log "${RED}[ALERT] No SSH keys found! Add one: https://github.com/settings/keys${NC}"
    else
        echo "$SSH_KEYS" | tee -a "$LOG_FILE"
        log "${GREEN}[OK] SSH keys are present.${NC}"
    fi
}

check_gpg_keys() {
    log "${YELLOW}[*] Listing GPG keys...${NC}"
    GPG_KEYS=$(gh api user/gpg_keys --jq '.[] | {id: .id, key_id: .key_id, created_at: .created_at}')
    if [[ -z "$GPG_KEYS" ]]; then
        log "${RED}[ALERT] No GPG keys found! Add one: https://github.com/settings/keys${NC}"
    else
        echo "$GPG_KEYS" | tee -a "$LOG_FILE"
        log "${GREEN}[OK] GPG keys are present.${NC}"
    fi
}

# ===========================
# Run Checks
# ===========================
check_gh_cli
check_auth_and_scopes
check_2fa
check_primary_email
check_recovery_codes
check_ssh_keys
check_gpg_keys

log "${GREEN}✔ Account security check complete.${NC}"
