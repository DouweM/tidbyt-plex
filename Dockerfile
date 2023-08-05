ARG PIXBYT_IMAGE=ghcr.io/douwem/pixbyt:main
FROM $PIXBYT_IMAGE as base

ENV APP_NAME=plex

WORKDIR /project

# Copy app files
COPY ./ ./apps/${APP_NAME}

# Install apt packages for apps
RUN cat ./apps/**/apt-packages.txt | sort | uniq > ./apps/apt-packages.txt
RUN xargs -a apps/apt-packages.txt apt-get install -y

# Install Meltano plugins for apps
RUN meltano --log-level=debug install extractors tap-pixlet--${APP_NAME}

ENTRYPOINT []
CMD meltano run ${APP_NAME}--webp
