# [Choice] Ubuntu version (use hirsute or bionic on local arm64/Apple Silicon): hirsute, focal, bionic
ARG VARIANT="hirsute"
FROM buildpack-deps:${VARIANT}-curl

# Options for setup script
ARG INSTALL_ZSH="false"
ARG UPGRADE_PACKAGES="true"
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG HOMEDIR=/home/$USERNAME

# Default to bash shell (other shells available at /usr/bin/fish and /usr/bin/zsh)
ENV SHELL=/bin/bash \
    NVM_DIR="/home/${USERNAME}/.nvm" \
    NVS_HOME="/home/${USERNAME}/.nvs" \
    NPM_GLOBAL="/home/${USERNAME}/.npm-global" \
    PIPX_HOME="/usr/local/py-utils" \
    GOROOT="/usr/local/go" \
    GOPATH="/go" \
    CARGO_HOME="/usr/local/cargo" \
    RUSTUP_HOME="/usr/local/rustup" \
    SDKMAN_DIR="/usr/local/sdkman"

# SSH Options
ENV SSHD_PORT=22 \
    START_SSHD=true

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
COPY library-scripts/*.sh library-scripts/*.env /tmp/scripts/
RUN yes | unminimize 2>&1 \ 
    && apt-get update \
    && bash /tmp/scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    # Verify expected build and debug tools are present
    && apt-get -y install build-essential cmake cppcheck valgrind clang lldb llvm gdb python3-dev \
    && bash /tmp/scripts/sshd-debian.sh "${SSHD_PORT}" "${USERNAME}" "${START_SSHD}" "skip" "true" \
    # Install Python
    && bash /tmp/scripts/python-debian.sh "none" "/opt/python/latest" "${PIPX_HOME}" "${USERNAME}" "true" \

# Setup Node.js, install NVM and NVS
RUN bash /tmp/scripts/node-debian.sh "${NVM_DIR}" "none" "${USERNAME}" \
    && (cd ${NVM_DIR} && git remote get-url origin && echo $(git log -n 1 --pretty=format:%H -- .)) > ${NVM_DIR}/.git-remote-and-commit \
    # Install nvs (alternate cross-platform Node.js version-management tool)
    && sudo -u ${USERNAME} git clone -c advice.detachedHead=false --depth 1 https://github.com/jasongin/nvs ${NVS_HOME} 2>&1 \
    && (cd ${NVS_HOME} && git remote get-url origin && echo $(git log -n 1 --pretty=format:%H -- .)) > ${NVS_HOME}/.git-remote-and-commit \
    && sudo -u ${USERNAME} bash ${NVS_HOME}/nvs.sh install \
    && rm ${NVS_HOME}/cache/* \
    # Set npm global location
    && sudo -u ${USERNAME} npm config set prefix ${NPM_GLOBAL} \
    && npm config -g set prefix ${NPM_GLOBAL} \
    # Clean up
    && rm -rf ${NVM_DIR}/.git ${NVS_HOME}/.git

# Install SDKMAN, OpenJDK8 (JDK 17 already present), gradle (maven already present)
RUN bash /tmp/scripts/gradle-debian.sh "latest" "${SDKMAN_DIR}" "${USERNAME}" "true" \
    && su ${USERNAME} -c ". ${SDKMAN_DIR}/bin/sdkman-init.sh \
        && sdk install java 11-opt-java /opt/java/17.0 \
        && sdk install java lts-opt-java /opt/java/lts"

# Install Rust, Go, remove scripts now that we're done with them
RUN bash /tmp/scripts/rust-debian.sh "${CARGO_HOME}" "${RUSTUP_HOME}" "${USERNAME}" "true" \
    && bash /tmp/scripts/go-debian.sh "latest" "${GOROOT}" "${GOPATH}" "${USERNAME}" \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/scripts

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>