{
  // Apply a patch on all objects that match a kind
  // To be composed with functions starting with 'apply'
  forKind(kind, f):: function(o) (
    if std.get(o, 'kind') == kind then
      f(o)
    else
      o
  ),
  // Apply a patch on all objects that match a kind and name
  // To be composed with functions starting with 'apply'
  forObject(kind, name, f):: function(o) (
    if std.get(o, 'kind') == kind && o.metadata.name == name then
      f(o)
    else
      o
  ),
  apply:: function(changes) function(o) (o + changes),
  applyDelete:: function(o) (null),

  // Patches that conform to the `k.libsonnet` interface of
  // function(unpatched: object) -> (patched: object)
  removeKind:: function(kind) (
    self.forKind(kind, self.applyDelete)
  ),
  removeObject:: function(kind, name) (
    self.forObject(kind, name, self.applyDelete)
  ),
  removeNamespace:: self.forKind('Namespace', self.applyDelete),
  removeSecrets:: self.forKind('Secret', self.applyDelete),
  removeSecret:: function(name) (
    self.forObject('Secret', name, self.applyDelete)
  ),
  // Sets the servicer-side apply option for the resource managed by FluxCD.
  // Can be: Override (default) ; Merge ; IfNotPresent ; Ignore.
  // Note: Setting IfNotPresent for *WebhookConfigurations & Secret kinds.
  // See https://fluxcd.io/flux/components/kustomize/kustomizations/#controlling-the-apply-behavior-of-resources
  applyKustomizeApplyPolicy(setting):: function(o) (
    o {
      metadata+: {
        annotations+: {
          'kustomize.toolkit.fluxcd.io/ssa': setting,
        },
      },
    }
  ),
  // Sets the recreate policy for a resource managed by FluxCD.
  // Can be: Enabled ; Disabled
  // Default depends on the Kustomization object settings.
  // See https://fluxcd.io/flux/components/kustomize/kustomizations/#controlling-the-apply-behavior-of-resources
  applyKustomizeRecreatePolicy(setting):: function(o) (
    o {
      metadata+: {
        annotations+: {
          'kustomize.toolkit.fluxcd.io/force': setting,
        },
      },
    }
  ),
  // Sets the recreate policy for a resource managed by FluxCD.
  // Can be: Enabled ; Disabled
  // Default depends on the Kustomization object settings.
  // See https://fluxcd.io/flux/components/kustomize/kustomizations/#controlling-the-apply-behavior-of-resources
  applyKustomizeDeletePolicy(setting):: function(o) (
    o {
      metadata+: {
        annotations+: {
          'kustomize.toolkit.fluxcd.io/prune': setting,
        },
      },
    }
  ),

  addVolume:: function(kind, name, volume) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then
        obj {
          spec+: {
            template+: {
              spec+: {
                volumes+: [volume],
              },
            },
          },
        }
      else
        obj
    )
  ),

  addVolumeCliamTemplate:: function(kind, name, claimTemplate) (
    function(obj) (
      if kind != 'StatefulSet' then
        error 'can only be used with a stateful set'
      else
        if std.get(obj, 'kind') == kind && obj.metadata.name == name then
          obj {
            spec+: {
              volumeClaimTemplates+: [claimTemplate],
            },
          }
        else
          obj
    )
  ),
  addVolumeMount:: function(kind, name, containerName, mount) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then
        local containers = obj.spec.template.spec.containers;
        local patchedContainers = std.map(function(c) (
          if c.name == containerName then
            (c {
               volumeMounts+: [mount],
             })
          else c
        ), obj.spec.template.spec.containers);

        obj {
          spec+: {
            template+: {
              spec+: {
                containers: patchedContainers,
              },
            },
          },
        }
      else
        obj
    )
  ),
  addEnvironmentVars:: function(kind, name, containerName, envs) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then
        local containers = obj.spec.template.spec.containers;
        local patchedContainers = std.map(function(c) (
          if c.name == containerName then
            (c {
               env+: envs,
             })
          else c
        ), obj.spec.template.spec.containers);

        obj {
          spec+: {
            template+: {
              spec+: {
                containers: patchedContainers,
              },
            },
          },
        }
      else
        obj
    )
  ),
  addEnvironmentVar:: function(kind, name, containerName, env) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then
        local containers = obj.spec.template.spec.containers;
        local patchedContainers = std.map(function(c) (
          if c.name == containerName then
            (c {
               env+: [env],
             })
          else c
        ), obj.spec.template.spec.containers);

        obj {
          spec+: {
            template+: {
              spec+: {
                containers: patchedContainers,
              },
            },
          },
        }
      else
        obj
    )
  ),
  removeVolume:: function(kind, name, volumeName) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then
        local patchedVolumes = std.filter(function(v) (
          v.name != volumeName
        ), obj.spec.template.spec.volumes);

        obj {
          spec+: {
            template+: {
              spec+: {
                volumes: patchedVolumes,
              },
            },
          },
        }
      else
        obj
    )
  ),
  removeMount:: function(kind, name, containerName, mountName) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then
        local containers = obj.spec.template.spec.containers;
        local patchedContainers = std.map(function(c) (
          if c.name == containerName then
            (c {
               volumeMounts: std.map(function(v) (
                 if v.name == mountName then ({}) else (v)
               ), c.volumeMounts),
             })
          else c
        ), obj.spec.template.spec.containers);

        obj {
          spec+: {
            template+: {
              spec+: {
                containers: patchedContainers,
              },
            },
          },
        }
      else
        obj
    )
  ),
  patchResources:: function(resources, kind, name=null, containerName=null) (
    function(obj) (
      if std.get(obj, 'kind') == kind && (name == null || obj.metadata.name == name) then (
        local containers = obj.spec.template.spec.containers;
        local patchedContainers = std.map(function(ele) (
          if (containerName == null || containerName == ele.name) then
            ele {
              resources: resources,
            }
          else (ele)
        ), containers);

        obj {
          spec+: {
            template+: {
              spec+: {
                containers: patchedContainers,
              },
            },
          },
        }
      ) else (obj)
    )
  ),
  patchNodeSelector:: function(nodeSelector, kind, name) (
    function(obj) (
      if std.get(obj, 'kind') == kind && obj.metadata.name == name then (
        obj {
          spec+: {
            template+: {
              spec+: {
                nodeSelector+: nodeSelector,
              },
            },
          },
        }
      ) else (obj)
    )
  ),
  convertIngressToGRPCRoute:: function(gatewayRef, name) (
    function(obj) (
      if std.get(obj, 'kind') == 'Ingress' && std.get(std.get(obj, 'metadata'), 'name') == name && std.get(obj, 'apiVersion') == 'networking.k8s.io/v1' then (

        local rules = std.flatMap(function(rule) (
          std.map(function(path) (
            {
              backendRefs: [
                {
                  name: path.backend.service.name,
                  port: path.backend.service.port.number,
                  kind: 'Service',
                },
              ],
            }
          ), rule.http.paths)
        ), obj.spec.rules);

        local hostNames = std.flatMap(function(rule) (
          if !std.isArray(rule.host) then [rule.host] else rule.host
        ), obj.spec.rules);

        {
          apiVersion: 'gateway.networking.k8s.io/v1',
          kind: 'GRPCRoute',
          metadata: obj.metadata,
          spec: {
            parentRefs: [gatewayRef],
            hostnames: hostNames,
            rules: rules,
          },
        }
      ) else obj
    )
  ),
  convertIngressToHTTPRoute:: function(gatewayRef) (
    function(obj) (
      if std.get(obj, 'kind') == 'Ingress' && std.get(obj, 'apiVersion') == 'networking.k8s.io/v1' then (

        local rules = std.flatMap(function(rule) (
          std.map(function(path) (
            {
              matches:
                [
                  {
                    path: {
                      type: if path.pathType == 'Prefix' then
                        'PathPrefix' else if path.pathType == 'ImplementationSpecific' then
                        'PathPrefix' else
                        error 'unknown ' + path.pathType,
                      value: path.path,
                    },
                  },
                ],
              backendRefs: [
                {
                  name: path.backend.service.name,
                  port: path.backend.service.port.number,
                  kind: 'Service',
                },
              ],
            }
          ), rule.http.paths)
        ), obj.spec.rules);

        local hostNames = std.flatMap(function(rule) (
          if !std.isArray(rule.host) then [rule.host] else rule.host
        ), obj.spec.rules);

        {
          apiVersion: 'gateway.networking.k8s.io/v1',
          kind: 'HTTPRoute',
          metadata: obj.metadata,
          spec: {
            parentRefs: [gatewayRef],
            hostnames: hostNames,
            rules: rules,
          },
        }
      ) else obj
    )
  ),

}
