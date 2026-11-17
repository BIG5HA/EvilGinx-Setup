# Evilginx Lab Deployment Automation

**Bash · Expect · Linux Infrastructure · Authorized AiTM Research**

A Bash deployment and validation script for preparing an [Evilginx](https://github.com/kgretzky/evilginx2) lab on a Linux x86-64 host. It validates the environment and input parameters, retrieves a pinned upstream release, checks its integrity, extracts it into a user-specific laboratory directory, and starts an interactive session through **Expect**.

> **Responsible use:** Evilginx is a dual-use security-testing framework. Run this script and any testing activities only on infrastructure, domains and accounts you own or are explicitly authorized to assess. The repository contains deployment automation, not permission to intercept third-party sessions.

## Repository contents

```text
setup-evilginx.sh    # Bash/Expect setup and launch script
README.md            # This guide
```

The original uploaded script was named `setup-evilginx(1).sh`. The example filename above is a cleaner repository name; if you keep the uploaded filename, substitute it in the commands below. The script does **not** require its own filename to be changed.

## Features

- Validates Linux and `x86_64` architecture.
- Validates an input domain name and IPv4 address.
- Checks required command-line tools and installs missing APT packages if possible.
- Looks up the supplied domain's IPv4 DNS records and compares them with the given address.
- Checks the latest upstream GitHub release against a pinned version.
- Downloads a specific release ZIP and checks both its **SHA-256 checksum** and ZIP integrity.
- Extracts the release into a persistent laboratory directory.
- Makes the extracted executable runnable.
- Uses **Expect** to automate initial interactive configuration input, then hands control over to the operator.

## Requirements

- Linux on **x86-64**.
- An APT-based distribution for automatic dependency installation.
- Bash and a working internet connection.
- Permissions to install missing packages and create the extraction directory.
- An authorized domain name and the corresponding server IPv4 address.

Dependencies checked by the script include `curl`, `jq`, `unzip`, `sha256sum`, `getent`, `awk`, `expect`, `sort`, `grep`, and `mktemp`.

## Usage

The script accepts **exactly two positional arguments**:

```text
<domain> <ipv4>
```

For a domain and address you control:

```bash
bash setup-evilginx.sh lab.example.org 192.0.2.10
```

The example uses a reserved documentation IPv4 address; substitute your own authorized lab values. The script uses the supplied domain and IP for validation and interactive application setup.

To make the script executable first:

```bash
chmod +x setup-evilginx.sh
./setup-evilginx.sh lab.example.org 192.0.2.10
```

If you retain the uploaded filename `setup-evilginx(1).sh`, quote it when invoking it:

```bash
bash 'setup-evilginx(1).sh' lab.example.org 192.0.2.10
```

## Configuration and installation

| Configuration | Actual value in the script |
| --- | --- |
| Pinned release | `v3.3.0` |
| Expected ZIP | `evilginx-v3.3.0-linux-64bit.zip` |
| Release metadata | GitHub API for `kgretzky/evilginx2` |
| Extracted location | `$USER_HOME/evilginx-lab/extracted` |
| Main extracted executable | `$EXTRACT_DIR/evilginx` |
| Automatic interactive setup | Bash invokes Expect and transfers control to the terminal |

When run with `sudo`, the script attempts to use the invoking user's home directory via `SUDO_USER`, rather than placing the laboratory files in root's home directory.

## Setup workflow

```text
Validate two input arguments
          ↓
Linux and CPU architecture check
          ↓
Dependency check / APT installation if needed
          ↓
Release metadata and pinned-version verification
          ↓
DNS IPv4 lookup and comparison
          ↓
Download upstream release archive
          ↓
SHA-256 checksum and ZIP integrity verification
          ↓
Extract into the user's lab directory
          ↓
Set executable permission
          ↓
Launch via Expect and enter interactive session
```

The DNS check **warns but does not stop the deployment** when records are missing or do not match. This is the behavior of the actual script, not an assertion that DNS is correctly configured.

## Integrity and reproducibility

The setup script contains a **fixed SHA-256 value** for the pinned release. It rejects a downloaded archive whose checksum does not match the built-in value and also runs a ZIP integrity test before extraction.

It checks the upstream *latest release tag* against `v3.3.0`. If the latest upstream version differs, **the script stops** rather than silently deploying a new version. Review and update both the pinned version and its checksum before changing the release.

## Important implementation details

- **No overwrite:** the extraction step refuses to proceed if the target extraction directory already exists. This is not an in-place upgrade utility.
- **APT dependencies:** the script can install missing dependencies automatically but requires a working APT-based environment for that path.
- **DNS mismatch:** reported as a warning in the main workflow, not a hard error.
- **Interactive process:** Expect automates initial setup input and then uses `interact`, leaving the process attached to the terminal. This is **not** a systemd service installation.
- **TLS and site-specific testing configuration:** the script does not provision certificates or include a full site-specific test configuration. Those steps are outside its documented automated scope.
- **Release integrity:** ZIP CRC verification and a known SHA-256 value protect the downloaded archive against accidental corruption or unexpected content, assuming the checksum is itself trusted.

## Troubleshooting

Verify Bash syntax before running the installer:

```bash
bash -n setup-evilginx.sh
```

Check availability of important utilities:

```bash
command -v curl jq unzip sha256sum expect
```

For failures, review the script's terminal output at the environment, dependencies, release-check, download, checksum, extraction or Expect launch stage. If the destination directory already exists, the script will stop rather than replace it.

## Scope and credits

This is an **independent Bash/Expect automation project** built around the upstream Evilginx release. It does not claim authorship of the Evilginx framework itself.

- **Evilginx upstream:** [kgretzky/evilginx2](https://github.com/kgretzky/evilginx2)
- **Deployment automation and lab documentation:** Nehoray Shaul
- **Portfolio case study:** [Evilginx Project](https://bigsha.pages.dev/projects/evilginx/)

Use only in authorized security training and testing environments.
