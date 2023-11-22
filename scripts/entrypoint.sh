#!/bin/bash

export RUNNER_ALLOW_RUNASROOT=1
export PATH=${PATH}:/actions-runner

# Un-export these, so that they must be passed explicitly to the environment of
# any command that needs them.  This may help prevent leaks.
export -n ACCESS_TOKEN
export -n RUNNER_TOKEN
export -n APP_ID
export -n APP_PRIVATE_KEY

deregister_runner() {
  echo "Caught SIGTERM. Deregistering runner"
  if [[ -n "${ACCESS_TOKEN}" ]]; then
    _TOKEN=$(ACCESS_TOKEN="${ACCESS_TOKEN}" bash ./reg_token.sh)
    RUNNER_TOKEN=$(echo "${_TOKEN}" | jq -r .token)
  fi
  ./config.sh remove --token "${RUNNER_TOKEN}"
  exit
}

_DISABLE_AUTOMATIC_DEREGISTRATION=${DISABLE_AUTOMATIC_DEREGISTRATION:-false}

_RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:="true"}

_RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}
if [[ ${RANDOM_RUNNER_SUFFIX} != "true" ]]; then
  # In some cases this file does not exist
  if [[ -f "/etc/hostname" ]]; then
    # in some cases it can also be empty
    if [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
      _RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(cat /etc/hostname)}
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${_RUNNER_NAME}"
    else
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} ./etc/hostname exists but is empty. Not using /etc/hostname."
    fi
  else
    echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname does not exist. Not using /etc/hostname."
  fi
fi

_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work/${_RUNNER_NAME}}
_LABELS=${LABELS:-default}
_RUNNER_GROUP=${RUNNER_GROUP:-Default}
_GITHUB_HOST=${GITHUB_HOST:="github.com"}
_RUN_AS_ROOT=${RUN_AS_ROOT:="false"}
_START_DOCKER_SERVICE=${START_DOCKER_SERVICE:="false"}

RUNNER_SCOPE="${RUNNER_SCOPE,,}" # to lowercase

case ${RUNNER_SCOPE} in
  org*)
    [[ -z ${ORG_NAME} ]] && ( echo "ORG_NAME required for org runners"; exit 1 )
    _SHORT_URL="https://${_GITHUB_HOST}/${ORG_NAME}"
    RUNNER_SCOPE="org"
    if [[ -n "${APP_ID}" ]] && [[ -z "${APP_LOGIN}" ]]; then
      APP_LOGIN=${ORG_NAME}
    fi
    ;;

  ent*)
    [[ -z ${ENTERPRISE_NAME} ]] && ( echo "ENTERPRISE_NAME required for enterprise runners"; exit 1 )
    _SHORT_URL="https://${_GITHUB_HOST}/enterprises/${ENTERPRISE_NAME}"
    RUNNER_SCOPE="enterprise"
    ;;

  *)
    [[ -z ${REPO_URL} ]] && ( echo "REPO_URL required for repo runners"; exit 1 )
    _SHORT_URL=${REPO_URL}
    RUNNER_SCOPE="repo"
    if [[ -n "${APP_ID}" ]] && [[ -z "${APP_LOGIN}" ]]; then
      APP_LOGIN=${REPO_URL%/*}
      APP_LOGIN=${APP_LOGIN##*/}
    fi
    ;;
esac

configure_runner() {
  ARGS=()
  if [[ -n "${APP_ID}" ]] && [[ -n "${APP_PRIVATE_KEY}" ]] && [[ -n "${APP_LOGIN}" ]]; then
    if [[ -n "${ACCESS_TOKEN}" ]] || [[ -n "${RUNNER_TOKEN}" ]]; then
      echo "ERROR: ACCESS_TOKEN or RUNNER_TOKEN provided but are mutually exclusive with APP_ID, APP_PRIVATE_KEY and APP_LOGIN." >&2
      exit 1
    fi
    echo "Obtaining access token for app_id ${APP_ID} and login ${APP_LOGIN}"
    ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY}" APP_LOGIN="${APP_LOGIN}" bash ./app_token.sh)
  elif [[ -n "${APP_ID}" ]] || [[ -n "${APP_PRIVATE_KEY}" ]] || [[ -n "${APP_LOGIN}" ]]; then
    echo "ERROR: All of APP_ID, APP_PRIVATE_KEY and APP_LOGIN must be specified." >&2
    exit 1
  fi

  if [[ -n "${ACCESS_TOKEN}" ]]; then
    echo "Obtaining the token of the runner"
    _TOKEN=$(ACCESS_TOKEN="${ACCESS_TOKEN}" bash ./reg_token.sh)
    RUNNER_TOKEN=$(echo "${_TOKEN}" | jq -r .token)
  fi

  if [ -n "${EPHEMERAL}" ]; then
    echo "Ephemeral option is enabled"
    ARGS+=("--ephemeral")
  fi

  if [ -n "${DISABLE_AUTO_UPDATE}" ]; then
    echo "Disable auto update option is enabled"
    ARGS+=("--disableupdate")
  fi
  
  if [ -n "${NO_DEFAULT_LABELS}" ]; then
    echo "Disable adding the default self-hosted, platform, and architecture labels"
    ARGS+=("--no-default-labels")
  fi
  
  echo "Configuring"
  ./config.sh \
      --url "${_SHORT_URL}" \
      --token "${RUNNER_TOKEN}" \
      --name "${_RUNNER_NAME}" \
      --work "${_RUNNER_WORKDIR}" \
      --labels "${_LABELS}" \
      --runnergroup "${_RUNNER_GROUP}" \
      --unattended \
      --replace \
      "${ARGS[@]}"

  [[ ! -d "${_RUNNER_WORKDIR}" ]] && mkdir "${_RUNNER_WORKDIR}"

}

if [[ ${_DISABLE_AUTOMATIC_DEREGISTRATION} == "false" ]]; then
  trap deregister_runner SIGINT SIGQUIT SIGTERM INT TERM QUIT
fi

# Start docker service if needed (e.g. for docker-in-docker)
if [[ ${_START_DOCKER_SERVICE} == "true" ]]; then
  echo "Starting docker service"
  _PREFIX=""
  [[ ${_RUN_AS_ROOT} != "true" ]] && _PREFIX="sudo"
  ${_PREFIX} service docker start
fi

if [ -f "/home/runner/.runner" ]; then
  echo "The runner has already been configured"
else
  configure_runner
fi

# Container's command (CMD) execution as runner user
if [[ ${_RUN_AS_ROOT} == "true" ]]; then
  if [[ $(id -u) -eq 0 ]]; then
    "$@"
  else
    echo "ERROR: RUN_AS_ROOT env var is set to true but the user has been overridden and is not running as root, but UID '$(id -u)'"
    exit 1
  fi
else
  if [[ $(id -u) -eq 0 ]]; then
    echo "ERROR: RUN_AS_ROOT env var is not set to true, but user is not overridden and UID '$(id -u)'"
    exit 1
  else
    "$@"
  fi
fi