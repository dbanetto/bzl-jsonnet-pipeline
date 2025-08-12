{
  // Default options
  new(name, trustDomain, ociRegistry)::
    {
      clusterName: name,
      trustDomain: trustDomain,
      registry: { oci: ociRegistry },
    }
    + $.dns.internal.withName(trustDomain)
    + $.fluxcd.registry.withOci(ociRegistry),

  // Builders to configure the options
  // DNS
  dns:: {
    internal:: {
      withName(name):: { dns+: { internal+: { name: name } } },
    },
    external:: {
      withName(name):: { dns+: { external+: { name: name } } },
    },
  },

  // FluxCD
  fluxcd:: {
    notify:: {
      withSlack(webhookUrl):: { fluxcd+: { notify+: { slack: webhookUrl } } },
    },
    registry:: {
      withOci(oci):: { fluxcd+: { registry+: { oci: oci } } },
      withSecretName(name):: { fluxcd+: { registry+: { secretName: name } } },
    },
  },

  // Secrets
  // Used by external-secrets to connect to a OpneBao
  // instance
  secrets:: {
    openbao:: {
      withAddress(address):: { secrets+: { openbao+: { address: address } } },
      withNamespace(namespace):: { secrets+: { openbao+: { namespace: namespace } } },
      withKvPath(kvPath):: { secrets+: { openbao+: { kvPath: kvPath } } },
      withKvVersion(kvVersion):: { secrets+: { openbao+: { kvVersion: kvVersion } } },
      auth:: {
        k8s:: {
          withPath(path):: { secrets+: { openbao+: { auth+: { k8s+: { path: path } } } } },
          withRole(role):: { secrets+: { openbao+: { auth+: { k8s+: { role: role } } } } },
        },
      },
    },
  },
}
