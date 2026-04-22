#!/usr/bin/env bash
SHED_DIR_PREFIX="${SHED_DIR_PREFIX:-/tmp/shed}"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${1:-}" == "--init" ]]; then
    cat "${BASH_SOURCE[0]}"
    exit 0
fi

shed() {
    case "${1:-}" in
        --init)    _shed_init ;;
        -h|--help) _shed_help ;;
        ls|list)   shift; _shed_ls "$@" ;;
        switch)    shift; _shed_switch "$@" ;;
        leave)     shift; _shed_leave "$@" ;;
        clean)     shift; _shed_clean "$@" ;;
        new)       shift; _shed_new "$@" ;;
        *)         _shed_new "$@" ;;
    esac
}

_shed_init() {
    local self
    self="$(command -v shed 2>/dev/null || echo "/usr/local/lib/shed/shed.sh")"
    if head -1 "$self" 2>/dev/null | grep -q "bootstrap"; then
        self="${self%/bin/shed}/lib/shed/shed.sh"
    fi
    cat "$self"
}

_shed_new() {
    if ! command -v uv &>/dev/null; then
        echo "❌ uv is required but not installed."
        echo "   Install it: curl -LsSf https://astral.sh/uv/install.sh | sh"
        return 1
    fi

    local pyversion=""
    local deps=()

    for arg in "$@"; do
        case "$arg" in
            -v=*|--version=*) pyversion="${arg#*=}" ;;
            -h|--help) _shed_help; return 0 ;;
            -*) echo "❌ Unknown option: $arg"; _shed_help; return 1 ;;
            *) deps+=("$arg") ;;
        esac
    done

    local dir
    dir=$(mktemp -d "${SHED_DIR_PREFIX}-XXXXXX") || { echo "❌ Failed to create temp dir"; return 1; }
    echo "🐍 Shed created: $dir"
    _shed_remember_prev
    cd "$dir" || return 1

    local venv_args=(-q .venv)
    if [[ -n "$pyversion" ]]; then
        venv_args+=(--python "$pyversion")
    fi

    uv venv "${venv_args[@]}" || { echo "❌ Failed to create venv"; rm -rf "$dir"; return 1; }
    source .venv/bin/activate
    echo "🐍 $(python3 --version) ready"

    if [[ ${#deps[@]} -gt 0 ]]; then
        echo "📦 Installing ${deps[*]}..."
        uv pip install -q "${deps[@]}" || { echo "❌ Failed to install deps"; return 1; }
        echo "✅ Installed ${deps[*]}"
    fi
}

_shed_clean() {
    local count
    count=$(find -L /tmp -maxdepth 1 -name "shed-*" -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -eq 0 ]]; then
        echo "🧹 No sheds to clean up"
        return 0
    fi
    rm -rf /tmp/shed-*
    echo "🧹 Swept away $count shed(s)"
}

_shed_ls() {
    local sheds
    sheds=$(find -L /tmp -maxdepth 1 -name "shed-*" -type d 2>/dev/null | sort)
    if [[ -z "$sheds" ]]; then
        echo "No active sheds"
        return 0
    fi
    {
        printf '#\tPYTHON\tCREATED\tSIZE\tPACKAGES\n'
        local i=1
        while IFS= read -r d; do
            local pyver="-" created="-" pkgs="(empty)" size="-" pkglist="" count=0
            size=$(du -sh "$d" 2>/dev/null | cut -f1 | tr -d ' ')
            if [[ -x "$d/.venv/bin/python" ]]; then
                pyver=$("$d/.venv/bin/python" --version 2>&1 | awk '{print $2}')
            fi
            if stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$d" &>/dev/null; then
                created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$d")
            else
                created=$(stat -c "%y" "$d" 2>/dev/null | cut -d'.' -f1)
            fi
            if [[ -d "$d/.venv" ]]; then
                pkglist=$(VIRTUAL_ENV="$d/.venv" uv pip list --format=freeze 2>/dev/null | cut -d= -f1)
                count=$(printf '%s\n' "$pkglist" | grep -c .)
                if [[ "$count" -gt 5 ]]; then
                    pkgs="$(printf '%s\n' "$pkglist" | head -5 | paste -sd ' ' -) ..."
                elif [[ "$count" -gt 0 ]]; then
                    pkgs=$(printf '%s\n' "$pkglist" | paste -sd ' ' -)
                fi
            fi
            printf '%d\t%s\t%s\t%s\t%s\n' "$i" "$pyver" "$created" "$size" "$pkgs"
            i=$((i+1))
        done <<< "$sheds"
    } | column -t -s $'\t'
}

_shed_switch() {
    local num="${1:-}"
    if [[ -z "$num" || ! "$num" =~ ^[0-9]+$ ]]; then
        echo "Usage: shed switch <number>"
        return 1
    fi
    local sheds target
    sheds=$(find -L /tmp -maxdepth 1 -name "shed-*" -type d 2>/dev/null | sort)
    target=$(printf '%s\n' "$sheds" | sed -n "${num}p")
    if [[ -z "$target" ]]; then
        echo "❌ No shed #$num (use 'shed ls')"
        return 1
    fi
    _shed_remember_prev
    cd "$target" || return 1
    # shellcheck disable=SC1091
    source .venv/bin/activate
    echo "🐍 Switched to shed #$num: $target"
}

_shed_remember_prev() {
    # Only capture pwd if we're not already inside a shed, so repeated
    # switches still return to the original dir.
    case "$PWD" in
        "${SHED_DIR_PREFIX}"-*) return 0 ;;
    esac
    SHED_PREV_DIR="$PWD"
}

_shed_leave() {
    case "$PWD" in
        "${SHED_DIR_PREFIX}"-*) ;;
        *) echo "Not currently in a shed"; return 1 ;;
    esac
    if declare -F deactivate &>/dev/null; then
        deactivate
    fi
    local dest="${SHED_PREV_DIR:-$HOME}"
    cd "$dest" || return 1
    echo "🐍 Left shed, back in $dest"
}

_shed_help() {
    cat <<'HELP'
shed - Ephemeral Python workspaces powered by uv 🐍

Usage:
  shed [options] [packages...]      Create a new shed (same as 'shed new')
  shed <command> [args...]

Commands:
  new [options] [packages...]       Create a new shed
  ls, list                          List active sheds
  switch <n>                        Switch to shed #n from 'shed ls'
  leave                             Return to pre-shed dir, deactivate venv
  clean                             Remove all shed directories

Options (for new):
  -v=VERSION, --version=VERSION     Python version (e.g. 3.12, 3.11)
  -h, --help                        Show this help
  --init                            Print shell init script (for eval)

Examples:
  shed                              # quick workspace, default python
  shed numpy requests               # install packages on creation
  shed -v=3.12 flask                # use python 3.12 + flask
  shed ls                           # list active sheds
  shed switch 2                     # jump into shed #2
  shed clean                        # sweep them all away
HELP
}
