#!/usr/bin/env bash
# github_key_audit.sh v2.1
# Production-ready GitHub SSH/GPG key auditor and manager for WSL / Ubuntu / macOS.
#
# Improvements in v2.1:
#  - Increased API timeout to 60s (was 30s) for reliability
#  - Better debugging information
#  - Fallback without --paginate for slower networks
#  - More resilient error handling
#
# Usage: ./github_key_audit.sh
# Notes: Requires `gh`, `jq`, `ssh-keygen`. Uses gh interactive login if needed.

set -euo pipefail
IFS=$'\n\t'

# Config
OLD_DAYS_THRESHOLD=365
AUDIT_LOG="${HOME}/.github_audit.log"
API_TIMEOUT=60  # Increased from 30s to 60s for reliability

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Helpers
err() { echo -e "${RED}ERROR: $*${NC}" >&2; }
info() { echo -e "\n${BLUE}[INFO] $*${NC}"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
debug() { 
  if [ "${DEBUG:-0}" = "1" ]; then
    echo -e "${BLUE}[DEBUG] $*${NC}" >&2
  fi
}

prompt_confirm() {
  # $1 = message
  local ans
  read -r -p "$(echo -e ${YELLOW})$1 [y/N]:$(echo -e ${NC}) " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# ============================================================================
# FIX #1: Portable date parsing (GNU/BSD compatible)
# ============================================================================
parse_epoch() {
  local iso_date="$1"
  
  # Try GNU date first (Linux)
  if date -d "$iso_date" +%s 2>/dev/null; then
    return 0
  # Fallback to BSD date (macOS)
  elif date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso_date" "+%s" 2>/dev/null; then
    return 0
  else
    echo 0
    return 1
  fi
}

# ============================================================================
# FIX #2: Secure temp file handling with trap cleanup
# ============================================================================
secure_temp() {
  local tmpfile
  tmpfile="$(mktemp)" || { err "Failed to create temp file"; return 1; }
  chmod 600 "$tmpfile" || { err "Failed to set temp file permissions"; return 1; }
  trap "rm -f '$tmpfile'" EXIT
  echo "$tmpfile"
}

# ============================================================================
# FIX #3: Improved API calls with better timeout and error handling
# ============================================================================
gh_api() {
  local output exit_code
  
  debug "Calling: timeout $API_TIMEOUT gh api $*"
  
  if output=$(timeout "$API_TIMEOUT" gh api "$@" 2>&1); then
    debug "API call successful"
    echo "$output"
    return 0
  else
    exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
      err "GitHub API timed out after ${API_TIMEOUT}s"
      err "Try setting: export DEBUG=1 to see more details"
      err "Or check GitHub status: https://www.githubstatus.com"
    elif [ $exit_code -eq 1 ]; then
      # Parse error from output
      err "GitHub API error: $(echo "$output" | tail -1)"
    else
      err "GitHub API failed (exit code: $exit_code)"
      debug "Full output: $output"
    fi
    return 1
  fi
}

# ============================================================================
# FIX #4: Input validation
# ============================================================================
validate_numeric() {
  local input="$1"
  local name="${2:-ID}"
  
  if ! [[ "$input" =~ ^[0-9]+$ ]]; then
    err "$name must be numeric. Got: $input"
    return 1
  fi
  echo "$input"
}

validate_keyname() {
  local keyname="$1"
  
  if ! [[ "$keyname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    err "Key name must contain only letters, numbers, hyphens, and underscores"
    return 1
  fi
  echo "$keyname"
}

# ============================================================================
# FIX #5: Audit logging
# ============================================================================
audit_log() {
  local action="$1"
  local key_id="$2"
  local details="${3:-}"
  
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $action | ID:$key_id | $details" >> "$AUDIT_LOG"
}

view_audit_log() {
  if [ ! -f "$AUDIT_LOG" ]; then
    warn "No audit log found at $AUDIT_LOG"
    return
  fi
  
  echo
  info "Audit Log ($AUDIT_LOG)"
  echo "---------------------------------------------------------------------"
  tail -20 "$AUDIT_LOG"
  echo "---------------------------------------------------------------------"
  echo "(Showing last 20 entries. Full log: $AUDIT_LOG)"
}

# ============================================================================
# Dependencies
# ============================================================================
check_deps() {
  local miss=()
  for cmd in gh jq ssh-keygen date timeout; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      miss+=("$cmd")
    fi
  done
  if [ "${#miss[@]}" -gt 0 ]; then
    err "Missing dependencies: ${miss[*]}"
    echo "Install them:"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y gh jq openssh-client gnupg coreutils"
    echo "  macOS: brew install gh jq openssh gnupg coreutils"
    exit 1
  fi
}

# ============================================================================
# Authentication
# ============================================================================
ensure_logged_in() {
  if gh auth status >/dev/null 2>&1; then
    success "You are logged in to GitHub CLI."
  else
    info "You are not logged in. Launching 'gh auth login'..."
    echo "Follow the interactive prompts (choose GitHub.com, HTTPS or SSH, login with browser or device)."
    gh auth login || { err "gh auth login failed or was cancelled."; exit 2; }
    info "Login finished. Re-checking status..."
    gh auth status || { err "Still not authenticated."; exit 2; }
  fi
}

# ============================================================================
# SSH Keys Operations
# ============================================================================
fetch_ssh_keys_json() {
  debug "Fetching SSH keys..."
  gh_api user/keys --paginate || {
    # Fallback without --paginate for slower connections
    debug "Retrying without --paginate..."
    gh_api user/keys
  }
}

list_ssh_keys_pretty() {
  local json
  json="$(fetch_ssh_keys_json)" || return 1
  
  if [ -z "$json" ] || [ "$json" = "[]" ]; then
    warn "No SSH keys found on your account."
    return
  fi

  echo
  echo "SSH Keys Summary"
  echo "ID | Title | Created At | Type | Bits | Age (days) | Status"
  echo "---------------------------------------------------------------------"
  
  local now_s
  now_s=$(date +%s)
  
  # Use mapfile to avoid subshell variable loss
  local -a lines=()
  mapfile -t lines < <(echo "$json" | jq -r '.[] | @base64')
  
  debug "Found ${#lines[@]} SSH keys"
  
  for line in "${lines[@]}"; do
    _jq() { echo "${line}" | base64 --decode | jq -r "${1}"; }
    local id title created_at key type bits age_days status notes
    
    id="$(_jq '.id')"
    title="$(_jq '.title')"
    created_at="$(_jq '.created_at')"
    key="$(_jq '.key')"

    # Use secure temp file with trap
    local tmpfile
    tmpfile="$(secure_temp)"
    echo "$key" >> "$tmpfile"
    echo "" >> "$tmpfile"

    # Get bits and type from ssh-keygen
    local info
    if info="$(ssh-keygen -lf "$tmpfile" 2>/dev/null)"; then
      bits="$(echo "$info" | awk '{print $1}')"
      type="$(echo "$key" | awk '{print $1}')"
    else
      bits="?"
      type="$(echo "$key" | awk '{print $1}')"
    fi

    # Calculate age
    local created_s
    created_s=$(parse_epoch "$created_at") || created_s=0
    if [ "$created_s" -eq 0 ]; then
      age_days="?"
      status="❓ UNKNOWN"
    else
      age_days=$(( (now_s - created_s) / 86400 ))
      if [ "$age_days" -ge "$OLD_DAYS_THRESHOLD" ]; then
        status="🔴 OLD (${age_days}d)"
      elif [ "$age_days" -ge 180 ]; then
        status="🟡 AGING (${age_days}d)"
      else
        status="🟢 OK (${age_days}d)"
      fi
    fi

    # Key strength assessment
    local strength=""
    if echo "$type" | grep -qi "ssh-rsa"; then
      if [ "$bits" != "?" ] && [ "$bits" -lt 4096 ]; then
        strength=" [WEAK]"
      else
        strength=" [OK]"
      fi
    elif echo "$type" | grep -qi -e "ssh-ed25519"; then
      strength=" [STRONG]"
    elif echo "$type" | grep -qi "ecdsa"; then
      strength=" [GOOD]"
    fi

    printf "%s | %s | %s | %s | %s | %s | %s%s\n" \
      "$id" "$title" "$created_at" "$type" "$bits" "$age_days" "$status" "$strength"
  done
}

find_old_ssh_keys() {
  local json now_s
  json="$(fetch_ssh_keys_json)" || return 1
  now_s=$(date +%s)
  
  echo
  echo "Old SSH Keys (>${OLD_DAYS_THRESHOLD} days)"
  echo "ID | Title | Age (days) | Created At"
  echo "---------------------------------------------------------------------"
  
  local count=0
  local -a lines=()
  mapfile -t lines < <(echo "$json" | jq -r '.[] | @base64')
  
  debug "Checking ${#lines[@]} keys for age > $OLD_DAYS_THRESHOLD days"
  
  for line in "${lines[@]}"; do
    _jq() { echo "${line}" | base64 --decode | jq -r "${1}"; }
    local id title created_at created_s age_days
    
    id="$(_jq '.id')"
    title="$(_jq '.title')"
    created_at="$(_jq '.created_at')"
    created_s=$(parse_epoch "$created_at") || continue
    
    if [ "$created_s" -eq 0 ]; then
      continue
    fi
    
    age_days=$(( (now_s - created_s) / 86400 ))
    if [ "$age_days" -ge "$OLD_DAYS_THRESHOLD" ]; then
      printf "%s | %s | %s | %s\n" "$id" "$title" "$age_days" "$created_at"
      ((count++))
    fi
  done
  
  if [ "$count" -eq 0 ]; then
    warn "No keys older than ${OLD_DAYS_THRESHOLD} days found. Good job!"
  else
    warn "Found $count old key(s). Consider rotating them."
  fi
}

delete_ssh_key_by_id() {
  local id
  id=$(validate_numeric "$1" "Key ID") || return 1
  
  if prompt_confirm "Delete SSH key id=$id?"; then
    if gh ssh-key delete "$id" 2>/dev/null; then
      success "Deleted key $id."
      audit_log "DELETE_SSH_KEY" "$id" "Manual deletion"
    else
      err "Failed to delete key $id"
      return 1
    fi
  else
    echo "Skipped deletion of $id."
  fi
}

# ============================================================================
# FIX #6: Batch operations
# ============================================================================
delete_all_old_keys_batch() {
  local json now_s count=0 threshold
  threshold="${OLD_DAYS_THRESHOLD}"
  
  json="$(fetch_ssh_keys_json)" || return 1
  now_s=$(date +%s)
  
  echo
  warn "This will delete all SSH keys older than ${threshold} days."
  
  if ! prompt_confirm "Continue?"; then
    echo "Aborted."
    return
  fi
  
  local -a lines=()
  mapfile -t lines < <(echo "$json" | jq -r '.[] | @base64')
  
  for line in "${lines[@]}"; do
    _jq() { echo "${line}" | base64 --decode | jq -r "${1}"; }
    local id title created_at created_s age_days
    
    id="$(_jq '.id')"
    title="$(_jq '.title')"
    created_at="$(_jq '.created_at')"
    created_s=$(parse_epoch "$created_at") || continue
    
    if [ "$created_s" -eq 0 ]; then
      continue
    fi
    
    age_days=$(( (now_s - created_s) / 86400 ))
    if [ "$age_days" -ge "$threshold" ]; then
      if prompt_confirm "Delete '$title' (${age_days} days old)?"; then
        if gh ssh-key delete "$id" 2>/dev/null; then
          success "Deleted $id: $title"
          audit_log "DELETE_SSH_KEY_BATCH" "$id" "Age: ${age_days}d, Title: $title"
          ((count++))
        else
          err "Failed to delete $id"
        fi
      fi
    fi
  done
  
  success "Batch delete complete. Deleted $count key(s)."
}

add_new_ssh_key_flow() {
  echo
  info "Generate and upload a new SSH key"
  
  local keyname keypath
  read -r -p "Enter a name for the key (e.g., id_ed25519_work): " keyname
  keyname="${keyname:-id_ed25519_github}"
  keyname=$(validate_keyname "$keyname") || return 1
  
  keypath="$HOME/.ssh/$keyname"
  
  if [ -f "$keypath" ] || [ -f "${keypath}.pub" ]; then
    warn "Key $keypath already exists."
    if ! prompt_confirm "Overwrite?"; then
      echo "Aborted."
      return
    fi
  fi
  
  # Generate ed25519 key
  info "Generating ED25519 key at $keypath..."
  ssh-keygen -t ed25519 -C "$(git config user.email 2>/dev/null || echo 'no-email')" -f "$keypath" -N "" || {
    err "Failed to generate key"
    return 1
  }
  
  success "Key generated at $keypath"
  
  # Add to GitHub
  if prompt_confirm "Add $keypath.pub to GitHub with title '$keyname'?"; then
    if gh ssh-key add "${keypath}.pub" --title "$keyname" 2>/dev/null; then
      success "Uploaded ${keypath}.pub to GitHub"
      audit_log "ADD_SSH_KEY" "N/A" "Title: $keyname"
    else
      err "Failed to upload key"
      return 1
    fi
  else
    echo "Key kept locally at $keypath (private) and ${keypath}.pub (public)."
  fi
}

rotate_ssh_key_flow() {
  echo
  info "SSH Key Rotation Flow"
  echo "This will generate a new key, upload it, and optionally delete an old one."
  
  add_new_ssh_key_flow || return 1
  
  echo
  list_ssh_keys_pretty || return 1
  
  local delid
  read -r -p "Enter SSH key ID to delete (or press Enter to skip): " delid
  if [ -n "$delid" ]; then
    delete_ssh_key_by_id "$delid" || true
  fi
  
  success "Key rotation complete!"
}

# ============================================================================
# GPG Keys Operations
# ============================================================================
list_gpg_keys_pretty() {
  local json
  json="$(gh_api user/gpg_keys)" || return 1
  
  if [ -z "$json" ] || [ "$json" = "[]" ]; then
    warn "No GPG keys found."
    return
  fi
  
  echo
  echo "GPG Keys"
  echo "ID | Key ID | Created At | Public Key (truncated)"
  echo "---------------------------------------------------------------------"
  echo "$json" | jq -r '.[] | "\(.id) | \(.key_id) | \(.created_at) | \(.public_key[0:40])..."'
}

delete_gpg_key_by_id() {
  local id
  id=$(validate_numeric "$1" "GPG Key ID") || return 1
  
  if prompt_confirm "Delete GPG key id=$id?"; then
    if gh api -X DELETE "user/gpg_keys/$id" 2>/dev/null; then
      success "Deleted GPG key $id."
      audit_log "DELETE_GPG_KEY" "$id" "Manual deletion"
    else
      err "Failed to delete GPG key $id"
      return 1
    fi
  else
    echo "Skipped deletion of GPG key $id."
  fi
}

# ============================================================================
# FIX #7: Export reports (JSON/CSV)
# ============================================================================
export_audit_report() {
  local format="${1:-json}"
  local json
  
  json="$(fetch_ssh_keys_json)" || return 1
  
  case "$format" in
    json)
      echo "$json" | jq .
      ;;
    csv)
      echo "ID,Title,Created,Type,Bits"
      echo "$json" | jq -r '.[] | [.id, .title, .created_at, (.key | split(" ")[0]), ""] | @csv'
      ;;
    *)
      err "Unknown format: $format (use 'json' or 'csv')"
      return 1
      ;;
  esac
}

# ============================================================================
# Health Check & Recommendations
# ============================================================================
quick_health_check() {
  echo
  info "🏥 GitHub Security Health Check"
  echo "==========================================="
  
  echo
  echo "Auth Status:"
  gh auth status || echo "(not logged in)"
  
  echo
  echo "SSH Keys Summary:"
  list_ssh_keys_pretty || true
  
  echo
  echo "Old Keys (>${OLD_DAYS_THRESHOLD} days):"
  find_old_ssh_keys || true
  
  echo
  echo "GPG Keys:"
  list_gpg_keys_pretty || true
  
  echo
  info "Recommendations:"
  echo " ✓ Rotate keys older than ${OLD_DAYS_THRESHOLD} days."
  echo " ✓ Prefer ssh-ed25519 (strongest) over RSA >= 4096 bits."
  echo " ✓ Remove unused keys and old device entries."
  echo " ✓ Use separate keys for separate devices/projects (better isolation)."
  echo " ✓ Store private keys securely (~/.ssh with 600 permissions)."
  echo " ✓ Consider hardware security keys for critical accounts."
  echo
  echo "✅ Health check complete!"
}

# ============================================================================
# Menu / UI
# ============================================================================
main_menu() {
  while true; do
    echo
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    GitHub SSH/GPG Key Auditor - Menu                      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "SSH Key Management:"
    echo "  1) Show SSH keys (detailed)"
    echo "  2) Find SSH keys older than ${OLD_DAYS_THRESHOLD} days"
    echo "  3) Rotate (generate + upload) a new SSH key"
    echo "  4) Add a new SSH key (generate & upload)"
    echo "  5) Delete an SSH key by ID"
    echo "  6) Batch delete old SSH keys"
    echo
    echo "GPG Key Management:"
    echo "  7) Show GPG keys"
    echo "  8) Delete a GPG key by ID"
    echo
    echo "Audit & Reports:"
    echo "  9) Run quick health check"
    echo "  10) View audit log"
    echo "  11) Export SSH keys (JSON)"
    echo "  12) Export SSH keys (CSV)"
    echo
    echo "Account:"
    echo "  13) Re-run gh auth login"
    echo "  0) Exit"
    echo
    
    read -r -p "Choose an option: " opt
    
    case "$opt" in
      1) list_ssh_keys_pretty ;;
      2) find_old_ssh_keys ;;
      3) rotate_ssh_key_flow ;;
      4) add_new_ssh_key_flow ;;
      5)
        local id
        read -r -p "Enter SSH key ID to delete: " id
        delete_ssh_key_by_id "$id" || true
        ;;
      6) delete_all_old_keys_batch ;;
      7) list_gpg_keys_pretty ;;
      8)
        local gid
        read -r -p "Enter GPG key ID to delete: " gid
        delete_gpg_key_by_id "$gid" || true
        ;;
      9) quick_health_check ;;
      10) view_audit_log ;;
      11) echo; export_audit_report "json" ;;
      12) echo; export_audit_report "csv" ;;
      13) gh auth login || echo "gh auth login finished or was cancelled." ;;
      0)
        info "Exiting. Remember to rotate old keys regularly!"
        break
        ;;
      *)
        err "Invalid option '$opt'. Please try again."
        ;;
    esac
    
    read -r -p "$(echo -e ${YELLOW})Press Enter to continue...${NC}" _
  done
}

# ============================================================================
# Entry point
# ============================================================================
main() {
  check_deps
  ensure_logged_in
  info "Starting GitHub Key Auditor v2.1. Threshold for 'old' keys is ${OLD_DAYS_THRESHOLD} days."
  info "Audit log: $AUDIT_LOG"
  echo "Tip: Set DEBUG=1 for detailed troubleshooting: DEBUG=1 ./github_key_audit.sh"
  main_menu
}

main "$@"
