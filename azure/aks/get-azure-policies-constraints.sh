#!/bin/bash

get_default() {
  echo "["
  for crd in $(kubectl get crd -l managed-by=azure-policy-addon -o json | jq -r ".items[].metadata.name")
  do
    kind=$(kubectl get crd ${crd} -o json|jq -r ".spec.names.kind")
    kubectl get ${kind} -o json| jq '.items[] | { "kind": .kind, "name": .metadata.name, "enforcement": .spec.enforcementAction, "violations": .status.totalViolation }' && echo ","
  done
  echo "]"
}

# To list custom policy, please create your own function based on the one above.

get_default