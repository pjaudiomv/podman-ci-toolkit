# Podman Image with
#   - Buildah, Crane, Cosign, Manifest-Tool, Oras, Make, JQ, Bash, Vault
FROM docker.io/library/alpine:3.21

# renovate: depName=hashicorp/vault
ARG VAULT_VERSION=1.19.0
# renovate: depName=oras-project/oras
ARG ORAS_VERSION=1.2.2
# renovate: depName=sigstore/cosign
ARG COSIGN_VERSION=2.4.3
# renovate: depName=estesp/manifest-tool
ARG MANIFEST_TOOL_VERSION=2.1.9
# renovate: depName=google/go-containerregistry
ARG CRANE_VERSION=0.20.3

ENV BUILDAH_ISOLATION=chroot \
    PATH="/home/builder/.local/bin:$PATH"

RUN apk add --no-cache \
        bash \
        buildah \
        bzip2 \
        ca-certificates \
        git \
        jq \
        make \
        podman \
        skopeo \
        tar \
        unzip \
        wget

# Create user
RUN adduser -D -s /bin/bash -u 1001 -h /home/builder builder && \
    chmod 0750 /home/builder

# Create directories with correct ownership
RUN mkdir -p /home/builder/.docker && \
    mkdir -p /home/builder/.config/containers && \
    mkdir -p /etc/containers && \
    mkdir -p /var/lib/containers/storage && \
    mkdir -p /run/containers/storage && \
    chown -R builder:builder /home/builder/.config && \
    chown -R builder:builder /home/builder/.docker

# Create containers.conf
COPY <<CONTAINERS_CONF /etc/containers/containers.conf
[containers]
netns=\"host\"
userns=\"host\"
ipcns=\"host\"
utsns=\"host\"
cgroupns=\"host\"
cgroups=\"disabled\"
log_driver = \"k8s-file\"
[engine]
cgroup_manager = \"cgroupfs\"
events_logger=\"file\"
runtime=\"crun\"
CONTAINERS_CONF

# Create storage.conf
COPY <<STORAGE_CONF /etc/containers/storage.conf
[storage]
driver = \"vfs\"
runroot = \"/run/containers/storage\"
graphroot = \"/var/lib/containers/storage\"
[storage.options]
additionalimagestores = []
pull_options = {enable_partial_images = \"false\", use_hard_links = \"false\", ostree_repos=\"\"}
STORAGE_CONF

# Create podman-containers.conf
COPY <<PODMAN_CONF /home/builder/.config/containers/containers.conf
[containers]
volumes = [
  \"/proc:/proc\",
]
PODMAN_CONF

# Set proper permissions on config files
RUN chmod 0644 /etc/containers/containers.conf && \
    chmod 0644 /etc/containers/storage.conf && \
    chown builder:builder /home/builder/.config/containers/containers.conf && \
    chmod 0640 /home/builder/.config/containers/containers.conf

# Set permissions and subuid/subgid
RUN chown -R builder:builder /var/lib/containers && \
    chown -R builder:builder /run/containers && \
    echo 'builder:100000:65536' >/etc/subuid && \
    echo 'builder:100000:65536' >/etc/subgid

RUN DETECTED_ARCH=$(uname -m) ARCH=$(if [ "$DETECTED_ARCH" = "arm64" ] || [ "$DETECTED_ARCH" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    wget --progress=dot:giga "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH}.zip" -O /tmp/vault.zip && \
    unzip /tmp/vault.zip -d /tmp && \
    rm /tmp/vault.zip && \
    mv /tmp/vault /usr/bin/vault && \
    chmod +x /usr/bin/vault

RUN DETECTED_ARCH=$(uname -m) ARCH=$(if [ "$DETECTED_ARCH" = "arm64" ] || [ "$DETECTED_ARCH" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    wget --progress=dot:giga "https://github.com/estesp/manifest-tool/releases/download/v${MANIFEST_TOOL_VERSION}/binaries-manifest-tool-${MANIFEST_TOOL_VERSION}.tar.gz" -O /tmp/manifest-tool.tar.gz && \
    tar xzf /tmp/manifest-tool.tar.gz -C /tmp && \
    mv "/tmp/manifest-tool-linux-${ARCH}" /usr/bin/manifest-tool && \
    chmod +x /usr/bin/manifest-tool && \
    rm -rf /tmp/*

RUN DETECTED_ARCH=$(uname -m) ARCH=$(if [ "$DETECTED_ARCH" = "arm64" ] || [ "$DETECTED_ARCH" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    wget --progress=dot:giga "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_${ARCH}.tar.gz" -O /tmp/oras.tar.gz && \
    tar xzf /tmp/oras.tar.gz -C /tmp && \
    mv /tmp/oras /usr/bin/oras && \
    chmod +x /usr/bin/oras && \
    rm -rf /tmp/*

RUN DETECTED_ARCH=$(uname -m) ARCH=$(if [ "$DETECTED_ARCH" = "arm64" ] || [ "$DETECTED_ARCH" = "aarch64" ]; then echo "arm64"; else echo "x86_64"; fi) && \
    wget --progress=dot:giga "https://github.com/google/go-containerregistry/releases/download/v${CRANE_VERSION}/go-containerregistry_Linux_${ARCH}.tar.gz" -O /tmp/crane.tar.gz && \
    tar xzf /tmp/crane.tar.gz -C /tmp && \
    mv /tmp/crane /usr/bin/crane && \
    chmod +x /usr/bin/crane && \
    rm -rf /tmp/*

RUN DETECTED_ARCH=$(uname -m) ARCH=$(if [ "$DETECTED_ARCH" = "arm64" ] || [ "$DETECTED_ARCH" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    wget --progress=dot:giga "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}" -O /usr/bin/cosign && \
    chmod +x /usr/bin/cosign


USER 1001
WORKDIR /home/builder
ENTRYPOINT []

LABEL repository="https://github.com/pjaudiomv/podman-ci-toolkit" \
      maintainer="Patrick Joyce <pjaudiomv@gmail.com>"
