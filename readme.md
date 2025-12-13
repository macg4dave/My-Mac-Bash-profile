# My Mac Bash Profile

A simple, clean Bash setup that gives you a few genuinely useful commands — without breaking anything, installing junk, or getting in your way.

Think of it like a small toolbox that quietly makes your terminal nicer on **macOS and Linux**, especially if you move between machines.

---

## What this gives you

Once installed, you can open a terminal and just type:

* `sysinfo` → quick view of CPU, memory, disks, uptime
* `netinfo` → network details at a glance
* `extract file.zip` → unpack almost any archive
* `flushdns` → clear DNS cache safely

No configuration required. No prompts. Nothing runs unless you ask for it.

---

## Who this is for

This is for you if:

* You use **Bash** (macOS or Linux)
* You want useful helpers without switching shells
* You want something safe, predictable, and easy to remove

**Note for macOS users:**
macOS defaults to *zsh*. This project is for **Bash**. It works perfectly if:

* You run `bash -l`, or
* Your terminal is set to start Bash as a login shell

---

## Install — step by step (recommended)

### 1. Download the project

Clone the repository:

```bash
git clone https://github.com/macg4dave/My-Mac-Bash-profile
cd My-Mac-Bash-profile
```

(If you don’t use git, download the ZIP and unzip it.)

---

### 2. Run the installer

From inside the project folder:

```bash
scripts/install.sh --repo "$(pwd)"
```

That’s it.

What the installer does:

* Copies the profile into `~/.my-mac-bash-profile`
* Links your `~/.bash_profile` to it
* Sets things up so it works on macOS *and* Linux
* Does **not** modify system files

Nothing destructive. Nothing hidden.

---

### 3. Reload your shell

Either:

* Open a new terminal window, **or**
* Reload manually:

```bash
source ~/.bash_profile
```

---

## Using it

Just type the commands by name.

Try these first:

```bash
sysinfo
netinfo
extract archive.tar.gz
```

If a command exists, it’s ready to use. If it doesn’t, nothing breaks.

---

## Common commands you now have

| Command      | What it does                             |
| ------------ | ---------------------------------------- |
| `sysinfo`    | System overview: CPU, RAM, disks, uptime |
| `netinfo`    | Network status and IPs                   |
| `extract`    | Unpacks zip, tar, gz, 7z, rar, and more  |
| `flushdns`   | Clears DNS cache (safe, best‑effort)     |
| `jd <url>`   | Resume‑safe file download                |
| `jdir <url>` | Download a full directory                |

macOS‑only extras:

* `cdf` — jump to the front Finder window folder
* `gosu` — open a new terminal tab as root

---

## Troubleshooting

### “Nothing loads”

Check that you are actually using Bash:

```bash
echo "$BASH_VERSION"
```

If this prints nothing, your shell is not Bash.

On macOS, set your terminal to start **Bash as a login shell**, or run:

```bash
bash -l
```

### “Something broke my shell”

Disable a feature without editing files:

```bash
export BASH_PROFILE_MODULES_DISABLE="netinfo"
```

Open a new terminal to confirm everything works.

---

### Uninstalling

To remove everything:

```bash
rm -rf ~/.my-mac-bash-profile
rm ~/.bash_profile
```

Nothing else is touched.

---

# Advanced / Power‑User Section

Everything above is all most people need. The rest is here if you like to tinker.

---

## How it works

* `~/.bash_profile` is the entry point
* Modules live in `profile.d/`
* Each feature is isolated and guarded by OS checks

Structure:

* `profile.d/10-common.sh` — cross‑platform helpers
* `profile.d/osx.sh` — macOS‑only helpers
* `profile.d/linux.sh` — Linux‑only helpers
* `profile.d/sysinfo.sh`
* `profile.d/netinfo.sh`
* `profile.d/extract.sh`

---

## Enabling / disabling modules

Disable specific modules:

```bash
export BASH_PROFILE_MODULES_DISABLE="netinfo extract"
```

Load only specific modules:

```bash
export BASH_PROFILE_MODULES_ENABLE="sysinfo"
```

Names can be `netinfo` or `netinfo.sh`.

---

## Local overrides

Add custom logic without touching the repo:

* `profile.d/local.sh` (git‑ignored)
* `~/.config/my-mac-bash-profile/local.sh`

Loaded last.

---

## Machine‑readable output

Some tools support `--kv` for scripting:

```bash
sysinfo --kv
netinfo --kv
```

Outputs stable `key=value` pairs.

---

## Bootstrap scripts

Optional helpers for installing dependencies:

* `scripts/bootstrap-linux.sh`
* `scripts/bootstrap-macos.sh`

Both support `--dry-run`.

---

## Developer notes

* Dev docs: `readme_for_dev.md`
* Roadmap: `roadmap.md`
* Lint/tests:

```bash
make lint
make test
```
