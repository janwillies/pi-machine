FROM ghcr.io/janwillies/hummingbird-base:latest

# Install pi dependencies
RUN dnf install -y nodejs && dnf clean all

# Install ripgrep
RUN curl -LO 'https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-aarch64-unknown-linux-gnu.tar.gz' && \
    tar -xzf 'ripgrep-15.2.0-aarch64-unknown-linux-gnu.tar.gz' && \
    mv 'ripgrep-15.2.0-aarch64-unknown-linux-gnu/rg' /usr/local/bin/rg && \
    rm -f 'ripgrep-15.2.0-aarch64-unknown-linux-gnu.tar.gz' && \
    rm -rf 'ripgrep-15.2.0-aarch64-unknown-linux-gnu'

# Install fd
RUN curl -LO https://github.com/sharkdp/fd/releases/download/v10.4.2/fd-v10.4.2-aarch64-unknown-linux-gnu.tar.gz && \
    tar -xzf 'fd-v10.4.2-aarch64-unknown-linux-gnu.tar.gz' && \
    mv 'fd-v10.4.2-aarch64-unknown-linux-gnu/fd' /usr/local/bin/fd && \
    rm -f 'fd-v10.4.2-aarch64-unknown-linux-gnu.tar.gz' && \
    rm -rf 'fd-v10.4.2-aarch64-unknown-linux-gnu'

# Install pi-coding-agent
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent && \
    npm cache clean --force
