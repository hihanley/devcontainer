# [Choice] Ubuntu version (use hirsute or bionic on local arm64/Apple Silicon): hirsute, focal, bionic
ARG VARIANT="focal"
FROM buildpack-deps:${VARIANT}-curl

# Options for setup script
ARG INSTALL_ZSH="false"
ARG UPGRADE_PACKAGES="true"
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Default to bash shell (other shells available at /usr/bin/fish and /usr/bin/zsh)
ENV SHELL=/bin/bash \
    GOROOT="/usr/local/go" \
    GOPATH="/go" \
    DOCKER_BUILDKIT=1

# SSH Options
ENV SSHD_PORT=22 \
    START_SSHD=true

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
COPY library-scripts/*.sh library-scripts/*.env /tmp/scripts/
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && yes | unminimize 2>&1 \ 
    && bash /tmp/scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    && bash /tmp/scripts/sshd-debian.sh "${SSHD_PORT}" "${USERNAME}" "${START_SSHD}" "skip" "true"

# Install Go, remove scripts now that we're done with them
RUN bash /tmp/scripts/go-debian.sh "latest" "${GOROOT}" "${GOPATH}" "${USERNAME}" \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/scripts

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>