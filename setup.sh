#!/bin/bash
# Guided first connection. Only macOS built-ins are needed.
set -euo pipefail
umask 077
project_dir=$(cd "$(dirname "$0")" && pwd)
config_dir=${WINLINK_HOME:-"$HOME/.config/winlink"}
bin_dir=${WINLINK_BIN_DIR:-"$HOME/.local/bin"}
ssh_config=${WINLINK_SSH_CONFIG:-"$HOME/.ssh/config"}
known_hosts=${WINLINK_KNOWN_HOSTS:-"$HOME/.ssh/known_hosts"}
temporary=''
trap '[ -z "$temporary" ] || rm -f "$temporary"' EXIT
fail() { printf 'Setup: %s\n' "$*" >&2; exit 2; }
usage() {
    cat <<'EOF'
Mac first-connection setup:
  bash setup.sh prepare [--name office] [--client-address MAC_IP] [--out FILE]
  bash setup.sh connect FILE.winlink.json

1. prepare installs winlink and exports this Mac's PUBLIC pairing data.
2. Copy the file to Windows; double-click Setup-Windows.cmd there.
3. Copy the updated file back; connect verifies the host key and login.
Pairing files contain device information; keep them private.
EOF
}
read_json() { /usr/bin/plutil -extract "$2" raw -o - -- "$1" 2>/dev/null; }
validate_name() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || fail 'Invalid target name.'; }
validate_address() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'A single IPv4 address is required.'
    printf '%s\n' "$1" | awk -F. '{for(i=1;i<=4;i++) if(length($i)>3 || $i+0>255) exit 1}' || fail 'Invalid IPv4 address.'
    case "$1" in 0.*|127.*|255.*) fail 'Use a reachable unicast IPv4 address.' ;; esac
}
key_fingerprint() { ssh-keygen -lf "$1" | awk '{print $2}'; }
install_client() {
    /bin/bash "$project_dir/install-mac.sh"
    mkdir -p "$config_dir"
    chmod 700 "$config_dir"
}
command=${1:-help}
[ "$#" -eq 0 ] || shift
case "$command" in
    help|--help|-h) usage ;;
    prepare)
        name=office; address=''; output=''
        while [ "$#" -gt 0 ]; do
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            case "$1" in
                --name) name=$2 ;; --client-address) address=$2 ;; --out) output=$2 ;;
                *) fail "Unknown option: $1" ;;
            esac
            shift 2
        done
        validate_name "$name"
        if [ -z "$address" ]; then
            interface=$(/sbin/route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
            address=$(/usr/sbin/ipconfig getifaddr "${interface:-en0}" 2>/dev/null || true)
            [ -n "$address" ] || fail 'Cannot detect Mac IPv4; pass --client-address.'
            if [ -t 0 ]; then
                read -r -p "Mac address allowed by Windows [$address]: " chosen
                address=${chosen:-$address}
            fi
        fi
        validate_address "$address"
        install_client
        if [ ! -f "$config_dir/id_ed25519" ]; then "$bin_dir/winlink" keygen; fi
        [ -f "$config_dir/id_ed25519.pub" ] || fail 'Public key missing. Restore its matching .pub file before continuing.'
        output=${output:-"$PWD/$name.winlink.json"}
        [ ! -e "$output" ] || fail 'Pairing file already exists. Use another --out path to preserve it.'
        temporary=$(mktemp "$config_dir/.pairing.XXXXXX")
        /usr/bin/plutil -create xml1 "$temporary"
        /usr/bin/plutil -insert schemaVersion -integer 1 "$temporary"
        /usr/bin/plutil -insert kind -string winlink-request "$temporary"
        /usr/bin/plutil -insert name -string "$name" "$temporary"
        /usr/bin/plutil -insert clientAddress -string "$address" "$temporary"
        /usr/bin/plutil -insert publicKey -string "$(cat "$config_dir/id_ed25519.pub")" "$temporary"
        /usr/bin/plutil -insert clientKeyFingerprint -string "$(key_fingerprint "$config_dir/id_ed25519.pub")" "$temporary"
        /usr/bin/plutil -convert json -o "$output" "$temporary"
        chmod 600 "$output"
        printf 'Pairing file: %s\nCopy it to Windows, run Setup-Windows.cmd, then copy the updated file back.\n' "$output"
        ;;
    connect)
        [ "$#" -eq 1 ] || fail 'Usage: bash setup.sh connect FILE.winlink.json'
        profile=$1
        [ -f "$profile" ] || fail 'Connection file not found.'
        [ "$(read_json "$profile" schemaVersion)" = 1 ] || fail 'Unsupported pairing schema.'
        [ "$(read_json "$profile" kind)" = winlink-connection ] || fail 'Run Windows setup on this pairing file first.'
        name=$(read_json "$profile" name); validate_name "$name"
        host=$(read_json "$profile" hostAddress); validate_address "$host"
        user=$(read_json "$profile" user)
        [[ "$user" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || fail 'Invalid local Windows user.'
        port=$(read_json "$profile" port)
        [[ "$port" =~ ^[0-9]{1,5}$ ]] || fail 'Invalid port.'
        port=$((10#$port))
        [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || fail 'Invalid port.'
        [ -f "$config_dir/id_ed25519.pub" ] || fail 'Run prepare on this Mac first.'
        [ "$(key_fingerprint "$config_dir/id_ed25519.pub")" = "$(read_json "$profile" clientKeyFingerprint)" ] || fail 'This pairing file belongs to a different Mac key.'
        expected=$(read_json "$profile" hostFingerprint)
        [[ "$expected" =~ ^SHA256:[a-zA-Z0-9+/]{43}$ ]] || fail 'Invalid Windows host fingerprint.'
        temporary=$(mktemp "${TMPDIR:-/tmp}/winlink-host.XXXXXX")
        ssh-keyscan -T 5 -t ed25519 -p "$port" "$host" > "$temporary" 2>/dev/null || fail 'SSH port unreachable. Check the setup log, Mac IP, network and firewall.'
        actual=$(key_fingerprint "$temporary")
        [ "$actual" = "$expected" ] || fail 'Windows host fingerprint mismatch. No trust or target configuration was added.'
        token=$host
        [ "$port" -eq 22 ] || token="[$host]:$port"
        if [ -f "$known_hosts" ]; then
            prior=$(ssh-keygen -F "$token" -f "$known_hosts" 2>/dev/null || true)
            if printf '%s\n' "$prior" | /usr/bin/grep -Eq '^[[:space:]]*@'; then
                fail 'Marked known_hosts entries require manual review; no existing key was changed.'
            fi
            # OpenSSH may already have learned RSA/ECDSA keys for the same host.
            # Compare like for like; preserve every unrelated algorithm entry.
            prior=$(printf '%s\n' "$prior" | awk '$2 == "ssh-ed25519"')
            if [ -n "$prior" ]; then
                found=$(printf '%s\n' "$prior" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
                [ "$found" = "$expected" ] || fail 'Existing known_hosts entry conflicts. Review it manually; no existing key was removed.'
            fi
        else
            prior=''
        fi
        install_client
        mkdir -p "$(dirname "$known_hosts")"
        if [ -z "$prior" ]; then
            # Leading newline also preserves files without a trailing newline.
            printf '\n%s\n' "$(cat "$temporary")" >> "$known_hosts"
            chmod 600 "$known_hosts"
        fi
        "$bin_dir/winlink" add "$name" --host "$host" --user "$user" --port "$port"
        printf 'Host fingerprint verified. Checking public-key login to %s...\n' "$name"
        set +e
        ssh -F "$ssh_config" -o "UserKnownHostsFile=$known_hosts" \
            -o StrictHostKeyChecking=yes -o PreferredAuthentications=publickey \
            -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
            "winlink-$name" whoami
        status=$?
        set -e
        if [ "$status" -ne 0 ]; then
            printf 'Login check for %s failed (exit %s). Target and verified fingerprint are saved.\n' "$name" "$status" >&2
            printf 'Check the Windows setup log and unlock your local SSH key if needed.\n' >&2
            exit "$status"
        fi
        printf 'Connected: %s\nNext: winlink doctor %s\n' "$name" "$name"
        ;;
    *) usage >&2; fail "Unknown command: $command" ;;
esac
