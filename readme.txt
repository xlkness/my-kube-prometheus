执行./build.sh生成新的配置，配置目录manifests

启动：
kubectl apply --server-side -f manifests/setup
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
kubectl apply -f manifests/
kubectl apply -f manifests_im/