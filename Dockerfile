FROM ubuntu:24.04

# ── Global ENV ───────────────────────────────────────────────────────────────
# All custom tool paths are prepended to PATH so both root (during build) and
# the developer user (at runtime) can invoke every tool without extra config.
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    RUSTUP_HOME=/opt/rust/rustup \
    CARGO_HOME=/opt/rust/cargo \
    DENO_INSTALL=/opt/deno \
    BUN_INSTALL=/opt/bun \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    GRAALVM_HOME=/opt/graalvm \
    GOPATH=/opt/go-workspace \
    DOTNET_ROOT=/usr/local/dotnet \
    PATH="/opt/rust/cargo/bin:/opt/deno/bin:/opt/bun/bin:/usr/local/go/bin:/opt/go-workspace/bin:/opt/graalvm/bin:/usr/local/dotnet:${PATH}"

# ── APT reliability config (retries + IPv4 + timeout) ───────────────────────
# Must be the very first RUN so all subsequent apt operations inherit it.
RUN printf 'Acquire::Retries "5";\nAcquire::http::Timeout "120";\nAcquire::https::Timeout "120";\nAcquire::ForceIPv4 "true";\n' \
    > /etc/apt/apt.conf.d/80-reliability

# ── Locale + ca-certificates (single atomic step to bootstrap HTTPS) ─────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales ca-certificates \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ── Switch APT sources to HTTPS now that ca-certificates is installed ────────
RUN sed -i \
    -e 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' \
    -e 's|http://security.ubuntu.com|https://security.ubuntu.com|g' \
    /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    find /etc/apt -name '*.list' -exec sed -i \
        -e 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' \
        -e 's|http://security.ubuntu.com|https://security.ubuntu.com|g' {} \;

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        wget \
        jq \
        nano \
        vim \
        htop \
        tmux \
        screen \
        pkg-config \
        autoconf \
        automake \
        unzip \
        zip \
        gnupg \
        lsb-release \
        build-essential \
        software-properties-common \
        apt-transport-https \
        postgresql-client \
        default-mysql-client \
        redis-tools \
        sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# ── Java 21 ──────────────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends openjdk-21-jdk \
    && rm -rf /var/lib/apt/lists/*

# ── .NET 9 SDK (via official install script -- avoids launchpadlib TLS issues) ─
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 9.0 --install-dir /usr/local/dotnet \
    && ln -sf /usr/local/dotnet/dotnet /usr/local/bin/dotnet \
    && rm /tmp/dotnet-install.sh

# ── Python 3.13 (built from source -- ppa.launchpadcontent.net is blocked) ───
RUN apt-get update && apt-get install -y --no-install-recommends \
        libssl-dev libffi-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev liblzma-dev xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://www.python.org/ftp/python/3.13.3/Python-3.13.3.tar.xz \
       | tar -xJ -C /tmp \
    && cd /tmp/Python-3.13.3 \
    && ./configure --with-ensurepip=install \
    && make -j$(nproc) \
    && make altinstall \
    && ln -sf /usr/local/bin/python3.13 /usr/bin/python3.13 \
    && ln -sf /usr/local/bin/pip3.13 /usr/local/bin/pip \
    # Symlink in /usr/local/bin so PATH resolves python3 -> 3.13 for users,
    # but /usr/bin/python3 (system 3.12) is untouched for apt_pkg / system tools
    && ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3 \
    && pip install uv \
    && rm -rf /tmp/Python-3.13.3

# ── Node.js LTS ──────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g pnpm yarn \
    && rm -rf /var/lib/apt/lists/*

# ── Go ───────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://go.dev/dl/go1.26.2.linux-amd64.tar.gz -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && mkdir -p /opt/go-workspace

# ── Rust ─────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain stable \
    && /opt/rust/cargo/bin/rustup component add clippy rustfmt \
    && chmod -R a+rX /opt/rust

# ── LLVM / Clang (source added manually -- llvm.sh uses add-apt-repository) ──
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/apt-llvm-org.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/apt-llvm-org.gpg] https://apt.llvm.org/noble/ llvm-toolchain-noble-20 main" \
       > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        clang-20 llvm-20 lld-20 clang-tools-20 clangd-20 \
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 100 \
    && rm -rf /var/lib/apt/lists/*

# ── GraalVM CE ───────────────────────────────────────────────────────────────
RUN GRAAL_VERSION=25.0.2 \
    && mkdir -p /opt/graalvm \
    && curl -fsSL "https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-${GRAAL_VERSION}/graalvm-community-jdk-${GRAAL_VERSION}_linux-x64_bin.tar.gz" \
       | tar -xz -C /opt/graalvm --strip-components=1 \
    && chmod -R a+rX /opt/graalvm

# ── Deno ─────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deno.land/install.sh | sh \
    && chmod -R a+rX /opt/deno

# ── Bun ──────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash \
    && chmod -R a+rX /opt/bun

# ── Build tools: cmake, maven, gradle, protoc ────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        maven \
        gradle \
        protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# ── Bazelisk (as /usr/local/bin/bazel) ───────────────────────────────────────
RUN curl -fsSL https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
        -o /usr/local/bin/bazel \
    && chmod +x /usr/local/bin/bazel

# ── MongoDB Shell ─────────────────────────────────────────────────────────────
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
        | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg \
    && echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" \
        > /etc/apt/sources.list.d/mongodb-org-8.0.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

# ── Pi.dev ───────────────────────────────────────────────────────────────────
RUN npm install -g @mariozechner/pi-coding-agent

# ── Playwright + browsers ─────────────────────────────────────────────────────
RUN npm install -g playwright \
    && playwright install --with-deps chromium firefox webkit \
    && chmod -R a+rX /opt/playwright-browsers

# ── Validate-tooling script ───────────────────────────────────────────────────
COPY scripts/validate-tooling.sh /usr/local/bin/validate-tooling
RUN chmod +x /usr/local/bin/validate-tooling

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN useradd -ms /bin/bash developer
USER developer
WORKDIR /workspace

CMD ["/bin/bash"]
