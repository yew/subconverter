#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="${script_dir}/.env"
source_file="${script_dir}/pref.example.yml"
target_file="${script_dir}/pref.yml"

if [[ ! -f "${env_file}" ]]; then
  echo "Missing ${env_file}" >&2
  exit 1
fi

if [[ ! -f "${source_file}" ]]; then
  echo "Missing ${source_file}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${env_file}"
set +a

required_vars=(API_MODE API_ACCESS_TOKEN SERVER_LISTEN)
for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var:-}" ]]; then
    echo "Missing required variable: ${required_var}" >&2
    exit 1
  fi
done

yaml_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "${value}"
}

insert_urls=()

if declare -p INSERT_URLS >/dev/null 2>&1; then
  if [[ "$(declare -p INSERT_URLS 2>/dev/null)" == declare\ -a* ]]; then
    insert_urls=("${INSERT_URLS[@]}")
  else
    echo "INSERT_URLS must be a Bash array" >&2
    exit 1
  fi
else
  echo "Missing required variable: INSERT_URLS" >&2
  exit 1
fi

if (( ${#insert_urls[@]} == 0 )); then
  insert_url_block='  insert_url: []'
else
  insert_url_block=$'  insert_url:\n    ['
  for insert_var_value in "${insert_urls[@]}"; do
    if [[ -n "${insert_var_value}" ]]; then
      escaped_value="$(yaml_escape "${insert_var_value}")"
      insert_url_block+=$'\n      "'
      insert_url_block+="${escaped_value}"
      insert_url_block+=$'",'
    fi
  done
  insert_url_block+=$'\n    ]'
fi

cp "${source_file}" "${target_file}"

export API_MODE API_ACCESS_TOKEN SERVER_LISTEN INSERT_URL_BLOCK="${insert_url_block}"
perl -0pi -e '
  s/^  api_mode: .*$/  api_mode: $ENV{API_MODE}/m;
  s/^  api_access_token: .*$/  api_access_token: $ENV{API_ACCESS_TOKEN}/m;
  s/^  insert_url: \[\]$/$ENV{INSERT_URL_BLOCK}/m;
  s/^  listen: .*$/  listen: $ENV{SERVER_LISTEN}/m;
' "${target_file}"

echo "Generated ${target_file}"