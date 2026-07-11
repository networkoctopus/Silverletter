# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/silverblue-main:44

### KMODS (broadcom-wl + facetimehd)
COPY --from=ghcr.io/ublue-os/akmods:main-44 / /var/tmp/akmods-common
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/roothome && \
    /ctx/10-kmods.sh && \
    /ctx/15-packages.sh && \
    /ctx/20-power.sh && \
    /ctx/30-fixes.sh && \
    /ctx/40-post-deploy-setup.sh && \
    /ctx/50-updates.sh && \
    /ctx/90-initramfs.sh && \
    /ctx/99-cleanup.sh
    
### LINTING
RUN bootc container lint
