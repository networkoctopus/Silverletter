# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Pre-built kmod RPMs from Universal Blue's daily-built akmods images
# Tag format: <kernel-flavor>-<fedora-version>
# - wl (broadcom) is in the 'common' stream
# - facetimehd is in the 'extra' stream
FROM ghcr.io/ublue-os/akmods:main-44 AS akmods-common
FROM ghcr.io/ublue-os/akmods-extra:main-44 AS akmods-extra

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
## Install pre-built kernel modules from ublue-os/akmods images.
## This avoids running akmods/akmod build scripts as root at image build time,
## which fails in a container context.
COPY --from=akmods-common /rpms/ /tmp/rpms/
COPY --from=akmods-extra /rpms/ /tmp/rpms-extra/

RUN dnf install -y /tmp/rpms/ublue-os/ublue-os-akmods*.rpm && \
    dnf install -y /tmp/rpms/kmods/kmod-wl*.rpm && \
    dnf install -y /tmp/rpms-extra/kmods/kmod-facetimehd*.rpm && \
    rm -rf /tmp/rpms /tmp/rpms-extra

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
