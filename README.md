# pi-dev-container

A standalone Docker image containing a full polyglot developer toolchain with
[Pi.dev](https://github.com/mariozechner/pi-coding-agent) pre-installed. Connect
it to Ollama or LM Studio running elsewhere on your network and get a complete,
isolated coding agent environment.

---

## Prerequisites

- Docker installed and running on your machine.
- Ollama **or** LM Studio running on your local network (reachable by IP address).

---

## One-time setup

1. Clone this repository:

   ```bash
   git clone https://github.com/coderandhiker/pi-dev-container.git
   cd pi-dev-container
   ```

2. Edit `llm-config/models.json` — replace the placeholder IP addresses and
   model IDs with your actual values:

   | Placeholder | Replace with |
   |---|---|
   | `OLLAMA_IP` | LAN IP of your Ollama host (e.g. `192.168.1.100`) |
   | `LM_STUDIO_IP` | LAN IP of your LM Studio host |
   | `YOUR_OLLAMA_MODEL_HERE` | A model loaded in Ollama (e.g. `qwen3.6:27b`) |
   | `YOUR_LM_STUDIO_MODEL_HERE` | A model loaded in LM Studio (e.g. `qwen/qwen3.5-35b-a3b`) |

   See `llm-config/README.md` for full details.

---

## Build the image

```bash
docker build -t pi-dev:latest .
```

First build can take a while — it pulls a full polyglot toolchain including multiple language runtimes and browser binaries.

---

## Run standalone

```bash
docker run -it \
  -v "$(pwd)/llm-config":/root/.pi/agent \
  -v "$(pwd)/workspace":/workspace \
  pi-dev:latest
```

Your `workspace/` directory is mounted at `/workspace` inside the container.
Your `llm-config/` directory is mounted as the Pi.dev config directory.

---

## Validate tooling

Inside the container, run:

```bash
validate-tooling --strict
```

This checks every tool in the manifest and tests reachability of your LLM
provider URLs. All tools must pass; provider reachability warnings are expected
if you have not yet configured real IPs.

---

## Start Pi.dev

Inside the container:

```bash
pi
```

Pi reads `~/.pi/agent/models.json` (your mounted `llm-config/`) and connects to
the configured provider.

---

## VS Code Dev Container

1. Open this folder in VS Code.
2. When prompted, click **Reopen in Container** (or run
   **Dev Containers: Reopen in Container** from the command palette).
3. VS Code builds the image (if needed), starts the container, and runs
   `validate-tooling` as the post-create command.

---

## Example: validate-tooling output

```
== validate-tooling summary ==
PASS: 33
FAIL: 0
WARN: 1

[ok] java - openjdk 25.0.2 2026-01-20
[ok] javac - javac 25.0.2
[ok] dotnet - 9.0.313
[ok] python3 - Python 3.13.3
[ok] pip - pip 25.0.1 from /usr/local/lib/python3.13/site-packages/pip (python 3.13)
[ok] uv - uv 0.11.8 (x86_64-unknown-linux-gnu)
[ok] node - v24.15.0
[ok] npm - 11.12.1
[ok] pnpm - 10.33.2
[ok] yarn - 1.22.22
[ok] deno - deno 2.7.14 (stable, release, x86_64-unknown-linux-gnu)
[ok] bun - 1.3.13
[ok] rustc - rustc 1.95.0 (59807616e 2026-04-14)
[ok] cargo - cargo 1.95.0 (f2d3ce0bd 2026-03-21)
[ok] go - found
[ok] gcc - gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
[ok] g++ - g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
[ok] clang - Ubuntu clang version 20.1.8
[ok] cmake - cmake version 3.28.3
[ok] mvn - Apache Maven 3.8.7
[ok] gradle - found
[ok] bazel - bazel 9.1.0
[ok] protoc - libprotoc 3.21.12
[ok] psql - psql (PostgreSQL) 16.13
[ok] mysql - mysql Ver 8.0.45 for Linux on x86_64
[ok] mongosh - 2.8.3
[ok] redis-cli - redis-cli 7.0.15
[ok] sqlite3 - 3.45.1
[ok] pi - 0.72.1
[ok] playwright - Version 1.59.1
[ok] models.json - valid JSON
[warn] provider-reachability - unreachable: http://YOUR_OLLAMA_IP:11434/v1
[ok] provider-reachability - reachable: http://YOUR_LM_STUDIO_IP:1234/v1
[ok] settings.json - valid JSON
```

`[warn]` on `provider-reachability` is expected for any provider that is not currently running. All `[ok]` on tools means the image is complete.
