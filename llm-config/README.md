# llm-config

This directory is the Pi.dev configuration directory. It is bind-mounted into
the container at `/root/.pi/agent/` at runtime:

```
./llm-config  →  /root/.pi/agent/
```

Pi.dev reads `models.json` and `settings.json` from this directory on startup
and whenever you open the `/model` command inside Pi.

---

## Setting up models.json

`models.json` declares the LLM providers and models Pi.dev can use. Before your
first run, replace the placeholder values with your actual network details:

1. Open `models.json` in any text editor.
2. Replace `OLLAMA_IP` with the LAN IP address of the machine running Ollama
   (e.g. `192.168.1.100`). **Do not use `localhost` or `host.docker.internal`**
   — those do not resolve correctly from inside the container.
3. Replace `LM_STUDIO_IP` with the LAN IP of the machine running LM Studio.
4. Replace `YOUR_OLLAMA_MODEL_HERE` with a model name that is loaded in Ollama
   (e.g. `llama3.1:8b`).
5. Replace `YOUR_LM_STUDIO_MODEL_HERE` with a model loaded in LM Studio
   (e.g. `qwen2.5-coder:7b`).

You can add more entries to the `"models"` array for each provider. Only the
`"id"` field is required per entry.

Pi.dev does **not** auto-discover models from provider endpoints — you must
declare each model explicitly.

---

## settings.json

`settings.json` controls Pi.dev global settings. The default file sets the
active provider to `ollama`:

```json
{
  "defaultProvider": "ollama"
}
```

Change `"defaultProvider"` to `"lm-studio"` (or any other key from
`models.json`) to switch which provider Pi uses by default when it starts.

---

## Reloading models without restart

Pi.dev reloads `models.json` live when you open the `/model` command inside a
running Pi session. You do **not** need to restart the container after editing
this file — just open `/model` and the new provider or model list will appear.

---

## Verifying providers are reachable

From inside the container, run:

```bash
validate-tooling --strict
```

This checks that every tool in the manifest is installed **and** performs an
HTTP reachability test against each `baseUrl` listed in `models.json`. A
`[warn]` on `provider-reachability` means the IP address is either wrong or the
LLM server is not running. A `[fail]` means a required binary is missing from
the image.
