#!/usr/bin/env bash

# Kubeconfig generator script

set -e

# Script failure catcher
trap 'catch $?' EXIT
catch() {
  if [ "$1" != 0 ]
  then
    # This will execute on any non-zero exit of the script
    cleanup
  fi
}

USERNAME="$1"
GROUPNAME="$2"
KUBECTL_OPTIONS="${*:3}"
CLUSTER_CA="$(mktemp)"
CSRFILE="$(mktemp)"
CERTFILE="$(mktemp)"
KEYFILE="$(mktemp)"

show_usage() {
  echo "" >&2
  echo "Usage: $(basename "$0") <user> <group> [kubectl options]" >&2
  echo "" >&2
  echo "This script creates a K8S kubeconfig valid for 5 years for the specified User and Group and outputs it to the stdout

user - should correspond to the (Cluster)RoleBinding User name if present or otherwise any value
group - should correspond to the (Cluster)RoleBinding Group name if present or otherwise any value

Example:

  $(basename "$0") namespace-admin namespace-admins
  " >&2
  echo "" >&2
  exit 1
}

_kubectl() {
  if [ -z "$KUBECTL_OPTIONS" ]
  then
    kubectl "$@"
  else
    kubectl "$@" "$KUBECTL_OPTIONS"
  fi
}

gen_cert() {
  openssl req -subj "/O=$GROUPNAME/CN=$USERNAME" -new -newkey rsa:2048 -nodes -out "$CSRFILE" -keyout "$KEYFILE"
  openssl x509 -req -sha256 -in "$CSRFILE" -CA "$CLUSTER_CA" -CAkey ca.key -CAcreateserial -out "$CERTFILE" -days 1825
}

cleanup() {
  rm -f "$KUBECONFIG"
  rm -f "$CLUSTER_CA"
  rm -f "$CERTFILE"
  rm -f "$KEYFILE"
  rm -f "$CSRFILE"
}

main() {
  if [[ $# == 0 ]]
  then
    show_usage
  fi

  if [ ! -f ca.key ]
  then
    printf "\n\e[31mCluster CA key \"ca.key\" must be present in the current dir!\nIt could be obtained from any K8S master at /etc/kubernetes/ssl/ca.key\e[0m\n" >&2
    exit 1
  fi

  CONTEXT="$(_kubectl config current-context)"
  CLUSTER="$(_kubectl config view -o "jsonpath={.contexts[?(@.name==\"$CONTEXT\")].context.cluster}")"
  SERVER="$(_kubectl config view -o "jsonpath={.clusters[?(@.name==\"$CLUSTER\")].cluster.server}")"
  CLUSTER_CA_DATA="$(_kubectl get secret -o "jsonpath={.items[0].data.ca\.crt}" | openssl enc -d -base64 -A)"
  echo "$CLUSTER_CA_DATA" > "$CLUSTER_CA"
  NEW_CONTEXT="$USERNAME@$CLUSTER"

  KUBECONFIG="$(mktemp)"
  export KUBECONFIG

  gen_cert >&2

  kubectl config set-credentials "$USERNAME" --client-certificate="$CERTFILE" --client-key="$KEYFILE" --embed-certs=true >/dev/null
  kubectl config set-cluster "$CLUSTER" --server="$SERVER" --certificate-authority="$CLUSTER_CA" --embed-certs=true >/dev/null
  kubectl config set-context "$NEW_CONTEXT" --cluster="$CLUSTER" --user="$USERNAME" >/dev/null
  kubectl config use-context "$NEW_CONTEXT" >/dev/null

  cat "$KUBECONFIG"

  cleanup >&2
}

main "$@"
