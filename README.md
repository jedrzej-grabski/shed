# shed 🐍

Ephemeral Python workspaces powered by [uv](https://github.com/astral-sh/uv).

Spin up a disposable Python environment in seconds - with the version and packages you need - then **shed** it away when you're done.

```bash
shed -v=3.12 numpy matplotlib
```

That's it. You're in a temp directory with a fresh venv, packages installed.

## Install

### Homebrew (macOS / Linux)

```bash
brew tap youruser/shed
brew install shed
shed
```

### Manual

```bash
git clone https://github.com/youruser/shed.git
cd shed
sudo make install
shed
```

## Prerequisites

- [uv](https://github.com/astral-sh/uv) — `curl -LsSf https://astral.sh/uv/install.sh | sh`

## Usage

```bash
shed                              # quick workspace, default python
shed numpy requests               # default python + packages
shed -v=3.12                      # use python 3.12
shed -v=3.12 numpy matplotlib     # python 3.12 + packages
shed --help                       # show help
```

### Manage your sheds

```bash
shed-ls                           # list active sheds
shed-clean                        # remove all shed directories
```

### Typical workflow

```bash
shed -v=3.12 pandas; code .       # open in VS Code
shed numpy; jupyter notebook      # quick notebook
shed flask; python app.py         # prototype a server
```

## Configuration

| Variable | Default | Description |
|---|---|---|∑
| `SHED_DIR_PREFIX` | `/tmp/shed` | Base path for shed directories |

## How it works

`shed` is a shell function so it can `cd` and `activate` in your current shell.

Since everything lives in `/tmp`, your OS cleans it up on reboot — or use `shed-clean` to do it manually.

## License

MIT
