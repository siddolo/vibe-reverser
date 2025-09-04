#!/usr/bin/env bash
set -euo pipefail

AGENT_EXEC_CMD=(codex exec)
AGENT_EXEC_DEFAULT_PARAMETERS=(--skip-git-repo-check --sandbox danger-full-access)
AGENT_DOCKER_NAME='agent-re'

SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME --exec <prompt>
  $SCRIPT_NAME --clean-output
  $SCRIPT_NAME --clean-helper
  $SCRIPT_NAME --clean-docker
  $SCRIPT_NAME --clean-all
  $SCRIPT_NAME --help

Details:
  --exec <prompt>
      Runs the agent defined in AGENT_EXEC_CMD passing the <prompt>
      Example:
        $SCRIPT_NAME --exec "Analyze the file ./target/example.elf"

  --clean-output
      Delete ALL contents inside of ./output/.

  --clean-helper
      Delete ALL contents inside of './helper/'.

  --clean-docker
      Delete docker container '$AGENT_DOCKER_NAME'.

  --clean-all
      Delete docker container '$AGENT_DOCKER_NAME', ALL contents of './output/' and './helper/'.

EOF
}

confirm() {
  local prompt_msg=${1:-"Proceed? [y/N] "}
  local reply
  read -r -p "$prompt_msg" reply || reply=""
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *) echo "Cancelled."; return 1 ;;
  esac
}

clean_dir_output() {
  docker start "$AGENT_DOCKER_NAME" >/dev/null 2>&1 || true
  docker exec "$AGENT_DOCKER_NAME" bash -c "rm -rf ./output/*"
  docker stop "$AGENT_DOCKER_NAME" >/dev/null 2>&1 || true
  echo "Output directory cleaned."
}

clean_dir_helper() {
  docker start "$AGENT_DOCKER_NAME" >/dev/null 2>&1 || true
  docker exec "$AGENT_DOCKER_NAME" bash -c "rm -rf ./helper/*"
  docker stop "$AGENT_DOCKER_NAME" >/dev/null 2>&1 || true
  echo "Helper directory cleaned."
}

clean_agent_docker() {
  docker stop "$AGENT_DOCKER_NAME" >/dev/null 2>&1 || true
  docker rm "$AGENT_DOCKER_NAME"
  echo "Docker cleaned: $AGENT_DOCKER_NAME"
}

run_exec() {
  # Execute the agent command with default parameters plus any user-provided args
  local -a cmd=("${AGENT_EXEC_CMD[@]}" "${AGENT_EXEC_DEFAULT_PARAMETERS[@]}")
  if [[ $# -gt 0 ]]; then
    cmd+=("$@")
  fi
  echo "Running: ${cmd[*]}" >&2
  "${cmd[@]}"
}

main() {
  if [[ ${#@} -eq 0 ]]; then
    usage
    exit 1
  fi

  case "${1:-}" in
    --help|-h)
      usage
      ;;

    --clean-output)
      shift
      if confirm "Confirm deletion of ALL contents in './output/'? [y/N] "; then
        clean_dir_output
      fi
      ;;

    --clean-helper)
      shift
      if confirm "Confirm deletion of ALL contents in './helper/'? [y/N] "; then
        clean_dir_helper
      fi
      ;;

    --clean-docker)
      shift
      if confirm "Confirm deletion of docker '$AGENT_DOCKER_NAME'? [y/N] "; then
        clean_agent_docker
      fi
      ;;

    --clean-all)
      shift
      if confirm "Confirm deletion of docker '$AGENT_DOCKER_NAME', ALL contents in './output/' and './helper/'? [y/N] "; then
        clean_dir_output
        clean_dir_helper
        clean_agent_docker
      fi
      ;;

    --exec)
      shift
      run_exec "$@"
      ;;

    *)
      echo "Error: unrecognized option: $1" >&2
      echo
      usage
      exit 1
      ;;
  esac
}

main "$@"
