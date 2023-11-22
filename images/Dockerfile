# Source: https://github.com/dotnet/dotnet-docker
FROM ghcr.io/actions/actions-runner:latest

USER root

COPY ../scripts/entrypoint.sh ../scripts/reg_token.sh ../scripts/app_token.sh ./
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        jq \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
    && rm -rf /var/lib/apt/lists/*
RUN chmod +x entrypoint.sh reg_token.sh app_token.sh \
    && chown runner:docker entrypoint.sh reg_token.sh app_token.sh

USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
CMD ["bash"]
#CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]