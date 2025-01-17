#!/bin/bash

function on_exit() {
  rm -rf /tmp/nodeProbe${ID}
  rm -rf /tmp/gridProbe${ID}
}
trap on_exit EXIT

ID=$(echo $RANDOM)

function replace_localhost_by_service_name() {
  internal="${SE_HUB_HOST:-$SE_ROUTER_HOST}:${SE_HUB_PORT:-$SE_ROUTER_PORT}"
  echo "SE_NODE_GRID_URL: ${SE_NODE_GRID_URL}"
  if [[ "${SE_NODE_GRID_URL}" == *"/localhost"* ]]; then
      SE_GRID_URL=${SE_NODE_GRID_URL//localhost/${internal}}
  elif [[ "${SE_NODE_GRID_URL}" == *"/127.0.0.1"* ]]; then
      SE_GRID_URL=${SE_NODE_GRID_URL//127.0.0.1/${internal}}
  elif [[ "${SE_NODE_GRID_URL}" == *"/0.0.0.0"* ]]; then
      SE_GRID_URL=${SE_NODE_GRID_URL//0.0.0.0/${internal}}
  else
      SE_GRID_URL=${SE_NODE_GRID_URL}
  fi
  echo "Set SE_GRID_URL internally: ${SE_GRID_URL}"
}
replace_localhost_by_service_name

if curl -sfk ${SE_SERVER_PROTOCOL}://127.0.0.1:${SE_NODE_PORT}/status -o /tmp/nodeProbe${ID}; then
  NODE_ID=$(jq -r '.value.node.nodeId' /tmp/nodeProbe${ID})
  NODE_STATUS=$(jq -r '.value.node.availability' /tmp/nodeProbe${ID})
  if [ -n "${NODE_ID}" ]; then
    echo "Node responds the ID: ${NODE_ID} with status: ${NODE_STATUS}"
  else
    echo "Wait for the Node to report its status"
    exit 1
  fi

  curl -sfk "${SE_GRID_URL}/status" -o /tmp/gridProbe${ID}
  GRID_NODE_ID=$(jq -e ".value.nodes[].id|select(. == \"${NODE_ID}\")" /tmp/gridProbe${ID} | tr -d '"' || true)
  if [ -n "${GRID_NODE_ID}" ]; then
    echo "Grid responds a matched Node ID: ${GRID_NODE_ID}"
  fi

  if [ "${NODE_STATUS}" = "UP" ] && [ -n "${NODE_ID}" ] && [ -n "${GRID_NODE_ID}" ] && [ "${NODE_ID}" = "${GRID_NODE_ID}" ]; then
    echo "Node ID: ${NODE_ID} is found in the Grid. The registration is successful."
    exit 0
  else
    echo "Node ID: ${NODE_ID} is not found in the Grid. The registration could be in progress."
    exit 1
  fi
else
  echo "Wait for the Node to report its status"
  exit 1
fi
