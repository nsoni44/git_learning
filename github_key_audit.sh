#!/usr/bin/env bash
# github_key_audit.sh
# Interactive GitHub SSH/GPG key auditor and manager for WSL / Ubuntu.
#
# Usage: ./github_key_audit.sh
# Notes: Requires `gh`, `jq`, `ssh-keygen`. Uses gh interactive login if needed.

set -eo pipefail
IFS=$'\n\t'

# Config
OLD_DAYS_THRESHOLD=365

# Helpers
err() { echo "ERROR: $*" >&2; }
info() { echo -e "\n[INFO] $*"; }
prompt_confirm() {
  # $1 = message
  read -r -p "$1 [y/N]: " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

check_deps() {
  local miss=()
  for cmd in gh jq ssh-keygen date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      miss+=("$cmd")
    fi
  done
  if [ "${#miss[@]}" -gt 0 ]; then
    err "Missing dependencies: ${miss[*]}"
    echo "Install them on Ubuntu with: sudo apt update && sudo apt install -y gh jq openssh-client gnupg"
    exit 1
  fi
}

ensure_logged_in() {
  if gh auth status >/dev/null 2>&1; then
    info "You are logged in to GitHub CLI."
  else
    info "You are not logged in. Launching 'gh auth login'..."
    echo "Follow the interactive prompts (choose GitHub.com, HTTPS or SSH, login with browser or device)."
    gh auth login || { err "gh auth login failed or was cancelled."; exit 2; }
    info "Login finished. Re-checking status..."
    gh auth status || { err "Still not authenticated."; exit 2; }
  fi
}

# --- SSH Keys ---
fetch_ssh_keys_json() {
  gh api user/keys --paginate
}

list_ssh_keys_pretty() {
  local json
  json="$(fetch_ssh_keys_json)"
  if [ -z "$json" ] || [ "$json" = "[]" ]; then
    echo "No SSH keys found on your account."
    return
  fi

  echo "ID | Title | Created At | Type | Bits | Age (days) | Notes"
  echo "---------------------------------------------------------------------"
  local idx=0
  local now_s=$(date +%s)
  echo "$json" | jq -r '.[] | @base64' | while read -r line; do
    idx=$((idx+1))
    _jq() { echo "${line}" | base64 --decode | jq -r "${1}"; }
    id="$(_jq '.id')"
    title="$(_jq '.title')"
    created_at="$(_jq '.created_at')"
    key="$(_jq '.key')"

    # write key to temp file to inspect
    tmpfile="$(mktemp)"
    echo "$key" > "$tmpfile"
    # ssh-keygen -lf needs a file with a public key
    # Some systems require a trailing newline/prefix; it's okay.
    echo "" >> "$tmpfile"

    # Get bits and fingerprint from ssh-keygen
    # ssh-keygen -lf reads comments too; parse first token as bits if available
    local info
    if info="$(ssh-keygen -lf "$tmpfile" 2>/dev/null)"; then
      bits="$(echo "$info" | awk '{print $1}')"
      # type detection: public key string starts with type
      type="$(echo "$key" | awk '{print $1}')"
    else
      bits="?"
      type="$(echo "$key" | awk '{print $1}')"
    fi
    rm -f "$tmpfile"

    # age
    created_s=$(date -d "$created_at" +%s 2>/dev/null || echo 0)
    if [ "$created_s" -eq 0 ]; then
      age_days="?"
    else
      age_days=$(( (now_s - created_s) / 86400 ))
    fi

    notes=()
    if [ "$age_days" != "?" ] && [ "$age_days" -ge "$OLD_DAYS_THRESHOLD" ]; then
      notes+=("old>${OLD_DAYS_THRESHOLD}d")
    fi
    # Suggest if insecure (rsa small)
    if echo "$type" | grep -qi "ssh-rsa"; then
      if [ "$bits" != "?" ] && [ "$bits" -lt 4096 ]; then
        notes+=("rsa<4096")
      else
        notes+=("rsa")
      fi
    elif echo "$type" | grep -qi -e "ssh-ed25519" -e "ecdsa"; then
      notes+=("$type")
    else
      notes+=("unknown-type")
    fi

    printf "%s | %s | %s | %s | %s | %s | %s\n" "$id" "$title" "$created_at" "$type" "$bits" "$age_days" "$(IFS=,; echo "${notes[*]}")"
  done
}

find_old_ssh_keys() {
  local json created_s now_s age_days id title created_at key
  json="$(fetch_ssh_keys_json)"
  now_s=$(date +%s)
  echo "$json" | jq -r '.[] | @base64' | while read -r line; do
    _jq() { echo "${line}" | base64 --decode | jq -r "${1}"; }
    id="$(_jq '.id')"
    title="$(_jq '.title')"
    created_at="$(_jq '.created_at')"
    created_s=$(date -d "$created_at" +%s 2>/dev/null || echo 0)
    if [ "$created_s" -eq 0 ]; then
      continue
    fi
    age_days=$(( (now_s - created_s) / 86400 ))
    if [ "$age_days" -ge "$OLD_DAYS_THRESHOLD" ]; then
      printf "%s | %s | %s days\n" "$id" "$title" "$age_days"
    fi
  done
}

delete_ssh_key_by_id() {
  local id="$1"
  if prompt_confirm "Delete SSH key id=$id ?"; then
    gh ssh-key delete "$id" && echo "Deleted key $id." || err "Failed to delete $id"
  else
    echo "Skipped deletion of $id."
  fi
}

add_new_ssh_key_flow() {
  read -r -p "Enter a name for the key file (e.g. id_ed25519_work): " keyname
  keyname="${keyname:-id_ed25519_github}"
  keypath="$HOME/.ssh/$keyname"
  if [ -f "$keypath" ] || [ -f "${keypath}.pub" ]; then
    if ! prompt_confirm "Key $keypath exists. Overwrite?"; then
      echo "Aborting key generation."
      return
    fi
  fi
  # generate ed25519
  echo "Generating ED25519 key at $keypath ..."
  ssh-keygen -t ed25519 -C "$(git config user.email || echo 'no-email')" -f "$keypath"
  # add to GitHub
  if prompt_confirm "Add $keypath.pub to GitHub with title '$keyname' ?"; then
    gh ssh-key add "${keypath}.pub" --title "$keyname" && echo "Uploaded ${keypath}.pub" || err "Failed to upload key"
  else
    echo "Not uploading. Key kept locally at $keypath (private) and ${keypath}.pub (public)."
  fi
}

rotate_ssh_key_flow() {
  echo "Rotation flow: generate new key, upload, optionally delete an old key."
  add_new_ssh_key_flow
  echo "Now list keys so you can choose old one to delete if desired."
  list_ssh_keys_pretty
  read -r -p "Enter SSH key ID to delete (or press Enter to skip): " delid
  if [ -n "$delid" ]; then
    delete_ssh_key_by_id "$delid"
  fi
}

# --- GPG keys ---
list_gpg_keys_pretty() {
  local json
  json="$(gh api user/gpg_keys)"
  if [ -z "$json" ] || [ "$json" = "[]" ]; then
    echo "No GPG keys found."
    return
  fi
  echo "ID | Key ID | Created At | Public Key (truncated)"
  echo "--------------------------------------------------"
  echo "$json" | jq -r '.[] | "\(.id) | \(.key_id) | \(.created_at) | \(.public_key[0:60])..."'
}

delete_gpg_key_by_id() {
  local id="$1"
  if prompt_confirm "Delete GPG key id=$id ?"; then
    gh api -X DELETE "user/gpg_keys/$id" && echo "Deleted GPG key $id." || err "Failed to delete GPG key $id"
  else
    echo "Skipped deletion of GPG key $id."
  fi
}

# --- Menu / UI ---
main_menu() {
  while true; do
    cat <<'MENU'

GitHub SSH/GPG Key Auditor - Menu
1) Show SSH keys (detailed)
2) Find SSH keys older than threshold (365 days)
3) Rotate (generate + upload) a new SSH key
4) Add a new SSH key (generate & upload)
5) Delete an SSH key by ID
6) Show GPG keys
7) Delete a GPG key by ID
8) Run quick health check (flags)
9) Re-run gh auth login
0) Exit
MENU
    read -r -p "Choose an option: " opt
    case "$opt" in
      1) list_ssh_keys_pretty ;;
      2) find_old_ssh_keys ;;
      3) rotate_ssh_key_flow ;;
      4) add_new_ssh_key_flow ;;
      5) read -r -p "Enter SSH key ID to delete: " id && delete_ssh_key_by_id "$id" ;;
      6) list_gpg_keys_pretty ;;
      7) read -r -p "Enter GPG key ID to delete: " gid && delete_gpg_key_by_id "$gid" ;;
      8) quick_health_check ;;
      9) gh auth login || echo "gh auth login finished or was cancelled." ;;
      0) info "Exiting."; break ;;
      *) echo "Invalid option." ;;
    esac
    echo
  done
}

quick_health_check() {
  info "Quick health check:"
  echo "- Auth status:"
  gh auth status || echo "(not logged in)"
  echo
  echo "- SSH keys summary (id | title | created_at | type | bits | age_days | notes):"
  list_ssh_keys_pretty
  echo
  echo "- Old keys (>${OLD_DAYS_THRESHOLD} days):"
  find_old_ssh_keys || echo "No old keys."
  echo
  echo "- GPG keys:"
  list_gpg_keys_pretty
  echo
  echo "Recommendations:"
  echo " * Rotate keys older than ${OLD_DAYS_THRESHOLD} days."
  echo " * Prefer ssh-ed25519 or RSA >= 4096 bits."
  echo " * Remove unused keys and old device entries (both locally and on GitHub)."
}

# Entry point
main() {
  check_deps
  ensure_logged_in
  info "Starting interactive auditor. Threshold for 'old' keys is ${OLD_DAYS_THRESHOLD} days."
  main_menu
}

main "$@"
