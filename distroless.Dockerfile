# syntax=docker/dockerfile:1
ARG BUILD_VERSION=6.5.0

FROM python:3.12-bookworm as build

ARG BUILD_VERSION

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /app

# Install under /root/.local
ENV PIP_USER="true"
ARG PIP_NO_WARN_SCRIPT_LOCATION=0
ARG PIP_ROOT_USER_ACTION="ignore"

RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    pip3.12 install streamlink==$BUILD_VERSION && \
    # Cleanup
    find "/root/.local" -name '*.pyc' -print0 | xargs -0 rm -f || true ; \
    find "/root/.local" -type d -name '__pycache__' -print0 | xargs -0 rm -rf || true ;

RUN install -d -m 775 -o 1000 -g 0 /download

# Distroless image use monty(1000) for non-root user
FROM al3xos/python-distroless:3.12-debian12 as final

# ffmpeg
COPY --link --from=mwader/static-ffmpeg:6.1.1 /ffmpeg /usr/bin/

# Copy dist and support arbitrary user ids (OpenShift best practice)
# https://docs.openshift.com/container-platform/4.14/openshift_images/create-images.html#use-uid_create-images
COPY --chown=1000:0 --chmod=775 \
    --from=build /root/.local /home/monty/.local
ENV PATH="/home/monty/.local/bin:$PATH"

COPY --chown=1000:0 --chmod=775 \
    --from=build /download /download
VOLUME [ "/download" ]

WORKDIR /download

STOPSIGNAL SIGINT
ENTRYPOINT [ "streamlink" ]
CMD [ "--help" ]