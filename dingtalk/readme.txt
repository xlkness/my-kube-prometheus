
install kustomize:
https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.3.0/kustomize_v5.3.0_linux_amd64.tar.gz

build:
kubectl kustomize ./ > ../manifests_im/dingding-operator.yaml