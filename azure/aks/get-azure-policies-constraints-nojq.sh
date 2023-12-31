#!/bin/bash

get_default() {
  for crd in $(kubectl get crd -l managed-by=azure-policy-addon -o custom-columns="CRD-NAME":.metadata.name --no-headers)
  do
    kind=$(kubectl get crd ${crd} -o custom-columns="KIND":.spec.names.kind --no-headers)
    kubectl get ${kind} -o custom-columns="kind":.kind,"name":.metadata.name,"enforcement":.spec.enforcementAction,"assignment-id":.metadata.annotations.azure-policy-assignment-id,"definition-id":.metadata.annotations.azure-policy-definition-id,"setdefinition-id":.metadata.annotations.azure-policy-setdefinition-id
  done
}

# To list custom policy, please create your own function based on the one above.

get_default