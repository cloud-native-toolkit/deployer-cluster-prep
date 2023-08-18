
#!/bin/bash

# Exit if any of the intermediate steps fail
set -e
# set bash debug
set -x

export ODF_NAMESPACE=openshift-storage

# install IBM Data Foundation


# create namespace
cat <<EOF | oc apply --insecure-skip-tls-verify=true -f -
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: ${ODF_NAMESPACE}
EOF


#Create the OCS Operator Group
cat <<EOF | oc apply --insecure-skip-tls-verify=true -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: ${ODF_NAMESPACE}
spec:
  targetNamespaces:
    - ${ODF_NAMESPACE}
EOF

#Create subscription for OCS
local ocp_version
local operator
ocp_version=$(oc get ClusterVersion version --insecure-skip-tls-verify=true -o jsonpath='{.status.desired.version}' | cut -d "." -f 1,2) &&
operator="odf-operator"

echo "INFO: Creating Subscription for ${operator}"

cat <<EOF | oc apply --insecure-skip-tls-verify=true -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${operator}
  namespace: ${ODF_NAMESPACE}
spec:
  channel: "stable-${ocp_version}"
  installPlanApproval: Automatic
  name: ${operator}
  source: redhat-operators  # <-- Modify the name of the redhat-operators catalogsource if not default
  sourceNamespace: openshift-marketplace
EOF

while true; do
  if oc get csv -l operators.coreos.com/ocs-operator.openshift-storage="" -n "${ODF_NAMESPACE}" --insecure-skip-tls-verify=true | grep -i "succeeded"; then
    echo "INFO: ODF Subscription is completed"
    break
  else
    echo "INFO: Waiting for Subscription to complete"
    sleep 10
  fi
done



cat <<EOF | oc apply --insecure-skip-tls-verify=true -f -
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  name: ${INFRA_ID}-storage
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: ${INFRA_ID}
spec:
  replicas: 3
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${INFRA_ID}
      machine.openshift.io/cluster-api-machineset: ${INFRA_ID}-storage
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: ${INFRA_ID}
        machine.openshift.io/cluster-api-machine-role: storage
        machine.openshift.io/cluster-api-machine-type: storage
        machine.openshift.io/cluster-api-machineset: ${INFRA_ID}-storage
    spec:
      lifecycleHooks: {}
      metadata:
        labels:
          cluster.ocs.openshift.io/openshift-storage: ''
          node-role.kubernetes.io/storage: ''
      providerSpec:
        value:
          ami:
            id: ${AMI_ID}
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
          - ebs:
              encrypted: true
              iops: 0
              kmsKey:
                arn: ""
              volumeSize: 120
              volumeType: gp3
          credentialsSecret:
            name: aws-cloud-credentials
          deviceIndex: 0
          iamInstanceProfile:
            id: ${INFRA_ID}-worker-profile
          instanceType: m5.4xlarge
          kind: AWSMachineProviderConfig
          metadata:
            creationTimestamp: null
          placement:
            availabilityZone: ${ZONE}
            region: ${AWS_REGION}
          securityGroups:
          - filters:
            - name: tag:Name
              values:
              - ${INFRA_ID}-worker-sg
          subnet:
            id: ${SUBNET}
          tags:
          - name: kubernetes.io/cluster/${INFRA_ID}
            value: owned
          userDataSecret:
            name: worker-user-data
EOF



# install OpenShift GitOps
#oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-operator/?ref=main --insecure-skip-tls-verify=true
#while ! oc wait crd applications.argoproj.io --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait deployment/cluster -n openshift-gitops --timeout=1800s --for=condition=Available  --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait deployment/kam -n openshift-gitops --timeout=1800s --for=condition=Available  --insecure-skip-tls-verify=true; do sleep 30; done
#
#oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-instance/?ref=main --insecure-skip-tls-verify=true
#
## install OpenShift Pipelines
#oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//openshift-pipelines-operator/?ref=main --insecure-skip-tls-verify=true
#while ! oc wait crd pipelines.tekton.dev --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait crd pipelineruns.tekton.dev --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait crd tasks.tekton.dev --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait --for=condition=ready TektonPipelines/pipeline --timeout=1800s --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait --for=condition=Ready TektonAddon/addon  --timeout=1800s --insecure-skip-tls-verify=true; do sleep 10; done
#
#
## install external secrets operator
#oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//externalsecrets-operator/?ref=main --insecure-skip-tls-verify=true
#while ! oc wait crd clustersecretstores.external-secrets.io --timeout=1800s --for=condition=Established --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait crd externalsecrets.external-secrets.io --timeout=1800s --for=condition=Established --insecure-skip-tls-verify=true; do sleep 30; done
#while ! oc wait crd operatorconfigs.operator.external-secrets.io --timeout=1800s --for=condition=Established --insecure-skip-tls-verify=true; do sleep 30; done
#
## Give default:pipeline SA cluster-admin permissions 
#if oc get clusterrolebinding pipeline-clusteradmin-crb; then
#  echo "clusterrolebinding pipeline-clusteradmin-crb added"
#else
#  oc create clusterrolebinding pipeline-clusteradmin-crb --clusterrole=cluster-admin --serviceaccount=default:pipeline --insecure-skip-tls-verify=true
#fi
#
#
## Add deployer tekton tasks to cluster in the default namespace
#oc apply -f https://raw.githubusercontent.com/cloud-native-toolkit/deployer-tekton-tasks/main/argocd.yaml --insecure-skip-tls-verify=true
#while ! oc get Tasks/ibm-pak -n default; do sleep 5; done
#
##patch storage class for a default
#oc patch storageclass ocs-storagecluster-cephfs  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}' || true
