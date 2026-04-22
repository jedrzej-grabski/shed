#!/usr/bin/env bash
SHED_DIR_PREFIX="${SHED_DIR_PREFIX:-/tmp/shed}"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${1:-}" == "--init" ]]; then
    cat "${BASH_SOURCE[0]}"
    exit 0
fi

shed() {
    if [[ "${1:-}" == "--init" ]]; then
        local self
        self="$(command -v shed 2>/dev/null || echo "/usr/local/lib/shed/shed.sh")"
        if head -1 "$self" 2>/dev/null | grep -q "bootstrap"; then
            self="${self%/bin/shed}/lib/shed/shed.sh"
        fi
        cat "$self"
        return 0
    fi

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

shed-clean() {
    local count
    count=$(find /tmp -maxdepth 1 -name "shed-*" -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -eq 0 ]]; then
        echo "🧹 No sheds to clean up"
        return 0
    fi
    rm -rf /tmp/shed-*
    echo "🧹 Swept away $count shed(s)"
}

shed-ls() {
    local sheds
    sheds=$(find /tmp -maxdepth 1 -name "shed-*" -type d 2>/dev/null)
    if [[ -z "$sheds" ]]; then
        echo "No active sheds"
        return 0
    fi
    echo "Active sheds:"
    while IFS= read -r d; do
        local size
        size=$(du -sh "$d" 2>/dev/null | cut -f1)
        echo "  $d ($size)"
    done <<< "$sheds"
}

_shed_help() {
    cat <<'HELP'
shed - Ephemeral Python workspaces powered by uv 🐍

Usage:
  shed [options] [packages...]

Options:
  -v=VERSION, --version=VERSION   Python version (e.g. 3.12, 3.11)
  -h, --help                      Show this help
  --init                          Print shell init script (for eval)

Commands:
  shed-clean                      Remove all shed directories
  shed-ls                         List active sheds

Examples:
  shed                            # quick workspace, default python
  shed numpy requests             # install packages on creation
  shed -v=3.12 flask              # use python 3.12 + flask
  shed -v=3.12 numpy matplotlib; code .
HELP
}
