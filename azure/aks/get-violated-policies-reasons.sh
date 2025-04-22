#!/bin/bash

get_default() {
  for crd in $(kubectl get crd -l managed-by=azure-policy-addon -o custom-columns="CRD-NAME":.metadata.name --no-headers)
  do
    kind=$(kubectl get crd ${crd} -o custom-columns="KIND":.spec.names.kind --no-headers)
    for policy in $(kubectl get ${kind} -o custom-columns="name":.metadata.name --no-headers)
    do
      totalViolations=$(kubectl get ${kind} ${policy} -o custom-columns="violations":.status.totalViolations --no-headers)
      echo "Kind: ${kind}, Constraint policy: ${policy}, total violations: ${totalViolations}"
      if [[ ${totalViolations} -gt 0 ]]
      then
        echo "Reasons of the violations:"
        kubectl get ${kind} ${policy} -o custom-columns="violations":.status.violations[*].message --no-headers | sed -e 's/\.,/.\n/g'
      fi
    done
  done
}

# To list custom policy, please create your own function based on the one above.

get_default