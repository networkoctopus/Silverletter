# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Pre-built kmod RPMs from Universal Blue's daily-built akmods images
# 'common' stream includes wl (broadcom)
FROM ghcr.io/ublue-os/akmods:common

# Base Image - Fedora Silverblue 44 with GNOME 50
FROM quay.io/fedora/fedora-silverblue:44
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
## facetimehd: installed via COPR in build.sh (akmods-extra image no longer publicly published)
COPY --from=akmods-common /rpms/ /tmp/rpms/

RUN dnf install -y /tmp/rpms/ublue-os/ublue-os-akmods*.rpm && \
    dnf install -y /tmp/rpms/kmods/kmod-wl*.rpm && \
    rm -rf /tmp/rpms

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
