## Build this Containerfile:
# container build --tag ghcr.io/janwillies/fedora-base:latest --file Containerfile .

FROM quay.io/fedora/fedora:44@sha256:55159f5c92b7baf5f1c1ca1d727c95e77a4cb77c0829b2c11740a700ff4ea02b

# only install en_US translations; must precede the dnf install to take effect
RUN echo "%_install_langs en_US:en" > /etc/rpm/macros.image-language-conf

# systemd provides /sbin/init, which is all a container machine needs; NetworkManager
# does DHCP on the virtio NIC; sudo/passwd are used by Apple's first-boot provisioning;
# chrony resyncs the clock, which otherwise drifts across host sleep and breaks TLS/git.
RUN dnf install -y \
        --setopt=install_weak_deps=False \
        --setopt=tsflags=nodocs \
        systemd dbus-broker NetworkManager openssh-server sudo passwd chrony \
        tar xz git-core curl wget ncurses-term which python3 nodejs npm dnf5-plugins systemd-pam && \
    dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf install -y gh && \
    dnf clean all && \
    rm -rf /usr/share/locale/* && \
    mkdir -p /usr/local/bin

# systemd treats an empty machine-id as first boot and provisions on start
RUN : > /etc/machine-id

RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
    echo "Europe/Berlin" > /etc/timezone

# the journal is uncapped by default and grows over the machine's lifetime
RUN mkdir -p /etc/systemd/journald.conf.d && \
    printf '[Journal]\nSystemMaxUse=32M\n' > /etc/systemd/journald.conf.d/00-size.conf

# https://github.com/apple/container/blob/main/docs/container-machine.md#bring-your-own-container-machine-image
# systemctl set-default does not persist here; the base ships
# /usr/lib/systemd/system/default.target -> graphical.target, so override it in /etc
RUN ln -sf /usr/lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# Apple's sample also masks systemd-tmpfiles-setup, but Fedora provisions /var from
# tmpfiles.d (e.g. /var/lib/chrony), so masking it breaks packages at boot.
RUN systemctl mask \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      systemd-update-utmp.service \
      console-getty.service

# StrictModes no because virtiofs mounts present ownership that sshd would otherwise reject.
# authorized_keys lives under /home/%u, which is provided at runtime via the
# host's home/ mount (see run-*.sh / *-vm zsh functions), not baked into the image.
RUN printf 'AuthorizedKeysFile /home/%%u/.ssh/authorized_keys\nStrictModes no\n' \
      > /etc/ssh/sshd_config.d/01-container-machine.conf


# Apple's first-boot provisioning ends with a recursive chown of CONTAINER_HOME
# (/sbin.machine/create-user.sh). /home is a virtiofs mount of the host tree,
# whose files already arrive owned by the invoking uid:gid, so that chown only
# re-stamps ownership the files already have -- at one host round trip per file,
# ~3.5 minutes for ~30k files, all of it before the first shell appears.
# /sbin.machine/init prefers /etc/machine/create-user.sh over its built-in copy,
# so ship the same steps with the recursion dropped.
RUN mkdir -p /etc/machine && \
    printf '%s\n' \
      '#!/bin/sh' \
      'set -e' \
      'if ! getent group "${CONTAINER_GID}" >/dev/null 2>&1; then' \
      '    echo "${CONTAINER_USER}:x:${CONTAINER_GID}:" >> /etc/group' \
      'fi' \
      'if ! getent passwd "${CONTAINER_UID}" >/dev/null 2>&1; then' \
      '    echo "${CONTAINER_USER}:x:${CONTAINER_UID}:${CONTAINER_GID}::${CONTAINER_HOME}:${CONTAINER_SHELL}" >> /etc/passwd' \
      '    echo "${CONTAINER_USER}:!:19000:0:99999:7:::" >> /etc/shadow' \
      'fi' \
      'mkdir -p "${CONTAINER_HOME}"' \
      'if [ -d /etc/skel ]; then' \
      '    cp -a /etc/skel/. "${CONTAINER_HOME}"' \
      'fi' \
      'chown "${CONTAINER_UID}:${CONTAINER_GID}" "${CONTAINER_HOME}"' \
      'mkdir -p /etc/sudoers.d' \
      'sudoers_file=$(echo "${CONTAINER_USER}" | tr "." "_")' \
      'echo "${CONTAINER_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${sudoers_file}"' \
      'chmod 440 "/etc/sudoers.d/${sudoers_file}"' \
      > /etc/machine/create-user.sh && \
    chmod 755 /etc/machine/create-user.sh

# npm config set prefix ~/.local
# npm install -g @agentclientprotocol/claude-agent-acp
