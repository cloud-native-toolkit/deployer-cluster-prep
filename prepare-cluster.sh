
#!/bin/bash

# Exit if any of the intermediate steps fail
set -e
# set bash debug
set -x

# install OpenShift GitOps
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-operator/?ref=main --insecure-skip-tls-verify=true
while ! oc wait crd applications.argoproj.io --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait deployment/cluster -n openshift-gitops --timeout=1800s --for=condition=Available  --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait deployment/kam -n openshift-gitops --timeout=1800s --for=condition=Available  --insecure-skip-tls-verify=true; do sleep 30; done

oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-instance/?ref=main --insecure-skip-tls-verify=true

# install OpenShift Pipelines
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//openshift-pipelines-operator/?ref=main --insecure-skip-tls-verify=true
while ! oc wait crd pipelines.tekton.dev --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait crd pipelineruns.tekton.dev --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait crd tasks.tekton.dev --timeout=1800s --for=condition=Established  --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait --for=condition=ready TektonPipelines/pipeline --timeout=1800s --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait --for=condition=Ready TektonAddon/addon  --timeout=1800s --insecure-skip-tls-verify=true; do sleep 10; done


# install external secrets operator
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//externalsecrets-operator/?ref=main --insecure-skip-tls-verify=true
while ! oc wait crd clustersecretstores.external-secrets.io --timeout=1800s --for=condition=Established --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait crd externalsecrets.external-secrets.io --timeout=1800s --for=condition=Established --insecure-skip-tls-verify=true; do sleep 30; done
while ! oc wait crd operatorconfigs.operator.external-secrets.io --timeout=1800s --for=condition=Established --insecure-skip-tls-verify=true; do sleep 30; done

# Give default:pipeline SA cluster-admin permissions 
if oc get clusterrolebinding pipeline-clusteradmin-crb; then
  echo "clusterrolebinding pipeline-clusteradmin-crb added"
else
  oc create clusterrolebinding pipeline-clusteradmin-crb --clusterrole=cluster-admin --serviceaccount=default:pipeline --insecure-skip-tls-verify=true
fi


# Add deployer tekton tasks to cluster in the default namespace
oc apply -f https://raw.githubusercontent.com/cloud-native-toolkit/deployer-tekton-tasks/main/argocd.yaml --insecure-skip-tls-verify=true
while ! oc get Tasks/ibm-pak -n default; do sleep 5; done

#patch storage class for a default
oc patch storageclass ocs-storagecluster-cephfs  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}' || true
