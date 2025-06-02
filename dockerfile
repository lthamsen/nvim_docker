# Use a specific Debian Slim release for stability.
FROM debian:bookworm-slim

# Set environment variable for non-interactive apt operations
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install core system dependencies and build tools
#    - `build-essential` provides gcc, g++, make.
#    - `cmake`, `ninja` for Neovim compilation.
#    - `nodejs`, `npm`, `golang-go`, `rustc`, `cargo` for LSPs.
#    - `python3`, `python3-pip` for Python tools.
#    - `clang`, `clangd`, `lld`, `libclang-dev`, `llvm-dev` are crucial for clangd.
#    - `libssl-dev` might be needed for some tools, e.g., git cloning or curl over https.
#    - `unzip`, `gzip`, `ripgrep`, `fd`, `fzf` are common utilities.
#    - `openssh-client` for git operations.
#    - `gpg` for adding external apt keys (like the fish shell repo).

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    ninja-build \
    nodejs \
    npm \
    sudo \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    rustc \
    cargo \
    clang \
    clangd \
    lld \
    libclang-dev \
    llvm-dev \
    libssl-dev \
    unzip \
    git \
    gzip \
    ripgrep \
    fd-find \
    fzf \
    gpg \
    openssh-client \
    # Add any other specific dependencies you might need for your plugins (e.g., php, java, etc.)
    && \
    # Install global npm packages often useful for Neovim or LSPs
    npm install -g neovim tree-sitter-cli \
    # Clean up apt cache to keep the image small
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Fish shell from its repository
RUN echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/4/Debian_12/ /' | tee /etc/apt/sources.list.d/shells:fish:release:4.list && \
    curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:4/Debian_12/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/shells_fish_release_4.gpg > /dev/null && \
    apt update && \
    apt install -y fish

# Add fish to valid shells and set it as default for root (and later for 'dev' user)
RUN echo /usr/bin/fish | tee -a /etc/shells # Use /usr/bin/fish as it's installed via apt
RUN chsh -s /usr/bin/fish # Set default shell for the current user (root during build)

# 2. Compile and install Neovim
#    - Using 'ninja' for faster builds.
#    - Deleting the source directory after installation to save space.
#    - Set CMAKE_INSTALL_PREFIX to /usr for standard installation paths.
RUN git clone https://github.com/neovim/neovim.git /usr/src/neovim && \
    cd /usr/src/neovim && \
    make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/usr && \
    make install && \
    rm -rf /usr/src/neovim

# 3. Create a non-root user (recommended for security and best practice)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd -g ${USER_GID} ${USERNAME} || true && \
    useradd -u ${USER_UID} -g ${USERNAME} -s /usr/bin/fish -m ${USERNAME} && \
    mkdir -p /home/${USERNAME}/.local/share/nvim/mason && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Switch to the non-root user for subsequent operations
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# 4. Clone your Neovim configuration
RUN git clone https://github.com/lthamsen/nvim.git /home/${USERNAME}/.config/nvim

# 5. Set up XDG_CONFIG_HOME for Neovim
ENV XDG_CONFIG_HOME="/home/${USERNAME}/.config"

# 6. Install LazyVim plugins
RUN nvim --headless "+Lazy! sync" +qa

# 7. Install Mason packages
#    - clangd is installed via apt, so it's removed from this list.
#    - These should now work on Debian, as they expect glibc.
RUN nvim --headless "+MasonInstall stylua codelldb neocmakelsp lua-language-server texlab" +qa

# Removed pyenv installation as it's not suitable for Dockerfile RUN commands.
# If you need specific Python versions, consider installing them directly via apt
# or using a multi-stage build.

# 8. Install debugpy into a virtual environment
RUN python3 -m venv /home/${USERNAME}/.virtualenvs/debugpy && \
    /home/${USERNAME}/.virtualenvs/debugpy/bin/pip install debugpy



RUN sudo curl -sS https://starship.rs/install.sh | sh -s -- --yes

# RUN echo "starship init fish | source" >> ~/.config/fish/config.fish 

# 9. Set the default command when the container starts
#    This will start the container directly into the Fish shell.
CMD ["fish"]
