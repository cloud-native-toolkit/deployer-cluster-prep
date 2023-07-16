
# get manifests
#wget -qO - https://raw.githubusercontent/cloud-native-toolkit/deployer-cluster-prep/argocd-operator > argocd-operator.yaml
#wget -qO - https://raw.githubusercontent/cloud-native-toolkit/deployer-cluster-prep/argocd-instance > argocd-instance.yaml
#wget -qO - https://raw.githubusercontent/cloud-native-toolkit/deployer-cluster-prep/openshift-pipelines-operator > openshift-pipelines-operator.yaml
#wget -qO - https://raw.githubusercontent/cloud-native-toolkit/deployer-cluster-prep/externalsecrets-operator > externalsecrets-operator.yaml
#wget -qO - https://raw.githubusercontent.com/cloud-native-toolkit/deployer-tekton-tasks/main/argocd.yaml > tasks.yaml
#https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-operator/?ref=main
#https://github.com/kubernetes-sigs/kustomize//examples/multibases/dev/?ref=v1.0.6
# install OpenShift GitOps
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-operator/?ref=main --insecure-skip-tls-verify=true
while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  --insecure-skip-tls-verify=true  2>/dev/null; do sleep 30; done
while ! oc wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n openshift-gitops  --insecure-skip-tls-verify=true > /dev/null; do sleep 30; done
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//argocd-instance/?ref=main --insecure-skip-tls-verify=true

# install OpenShift Pipelines
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//openshift-pipelines-operator/?ref=main --insecure-skip-tls-verify=true

# install external secrets operator
oc apply -k https://github.com/cloud-native-toolkit/deployer-cluster-prep//externalsecrets-operator/?ref=main --insecure-skip-tls-verify=true
while ! oc wait crd clustersecretstores.external-secrets.io --timeout=-1s --for=condition=Established --insecure-skip-tls-verify=true  2>/dev/null; do sleep 30; done
while ! oc wait crd externalsecrets.external-secrets.io --timeout=-1s --for=condition=Established --insecure-skip-tls-verify=true  2>/dev/null; do sleep 30; done
while ! oc wait crd operatorconfigs.operator.external-secrets.io --timeout=-1s --for=condition=Established --insecure-skip-tls-verify=true 2>/dev/null; do sleep 30; done

# Give default:pipeline SA cluster-admin permissions
oc create clusterrolebinding pipeline-clusteradmin-crb --clusterrole=cluster-admin --serviceaccount=default:pipeline --insecure-skip-tls-verify=true

# Add deployer tekton tasks to cluster in the default namespace
oc apply -f https://raw.githubusercontent.com/cloud-native-toolkit/deployer-tekton-tasks/main/argocd.yaml --insecure-skip-tls-verify=true

#patch storage class for a default
oc patch storageclass ocs-storagecluster-cephfs  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}' || true
