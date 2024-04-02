local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'metrics',
      },
      alertmanager+: {
        config: |||
          global:
            resolve_timeout: 5m
          templates:
            - /etc/alertmanager/config/*.tmpl
          inhibit_rules:
            - equal:
                - namespace
                - alertname
              target_match:
                severity_re: warning|info
              source_match:
                severity: critical
            - equal:
                - namespace
                - alertname
              target_match:
                severity_re: info
              source_match:
                severity: warning
          receivers:
            - name: dingding1
              webhook_configs:
                - url: http://dingtalk:8060/dingtalk/webhook1/send
                  http_config: {}
                  send_resolved: false
          route:
            group_by: []
            group_interval: 5m
            group_wait: 30s
            receiver: dingding1
            repeat_interval: 12h
            routes:
              - receiver: dingding1
                continue: true
                group_interval: 1m
                repeat_interval: 1h
                routes: []
                match:
                  severity: warning
        |||,
      },
    },
    prometheus+:: {
      prometheus+: {
        spec+: {  // https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#prometheusspec
          // If a value isn't specified for 'retention', then by default the '--storage.tsdb.retention=24h' arg will be passed to prometheus by prometheus-operator.
          // The possible values for a prometheus <duration> are:
          //  * https://github.com/prometheus/common/blob/c7de230/model/time.go#L178 specifies "^([0-9]+)(y|w|d|h|m|s|ms)$" (years weeks days hours minutes seconds milliseconds)
          retention: '30d',

          // Reference info: https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/storage.md
          // By default (if the following 'storage.volumeClaimTemplate' isn't created), prometheus will be created with an EmptyDir for the 'prometheus-k8s-db' volume (for the prom tsdb).
          // This 'storage.volumeClaimTemplate' causes the following to be automatically created (via dynamic provisioning) for each prometheus pod:
          //  * PersistentVolumeClaim (and a corresponding PersistentVolume)
          //  * the actual volume (per the StorageClassName specified below)
          replicas: 1,
          resources: {
            requests: {
              cpu: '20m',
              memory: '400Mi',
            },
            limits: {
              cpu: '500m',
              memory: '1Gi',
            },
          },
          exemplars: {
            maxSize: 200000,
          },
          additionalArgs: [
            {name: "enable-feature", value: "exemplar-storage"},
            {name: "enable-feature", value: "exemplar-storage"},
          ],
          storage: {  // https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#storagespec
            volumeClaimTemplate: {  // https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.11/#persistentvolumeclaim-v1-core (defines variable named 'spec' of type 'PersistentVolumeClaimSpec')
              apiVersion: 'v1',
              kind: 'PersistentVolumeClaim',
              metadata: {
                name: 'prometheus-db-pvc'
              },
              spec: {
                accessModes: ['ReadWriteOnce'],
                // https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.11/#resourcerequirements-v1-core (defines 'requests'),
                // and https://kubernetes.io/docs/concepts/policy/resource-quotas/#storage-resource-quota (defines 'requests.storage')
                resources: { requests: { storage: '100Gi' } },
                // A StorageClass of the following name (which can be seen via `kubectl get storageclass` from a node in the given K8s cluster) must exist prior to kube-prometheus being deployed.
                storageClassName: 'gp2',
                // The following 'selector' is only needed if you're using manual storage provisioning (https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/storage.md#manual-storage-provisioning).
                // And note that this is not supported/allowed by AWS - uncommenting the following 'selector' line (when deploying kube-prometheus to a K8s cluster in AWS) will cause the pvc to be stuck in the Pending status and have the following error:
                //  * 'Failed to provision volume with StorageClass "ssd": claim.Spec.Selector is not supported for dynamic provisioning on AWS'
                // selector: { matchLabels: {} },
              },
            },
          },  // storage
        },  // spec
      },  // prometheus
    },  // prometheus

  };

{ ['setup/0namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor is separated so that it can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
