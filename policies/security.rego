package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ── 1. ห้าม container รันเป็น root ───────────────────────────────────────
deny contains msg if {
  input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
  some c in input.spec.template.spec.containers
  not c.securityContext.runAsNonRoot
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := sprintf("[%s/%s] container '%s' must set runAsNonRoot=true",
    [input.kind, input.metadata.name, c.name])
}

# ── 2. ทุก container ต้องมี resource limits ──────────────────────────────
deny contains msg if {
  input.kind in ["Deployment", "StatefulSet"]
  some c in input.spec.template.spec.containers
  not c.resources.limits.memory
  msg := sprintf("[%s/%s] container '%s' missing memory limit",
    [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
  input.kind in ["Deployment", "StatefulSet"]
  some c in input.spec.template.spec.containers
  not c.resources.limits.cpu
  msg := sprintf("[%s/%s] container '%s' missing cpu limit",
    [input.kind, input.metadata.name, c.name])
}

# ── 4. ห้ามไม่ระบุ tag เลย (default = latest) ────────────────────────────
deny contains msg if {
  input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
  some c in input.spec.template.spec.containers
  not contains(c.image, ":")
  msg := sprintf("[%s/%s] container '%s' image '%s' has no tag",
    [input.kind, input.metadata.name, c.name, c.image])
}

# ── 5. ห้าม privileged container ─────────────────────────────────────────
deny contains msg if {
  input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
  some c in input.spec.template.spec.containers
  c.securityContext.privileged == true
  msg := sprintf("[%s/%s] container '%s' must not be privileged",
    [input.kind, input.metadata.name, c.name])
}

# ── 6. ต้องมี liveness + readiness probes ────────────────────────────────
deny contains msg if {
  input.kind in ["Deployment", "StatefulSet"]
  some c in input.spec.template.spec.containers
  not c.livenessProbe
  msg := sprintf("[%s/%s] container '%s' missing livenessProbe",
    [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
  input.kind in ["Deployment", "StatefulSet"]
  some c in input.spec.template.spec.containers
  not c.readinessProbe
  msg := sprintf("[%s/%s] container '%s' missing readinessProbe",
    [input.kind, input.metadata.name, c.name])
}

# ── 7. ทุก resource ต้องมี namespace กำกับ ───────────────────────────────
deny contains msg if {
  input.kind in ["Deployment", "StatefulSet", "Service", "ConfigMap", "Secret"]
  not input.metadata.namespace
  msg := sprintf("[%s/%s] missing namespace",
    [input.kind, input.metadata.name])
}

# ── 8. Warning: ควรมี labels พื้นฐาน ──────────────────────────────────────
warn contains msg if {
  input.kind in ["Deployment", "StatefulSet", "Service"]
  not input.metadata.labels.app
  msg := sprintf("[%s/%s] missing 'app' label",
    [input.kind, input.metadata.name])
}