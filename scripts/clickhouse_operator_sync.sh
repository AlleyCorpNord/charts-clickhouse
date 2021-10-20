#!/usr/bin/env bash
#
# This tool fetch and format 'Altinity/clickhouse-operator'
# k8s resource definitions into our chart.
#
# Why do we need this? The 'clickhouse-operator' doesn't expose a Helm
# package so we need to collect and bundle the resources by our own.
#

set -o errexit
set -o nounset

CLICKHOUSE_OPERATOR_TAG="master"
REPO_BASE_URL="https://raw.githubusercontent.com/Altinity/clickhouse-operator/${CLICKHOUSE_OPERATOR_TAG}/deploy/operator"

CURRENT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CHART_PATH_RAW="${CURRENT_DIR}/../charts/posthog"
CHART_PATH=$(cd $CHART_PATH_RAW 2> /dev/null && pwd -P)

function build_filename(){
  local kind=$1
  local name=$2

  if [ "$kind" = "customresourcedefinition" ]; then
    filename="${name}.yaml"
  else
    filename="${kind}-${name}.yaml"
  fi

  echo "$filename"
}

function fetch_and_format() {
  local url=$1
  local dest=$2

  local resources
  resources=$(curl -s "${url}" | yq e -o=json -N | jq . -c)

  OLDIFS=$IFS
  IFS=$'\n'
  for r in ${resources}; do
    local kind
    kind=$(echo "${r}" | jq .kind -r | tr '[:upper:]' '[:lower:]')

    local name
    name=$(echo "${r}" | jq .metadata.name -r | tr '[:upper:]' '[:lower:]')

    local filename
    filename="$(build_filename "$kind" "$name")"

    local filepath
    filepath="${dest}/${filename}"

    echo "Writing $filename to $dest..."
    echo "${r}" | yq e -P - > "$filepath"
  done
  IFS=$OLDIFS
}

fetch_and_format "${REPO_BASE_URL}/clickhouse-operator-install-crd.yaml" "${CHART_PATH}/crds"
fetch_and_format "${REPO_BASE_URL}/clickhouse-operator-install-deployment.yaml" "${CHART_PATH}/templates/clickhouse_operator"
fetch_and_format "${REPO_BASE_URL}/clickhouse-operator-install-service.yaml" "${CHART_PATH}/templates/clickhouse_operator"
