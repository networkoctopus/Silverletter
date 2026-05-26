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
    /ctx/build_files/10-kmods.sh

### FIXES (sleep hooks, backlight, wakeup)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/build_files/15-fixes.sh

### POWER (powertop, mbpfan, aspm, wifi powersave)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/20-power.sh

### PACKAGES (intel-gpu-tools, gnome extensions, dconf, toshy deps)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/30-packages.sh

### TOSHY (first-login setup scripts + service)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build_files/40-toshy.sh

### UPDATES (uupd, disable rpm-ostreed auto-updates, flatpak remotes)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/build_files/50-updates.sh

### CLEANUP
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    /ctx/build_files/100-cleanup.sh

### LINTING
RUN bootc container lint
