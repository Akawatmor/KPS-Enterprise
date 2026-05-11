# Monitoring Stack

This directory bootstraps the K3s monitoring baseline required for metrics-based canary analysis.

## Components

- `namespace.yaml`: dedicated `monitoring` namespace.
- `traefik-helmchartconfig.yaml`: enables Prometheus metrics on the bundled K3s Traefik controller.
- `kube-prometheus-stack.yaml`: installs Prometheus Operator, Prometheus, Alertmanager, and Grafana via the K3s Helm controller.
- `grafana-admin-secret.sample.yaml`: sample secret manifest for Grafana admin credentials.
- `traefik-podmonitor.yaml`: scrapes Traefik ingress metrics directly from the controller pods without exposing port `9100` through the K3s service load balancer.
- `todoapp-servicemonitor.yaml`: scrapes backend `/metrics` from the stable and canary services.
- `todoapp-prometheusrule.yaml`: alerts for backend availability and canary quality.
- `todoapp-dashboard.yaml`: Grafana dashboard config for TodoApp backend and canary traffic.

## Live bootstrap order

```bash
kubectl apply -f src/phase2-final/monitoring/namespace.yaml
kubectl create secret generic kps-grafana-admin -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='<strong-password>'
kubectl apply -f src/phase2-final/monitoring/traefik-helmchartconfig.yaml
kubectl apply -f src/phase2-final/monitoring/kube-prometheus-stack.yaml
kubectl apply -f src/phase2-final/k8s/networkpolicy.yaml
kubectl apply -f src/phase2-final/monitoring/traefik-podmonitor.yaml
kubectl apply -f src/phase2-final/monitoring/todoapp-servicemonitor.yaml
kubectl apply -f src/phase2-final/monitoring/todoapp-prometheusrule.yaml
kubectl apply -f src/phase2-final/monitoring/todoapp-dashboard.yaml
```

## Verification

```bash
kubectl get pods -n monitoring
kubectl get servicemonitors -n monitoring
kubectl get podmonitors -n monitoring
kubectl get prometheusrules -n monitoring
kubectl get ingress -n monitoring

kubectl get svc -n kube-system traefik
kubectl port-forward -n monitoring svc/kps-monitoring-grafana 3000:80
kubectl port-forward -n monitoring svc/kps-monitoring-kube-prometheus-prometheus 9090:9090
```

The public Grafana hostname is `dashboard-kps.akawatmor.com`.
Create a DNS `A` record for that hostname that points to the Traefik load balancer IP shown by `kubectl get ingress -n monitoring -o wide`.