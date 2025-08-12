local output = import 'lib/output.libsonnet';

//local externalSecrets = import 'external-secrets/main.libsonnet';
//local flux = import 'flux/main.libsonnet';
//local k = import 'k.libsonnet';

//local secretStore = externalSecrets.nogroup.v1.secretStore;
//local passwordGenerator = externalSecrets.generators.v1alpha1.password;
//local externalSecret = externalSecrets.nogroup.v1.externalSecret;


function(
  namespace,
  basePath,
  applicationsJson,
  addonsJson,
  configJson,
) (
  local cfg = std.parseJson(configJson);
  local fluxcdCfg = std.get(cfg, 'fluxcd', {});
  local registry = std.get(fluxcdCfg, 'registry', {
    secretName: null,
  });
  local registrySecretName = std.get(registry, 'secretName', null);
  local ociRegistry = std.get(registry, 'oci', cfg.oci.registry);

  // Addons defined in ../addons.bzl
  local parseAddon = function(prefix) (
    function(app) (
      local segments = std.prune(std.split(app.key, '/'));
      local lastSegment = segments[std.length(segments) - 1];
      local nameTag = std.splitLimit(lastSegment, ':', 2);
      local pathSegments = std.map(function(e) (
        std.splitLimit(e, ':', 2)[0]
      ), segments);

      [
        {
          name: prefix + '-' + nameTag[0],
          tag: if std.length(nameTag) == 1 then 'latest' else nameTag[1],
          namespace: app.value.namespace,
          ociUrl: std.join('/', [
            'oci:/',
            ociRegistry,
            std.get(app.value, 'ociPath', std.stripChars(std.join('/', pathSegments), '/')),
          ]),
        },
      ]
    )
  );


  local targets =
    // Default 'namespaces' target
    [{
      name: 'namespaces',
      tag: 'latest',
      ociUrl: std.join('/', ['oci:/', ociRegistry, basePath + '-namespaces']),
    }]
    // Applications
    + std.flatMap(parseAddon('app'), std.objectKeysValues(std.parseJson(applicationsJson)))
    // Base addons
    + std.flatMap(parseAddon('addon'), std.objectKeysValues(std.parseJson(addonsJson)));


  output.multi(
    {
      // (if registrySecretName != null then {
      //    ociReposSa: k.core.v1.serviceAccount.new(registrySecretName),
      //    ociRepoSecretStore:
      //      secretStore.new('openbao')
      //      + secretStore.spec.provider.vault.withServer(cfg.secrets.openbao.address)
      //      + secretStore.spec.provider.vault.withPath(cfg.secrets.openbao.kvPath)
      //      + secretStore.spec.provider.vault.withVersion(cfg.secrets.openbao.kvVersion)
      //      + secretStore.spec.provider.vault.auth.kubernetes.withMountPath(cfg.secrets.openbao.auth.k8s.path)
      //      + secretStore.spec.provider.vault.auth.kubernetes.withRole(cfg.secrets.openbao.auth.k8s.role)
      //      + secretStore.spec.provider.vault.auth.kubernetes.serviceAccountRef.withName($.ociReposSa.metadata.name)
      //      + secretStore.spec.provider.vault.auth.kubernetes.serviceAccountRef.withAudiences('secrets-read'),
      //
      //    ociRepoSecret:
      //      externalSecret.new(registrySecretName)
      //      + externalSecret.spec.secretStoreRef.withKind('SecretStore')
      //      + externalSecret.spec.secretStoreRef.withName($.ociRepoSecretStore.metadata.name)
      //      + externalSecret.spec.target.template.withType('kubernetes.io/dockerconfigjson')
      //      + externalSecret.spec.withData([
      //        externalSecret.spec.data.withSecretKey('.dockerconfigjson')
      //        + externalSecret.spec.data.remoteRef.withKey(std.join('/', [namespace, registry.secretName])),
      //      ]),
      //  } else {}) +
      // {
      //   ociRepos: [
      //     flux.source.v1beta2.ociRepository.new(target.name)
      //     + flux.source.v1beta2.ociRepository.spec.withInterval('120s')
      //     + flux.source.v1beta2.ociRepository.spec.withUrl(target.ociUrl)
      //     + flux.source.v1beta2.ociRepository.spec.ref.withTag(target.tag)
      //     + (if registrySecretName != null then flux.source.v1beta2.ociRepository.spec.secretRef.withName(registrySecretName) else {})
      //     for target in targets
      //   ],
      //
      //
      //   kustomizes: [
      //     // Namespaced targets
      //     flux.kustomize.v1.kustomization.new(target.name)
      //     + flux.kustomize.v1.kustomization.spec.sourceRef.withKind('OCIRepository')
      //     + flux.kustomize.v1.kustomization.spec.withInterval('600s')
      //     + flux.kustomize.v1.kustomization.spec.withTimeout('360s')
      //     + flux.kustomize.v1.kustomization.spec.withRetryInterval('30s')
      //     + flux.kustomize.v1.kustomization.spec.withWait(false)
      //     + flux.kustomize.v1.kustomization.spec.withForce(true)
      //     + flux.kustomize.v1.kustomization.spec.withPrune(true)
      //     + flux.kustomize.v1.kustomization.spec.sourceRef.withName(target.name)
      //     for target in targets
      //   ],
      //
      //   // Generator for webhookTokenPrefix
      //   // ExternalSecret
      //   local webhookSecret = 'webhook-token',
      //
      //   webhookGenerator:
      //     passwordGenerator.new('webhook-generator'),
      //
      //   webhookSecret:
      //     externalSecret.new(webhookSecret)
      //     + externalSecret.spec.withDataFrom(
      //       externalSecret.spec.dataFrom.sourceRef.generatorRef.withApiVersion(self.webhookGenerator.apiVersion)
      //       + externalSecret.spec.dataFrom.sourceRef.generatorRef.withKind(self.webhookGenerator.kind)
      //       + externalSecret.spec.dataFrom.sourceRef.generatorRef.withName(self.webhookGenerator.metadata.name)
      //     ),
      //
      //   changeReciever: [
      //     flux.notification.v1.receiver.new(target.name + '-changes')
      //     + flux.notification.v1.receiver.spec.withType('generic-hmac')
      //     + flux.notification.v1.receiver.spec.secretRef.withName(webhookSecret)
      //     + flux.notification.v1.receiver.spec.withResources(
      //       flux.notification.v1.receiver.spec.resources.withKind('Kustomization')
      //       + flux.notification.v1.receiver.spec.resources.withApiVersion('kustomize.toolkit.fluxcd.io/v1')
      //       + flux.notification.v1.receiver.spec.resources.withName(target.name)
      //       + flux.notification.v1.receiver.spec.resources.withNamespace(namespace)
      //     )
      //     for target in targets
      //   ],
      //
      //   changeProviders: [
      //     flux.notification.v1beta3.provider.new(target.name + '-changes')
      //     + flux.notification.v1beta3.provider.spec.withType('generic-hmac')
      //     + flux.notification.v1beta3.provider.spec.withAddress('http://notification-controller.flux-system.svc.cluster.local')
      //     + flux.notification.v1beta3.provider.spec.secretRef.withName(webhookSecret)
      //     for target in targets
      //   ],
      //
      //   changeAlerts: [
      //     flux.notification.v1beta3.alert.new(target.name + '-changes')
      //     + flux.notification.v1beta3.alert.spec.providerRef.withName(target.name + '-changes')
      //     + flux.notification.v1beta3.alert.spec.withEventSeverity('info')
      //     + flux.notification.v1beta3.alert.spec.withEventSources(
      //       flux.notification.v1beta3.alert.spec.eventSources.withKind('OCIRepository')
      //       + flux.notification.v1beta3.alert.spec.eventSources.withName(target.name)
      //     )
      //     for target in targets
      //   ],
    }, namespace=namespace, patches=[]
  )
)
