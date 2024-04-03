# !/bin/bash
#
# Copyright (c) 2023 by Delphix. All rights reserved.

con_support_dir=/opt/delphix/support
support_dir=support
mkdir -p $support_dir || die "failed to create $support_dir"
namespace=''
function collect_and_redact_values_yaml_file() {
	helm show values hyperscale-helm >$(pwd)/$support_dir/values.yaml
	echo $(pwd)/$support_dir'/values.yaml created.'
	for key in $(cat hyperscale-helm/tools/values-redact.properties); do
		echo 'Redacting: '$key' value with NULL'
		redactedValues=$(yq -i $key=NULL $(pwd)/$support_dir/values.yaml)
	done
	echo $(pwd)/$support_dir'/values.yaml redacted.'
	namespace=$(yq '.namespace' $(pwd)/$support_dir/values.yaml)
}

collect_and_redact_values_yaml_file
for service_name in controller-service unload-service masking-service load-service; do
	pod_name=$(kubectl get pods --namespace=$namespace -l io.hyperscale.service=$service_name --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
	echo "------------------Started collecting information from service:"$service_name " ,pod:" $pod_name"--------------"
	mkdir -p $support_dir/$pod_name/logs || die "failed to create $support_dir/$pod_name/logs"
	kubectl cp $namespace/$pod_name:$con_support_dir $support_dir/$pod_name || die "failed for kubectl cp"
	kubectl logs $pod_name --namespace=$namespace >>$support_dir/$pod_name/logs/$pod_name.log || die "failed for kubectl logs"
	kubectl exec -it $pod_name --namespace=$namespace -- /bin/bash /opt/delphix/collect_container_support_info.sh $service_name || die "failed for kubectl exec command"
	echo "------------------Finished collecting information from "$pod_name"--------------"
done

function archive_bundle() {
	DEFAULT_PREFIX="hyperscale-support"
	tar -czvf "${DEFAULT_PREFIX}-$(date +"%Y%m%d-%H-%M-%S").tar.gz" $support_dir
}
echo "Generating support bundle tar file..."
archive_bundle

echo "Deleting generated support directory..."
rm -rf $support_dir || die "failed to delete $support_dir"
echo "Generated support directory deleted."
