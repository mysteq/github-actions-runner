# Source: https://github.com/dotnet/dotnet-docker
FROM ghcr.io/actions/actions-runner:latest

ARG TARGETOS
ARG TARGETARCH
ARG PWSH_VERSION=7.4.0
ARG OSVERSION=22.04

USER root

COPY scripts/entrypoint.sh scripts/reg_token.sh scripts/app_token.sh ./
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

RUN curl -sSL -O https://packages.microsoft.com/config/ubuntu/${OSVERSION}/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm -f packages-microsoft-prod.deb \
    && apt-get update \
    && rm -rf /var/lib/apt/lists/*

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export PWSH_ARCH=x64 ; fi \
    && if [ "$RUNNER_ARCH" = "arm64" ]; then export PWSH_ARCH=arm64 ; fi \
    && curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz \
    && mkdir -p /usr/share/powershell/7 \
    && tar zxf /tmp/powershell.tar.gz -C /usr/share/powershell/7 \
    && rm -f /tmp/powershell.tar.gz \
    && chmod +x /usr/share/powershell/7/pwsh \
    && ln -s /usr/share/powershell/7/pwsh /usr/bin/pwsh

# RUN curl -s https://packagecloud.io/install/repositories/opentofu/tofu/script.deb.sh?any=true -o /tmp/tofu-repository-setup.sh \
#     && chmod +x /tmp/tofu-repository-setup.sh \
#     && /tmp/tofu-repository-setup.sh \
#     && rm -f /tmp/tofu-repository-setup.sh \
#     && apt-get update \
#     && apt-get install -y --no-install-recommends \
#         tofu \
#     && rm -rf /var/lib/apt/lists/*

RUN chmod +x entrypoint.sh reg_token.sh app_token.sh \
    && chown runner:docker entrypoint.sh reg_token.sh app_token.sh

USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
#CMD [ "bash" ]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]