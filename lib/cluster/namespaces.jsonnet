local output = import 'lib/output.libsonnet';
local patches = import 'lib/patches.libsonnet';

// local k = import 'k.libsonnet';

// Addons defined in ../addons.bzl
local parseAddon = function(addon) (
  local segments = std.prune(std.split(addon.key, '/'));
  local lastSegment = segments[std.length(segments) - 1];
  local nameTag = std.splitLimit(lastSegment, ':', 2);
  local pathSegments = std.map(function(e) (
    std.splitLimit(e, ':', 2)[0]
  ), segments);

  [
    {
      namespace: addon.value.namespace,
      labels: std.get(addon.value, 'labels', {}),
      annotations: std.get(addon.value, 'annotations', {}) {
        'k8s.ohno.cloud/source': addon.key,
      },
    },
  ]
);

function(applicationsJson, addonsJson) (
  local targets =
    std.flatMap(parseAddon, std.objectKeysValues(std.parseJson(applicationsJson)))
    + std.flatMap(parseAddon, std.objectKeysValues(std.parseJson(addonsJson)));

  output.renderDirectory({
    namespaces: [
      // k.core.v1.namespace.new(target.key)
      // + k.core.v1.namespace.metadata.withAnnotationsMixin(
      //   std.get(target.value, 'annotations', {}) {
      //     // Prevent deletion of Namespaces by Kustomize
      //     'kustomize.toolkit.fluxcd.io/prune': 'Disabled',
      //     // Prevents recreation from un-merge-able fileds
      //     'kustomize.toolkit.fluxcd.io/force': 'Disabled',
      //     // Preserves current settings and only sets manifests defined values
      //     'kustomize.toolkit.fluxcd.io/ssa': 'Merge',
      //   }
      // )
      // + k.core.v1.namespace.metadata.withLabelsMixin(
      //   std.get(target.value, 'labels', {})
      // )

      // Collopase targets by namespace to prevent duplication
      // for target in std.objectKeysValues(std.foldl(function(acc, idx) (
      //   acc {
      //     [std.get(idx, 'namespace')]+: {
      //       labels+: std.get(idx, 'labels', {}),
      //       annotations+: std.get(idx, 'annotations', {}),
      //     },
      //   }
      // ), targets, {}))
      // if  // Filter out known default namespaces
      //       target.key != 'kube-system' ||
      //       target.key != 'default'
    ],
  })
)
