# Allow build scripts to be referenced without being copied into the final image
ARG FEDORA_VERSION=44

FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/akmods:main-${FEDORA_VERSION} AS akmods

FROM ghcr.io/ublue-os/silverblue-main:${FEDORA_VERSION}
ARG FEDORA_VERSION

### KMODS (broadcom-wl + facetimehd)
COPY --from=akmods / /var/tmp/akmods-common
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/roothome && \
    /ctx/10-kmods.sh && \
    /ctx/15-packages.sh && \
    /ctx/20-power.sh && \
    /ctx/25-thunderbolt-extension.sh && \
    /ctx/30-fixes.sh && \
    /ctx/35-mactahoe-theme.sh && \
    /ctx/40-post-deploy-setup.sh && \
    /ctx/50-updates.sh && \
    /ctx/90-initramfs.sh && \
    /ctx/99-cleanup.sh
    
### LINTING
RUN bootc container lint
