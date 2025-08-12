function(config, namespace) (
  {
    additions: {
      name: {
        kind: 'ClusterName',
        metadata: { name: config.clusterName },
      },
    },
    patches: [],
  }
)
