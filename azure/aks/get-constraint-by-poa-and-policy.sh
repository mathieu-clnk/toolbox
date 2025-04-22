#!/bin/bash

USAGE="get-constraint-by-poa-and-policy.sh -a <assignment_id> -p <policy_id>[ -h ]\n\
Options: \n\
    -a: Required. The policy assignment id. \n\
    -p: Required. The policy id. \n\
    -h: Display this help. \n\
"

usage() {
    echo -e $USAGE
}

die() {
    echo "ERROR: $1"
    exit 1
}

while getopts "a:p:h" opt; do
  case $opt in
     a)
       ASSIGNMENT_ID=$OPTARG
       ;;
    p)
       POLICY_ID=$OPTARG
       ;;
    h)
        usage
        exit 0
        ;;
    *)
        usage
        die "Option not known. Please review the usage."
        ;;
  esac
done
if [ -z "$ASSIGNMENT_ID" ] || [ -z "$POLICY_ID" ]
then
    usage
    die "Please specify the required options"
fi
#To avoid case sensitive issue as the portal is in lower case.
if [[ $(echo $POLICY_ID|grep "/providers"| wc -l) == 1 ]]
then 
    POLICY_ID=$(basename $POLICY_ID)
fi
POLICY_PATH="/providers/Microsoft.Authorization/policyDefinitions/$POLICY_ID"
#To avoid case sensitive issue as the portal is in lower case.
if [[ $(echo $ASSIGNMENT_ID|grep "/subscriptions/"| wc -l) == 1 ]]
then 
    ASSIGNMENT_NAME=$(basename $ASSIGNMENT_ID)
    SUBSCRIPTION_ID=${ASSIGNMENT_ID:15:36}
else
    die "Please provide the full Assignment ID"
fi
ASSIGNMENT_PATH="/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyAssignments/$ASSIGNMENT_NAME"
kind=$(kubectl get constrainttemplates -o jsonpath='{.items[?(@.metadata.annotations.azure-policy-definition-id-1=="'$POLICY_PATH'")].spec.crd.spec.names.kind}')
constraint=$(kubectl get ${kind} -o jsonpath='{.items[?(@.metadata.annotations.azure-policy-assignment-id=="'$ASSIGNMENT_PATH'")].metadata.name}')
kubectl get ${kind} ${constraint} -o json