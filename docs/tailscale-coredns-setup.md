# Tailscale CoreDNS Setup

This document explains how to patch CoreDNS to forward `.ts.net` queries to the Tailscale operator nameserver.

## Prerequisites

1. Tailscale operator deployed and running
2. DNSConfig resource created and synced by Argo CD
3. `kubectl` access to the cluster

## Steps to Patch CoreDNS

### 1. Wait for Argo CD to Sync

After committing the Tailscale operator changes, ensure Argo CD has synced the DNSConfig:

```bash
# Check if DNSConfig is ready
kubectl -n tailscale get dnsconfig ts-dns -o yaml
```

### 2. Get the Nameserver IP

Once the DNSConfig is ready and has a status, extract the nameserver IP:

```bash
NSIP=$(kubectl -n tailscale get dnsconfig ts-dns -o jsonpath='{.status.nameserverIP}')
echo "Tailscale nameserver IP: $NSIP"
```

### 3. Backup and Edit CoreDNS ConfigMap

```bash
# Backup the current CoreDNS configuration
kubectl -n kube-system get configmap coredns -o yaml > /tmp/coredns-backup.yaml

# Get current configuration for editing
kubectl -n kube-system get configmap coredns -o yaml > /tmp/coredns.yaml
```

### 4. Edit the Corefile

Edit `/tmp/coredns.yaml` and find the `Corefile` section. Append the following configuration block:

```yaml
# Add this to the Corefile data section, after the existing server blocks
ts.net {
  errors
  cache 30
  forward . ${NSIP}
}
```

**Note**: Replace `${NSIP}` with the actual IP address obtained in step 2.

### 5. Apply the Changes

```bash
# Apply the updated CoreDNS configuration
kubectl -n kube-system apply -f /tmp/coredns.yaml

# Restart CoreDNS to pick up the new configuration
kubectl -n kube-system rollout restart deploy coredns

# Verify the rollout completed
kubectl -n kube-system rollout status deploy coredns
```

### 6. Test DNS Resolution

Test that `.ts.net` names can be resolved from within the cluster:

```bash
# Create a test pod to verify DNS resolution
kubectl run dns-test --rm -it --image=busybox --restart=Never -- nslookup some-device.ts.net

# Or test from an existing pod
kubectl exec -it <some-pod> -- nslookup some-device.ts.net
```

## Troubleshooting

### Check DNSConfig Status

```bash
kubectl -n tailscale describe dnsconfig ts-dns
```

### Check CoreDNS Logs

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns
```

### Verify CoreDNS Configuration

```bash
kubectl -n kube-system get configmap coredns -o yaml | grep -A 10 -B 5 "ts.net"
```

### Reset CoreDNS (if needed)

```bash
# Restore from backup if something goes wrong
kubectl -n kube-system apply -f /tmp/coredns-backup.yaml
kubectl -n kube-system rollout restart deploy coredns
```

## Example Complete Corefile

After patching, your Corefile should look similar to this:

```
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}

ts.net {
  errors
  cache 30
  forward . 10.96.0.100
}
```

## Notes

- The Tailscale nameserver IP is dynamically assigned and may change if the DNSConfig is recreated
- This setup allows pods to resolve Tailscale Magic DNS names (*.ts.net) from within the cluster
- The configuration persists across CoreDNS restarts but may need to be reapplied if the ConfigMap is reset