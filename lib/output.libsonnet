{
  local toArray = function(o) (
    if std.isObject(o) && std.objectHas(o, 'kind') then
      [o]
    else if std.isObject(o) then
      std.flatMap(toArray, std.objectValues(o))
    else if std.isArray(o) then
      o
    else
      error 'unexpected type ' + std.type(o) + ' expecting object or array'
  ),

  local isNotNull = function(o) (
    o != null && o != {}
  ),

  local getName = function(o) (
    local metadata = std.get(o, 'metadata', default={});
    std.strReplace(std.join(
      '-',
      std.prune([
        std.get(o, 'apiVersion', default=null),
        std.get(o, 'kind', default=null),
        std.get(metadata, 'namespace', default=null),
        std.get(metadata, 'name', default=null),
      ]),
    ), '/', '-') + '.yaml'
  ),

  getName:: getName,

  patchNamespace(ns):: function(o) (
    // Exclude non-namespaced resources
    // See kubectl api-resources --namespaced=false
    local nonNamespaced = std.set([
      'Namespace',
      'ComponentStatus',
      'Node',
      'PersistentVolume',
      'MutatingWebhookConfiguration',
      'ValidatingWebhookConfiguration',
      'CustomResourceDefinition',
      'APIService',
      'TokenReview',
      'SelfSubjectAccessReview',
      'SelfSubjectRulesReview',
      'SubjectAccessReview',
      'ClusterIssuer',
      'CertificateSigningRequest',
      'FlowSchema',
      'PriorityLevelConfiguration',
      'Pomerium',
      'NodeMetrics',
      'IngressClass',
      'NodeFeatureRule',
      'RuntimeClass',
      'ClusterRoleBinding',
      'ClusterRole',
      'PriorityClass',
      'CSIDriver',
      'CSINode',
      'StorageClass',
      'VolumeAttachment',
    ]);
    if o == null || o == {} then
      o
    else if std.objectHas(o, 'kind') && std.setMember(o.kind, nonNamespaced) then
      o
    else if std.objectHas(o, 'metadata') &&
            std.objectHas(o.metadata, 'annotations') && o.metadata.annotations != null &&
            std.get(o.metadata.annotations, 'tanka.dev/namespaced', default='true') == 'false' then
      o
    else
      o {
        metadata+: {
          namespace: ns,
        },
      }
  ),

  applyList: function(patches) (
    function(o) (
      std.foldl(function(patched, patchfn) (
        if patched == null then patched else patchfn(patched)
      ), patches, o)
    )
  ),

  addon:: function(o, namespace=null, patches=[]) (
    $.multi(o, namespace, patches, false)
  ),

  patchStage:: function(o, namespace=null, patches=[]) (
    $.multi(o, namespace, patches, false)
  ),

  renderStage:: function(o) (
    $.multi(o, namespace=null, patches=[], stringified=false)
  ),

  renderDirectory:: function(o) (
    $.multi(o, namespace=null, patches=[], stringified=true)
  ),

  multi:: function(o, namespace=null, patches=[], stringified=true) (
    local objs = std.filter(isNotNull, toArray(o));

    local kustomize = $.applyList(std.prune([
      if namespace != null then $.patchNamespace(namespace) else null,
    ] + patches));

    std.foldl(function(prev, i) (
      if i == null || i == {} then
        prev
      else (
        local name = getName(i);
        if std.objectHas(prev, name) then
          error 'Duplicate file ' + name
        else
          prev { [getName(i)]: if stringified then std.manifestJson(i) else i }
      )
    ), std.map(kustomize, objs), {})
  ),
}
