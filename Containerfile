# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/silverblue-main:44
## Other possible base images include:
# FROM quay.io/fedora/fedora-silverblue:latest  (tracks latest stable)
# FROM ghcr.io/ublue-os/bluefin:stable
# FROM ghcr.io/ublue-os/bazzite:stable
#
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base images: quay.io/fedora/fedora-silverblue

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.
# RUN rm /opt && mkdir /opt

### KMODS
## wl (broadcom): installed via ublue akmods pre-built image (avoids akmod-wl root build failure)
COPY --from=ghcr.io/ublue-os/akmods:main-44 / /tmp/akmods-common
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf install -y \
    /tmp/akmods-common/rpms/ublue-os/ublue-os-akmods-addons*.rpm \
    /tmp/akmods-common/rpms/common/broadcom-wl*.rpm \
    /tmp/akmods-common/rpms/kmods/kmod-wl*.rpm && \
    rm -rf /tmp/akmods-common /run/akmods /run/dnf

## facetimehd: installed via COPR in build.sh (akmods-extra image no longer publicly published)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y copr enable mulderje/facetimehd-kmod && \
    dnf5 install -y --setopt=tsflags=noscripts facetimehd-kmod && \
    dnf5 -y mark user facetimehd facetimehd-firmware kmod-facetimehd && \
    dnf5 -y copr disable mulderje/facetimehd-kmod && \
    dnf5 remove -y akmod-facetimehd akmods kmodtool && \
    dnf5 autoremove -y

### MODIFICATIONS
COPY --from=ctx /usr/local/bin/toshy-first-login-setup.sh /usr/local/bin/toshy-first-login-setup.sh
COPY --from=ctx /etc/xdg/autostart/toshy-first-login-setup.desktop /etc/xdg/autostart/toshy-first-login-setup.desktop

RUN chmod +x /usr/local/bin/toshy-first-login-setup.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
