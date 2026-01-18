import go

module K8sApiType {
  class ApiPackage extends Package {
    ApiPackage() { this.getPath().regexpMatch("^k8s\\.io/api/\\w+/\\w+$") }

    string getApiGroup() { result = this.getPath().regexpCapture("^k8s\\.io/api/(\\w+)/\\w+$", 1) }

    string getApiVersion() {
      result = this.getPath().regexpCapture("^k8s\\.io/api/\\w+/(\\w+)$", 1)
    }

    string getShortName() { result = this.getApiGroup() + "/" + this.getApiVersion() }
  }

  class ResourceType extends NamedType {
    ApiPackage package;

    ResourceType() {
      this.getPackage() = package and
      this.getUnderlyingType().(StructType).hasField("TypeMeta", _)
    }

    ApiPackage getApiPackage() { result = package }

    string getResourceName() {
      result = kindToResourceName(this.getName().regexpCapture("^(\\w*?)(List)?$", 1))
    }

    string getPkgVersionName() { result = package.getShortName() + "." + this.getName() }
  }

  /**
   * 任意“类 K8s 资源”的类型：
   *
   * - 结构体中包含 TypeMeta / ObjectMeta 字段
   * - 不再强制限定在 k8s.io/api/... 包下，从而可以覆盖 CRD 对应的 Go 类型
   *
   * 说明：
   * - 对于内置资源，这个类会与 ResourceType 重叠；此时优先复用 ResourceType 的语义
   * - 对于 CR，其包路径通常为 <domain>/<group>/<version>，只要结构体满足字段约束，也会被识别
   */
  class AnyK8sResourceType extends NamedType {
    AnyK8sResourceType() {
      exists(StructType st |
        st = this.getUnderlyingType() and
        st.hasField("TypeMeta", _) and
        (
          // 要求有 ObjectMeta 或 metadata 字段（大多数 CR 都有）
          st.hasField("ObjectMeta", _) or
          st.hasField("metadata", _) or
          // 或者有 Spec 字段（这也是 CR 的常见特征）
          st.hasField("Spec", _)
        )
      )
    }

    /**
     * 返回该类型的 Kind 名称（去掉 List 后缀）。
     */
    string getKind() {
      result = this.getName().regexpCapture("^(\\w*?)(List)?$", 1)
    }

    /**
     * 推导资源名：
     * - 对于任意 K8s 风格资源（包括 CR），使用 Kind 全小写作为近似资源名。
     */
    string getResourceName() { result = this.getKind().toLowerCase() }

    /**
     * 返回带包信息的类型名：
     * - 使用完整包路径 + 类型名，便于在结果中区分不同资源/CR。
     */
    string getPkgVersionName() { result = this.getPackage().getPath() + "." + this.getName() }
  }

  predicate exprPointsToResource(Expr expr, ResourceType typ) {
    expr.getType().(PointerType).getBaseType() = typ
  }

  /**
   * 更宽松的资源解析：既支持内置资源，也支持 CR 对应的 Go 类型。
   * 支持多种表达式类型：
   * - 指针类型：*VirtualMachineInstance
   * - 直接类型：VirtualMachineInstance（虽然不常见，但可能在某些上下文中出现）
   */
  predicate exprPointsToAnyResource(Expr expr, AnyK8sResourceType typ) {
    (
      expr.getType() instanceof PointerType and
      expr.getType().(PointerType).getBaseType() = typ
    )
    or
    (
      expr.getType() = typ
    )
  }

  predicate exprPointsToResourceConst(Expr const, string typStr) {
    typStr = getResourceConst(const)
  }

  string getResourceConst(Expr expr) {
    if expr instanceof StringLit then
      result = expr.(StringLit).getValue()
    else if expr instanceof StructLit then
      exists(KeyValueExpr kv
        | kv = expr.(StructLit).getAnElement() 
          and kv.getKey().(Ident).getName() = "Resource"
        | result = kv.getValue().(StringLit).getValue())
    else
      none()
  }

  bindingset[name]
  predicate isValideResourceName(string name) {
    name = "bindings" or
    name = "componentstatuses" or
    name = "configmaps" or
    name = "endpoints" or
    name = "events" or
    name = "limitranges" or
    name = "namespaces" or
    name = "nodes" or
    name = "persistentvolumeclaims" or
    name = "persistentvolumes" or
    name = "pods" or
    name = "podtemplates" or
    name = "replicationcontrollers" or
    name = "resourcequotas" or
    name = "secrets" or
    name = "serviceaccounts" or
    name = "services" or
    name = "mutatingwebhookconfigurations" or
    name = "validatingwebhookconfigurations" or
    name = "customresourcedefinitions" or
    name = "apiservices" or
    name = "controllerrevisions" or
    name = "daemonsets" or
    name = "deployments" or
    name = "replicasets" or
    name = "statefulsets" or
    name = "tokenreviews" or
    name = "localsubjectaccessreviews" or
    name = "selfsubjectaccessreviews" or
    name = "selfsubjectrulesreviews" or
    name = "subjectaccessreviews" or
    name = "horizontalpodautoscalers" or
    name = "cronjobs" or
    name = "jobs" or
    name = "certificatesigningrequests" or
    name = "leases" or
    name = "endpointslices" or
    name = "events" or
    name = "flowschemas" or
    name = "prioritylevelconfigurations" or
    name = "helmchartconfigs" or
    name = "helmcharts" or
    name = "addons" or
    name = "ingressclasses" or
    name = "ingresses" or
    name = "networkpolicies" or
    name = "runtimeclasses" or
    name = "poddisruptionbudgets" or
    name = "clusterrolebindings" or
    name = "clusterroles" or
    name = "rolebindings" or
    name = "roles" or
    name = "priorityclasses" or
    name = "csidrivers" or
    name = "csinodes" or
    name = "csistoragecapacities" or
    name = "storageclasses" or
    name = "volumeattachments"
  }

  bindingset[kind]
  private string kindToResourceName(string kind) {
    if kind = "Binding" then result = "bindings"
    else if kind = "ComponentStatus" then result = "componentstatuses"
    else if kind = "ConfigMap" then result = "configmaps"
    else if kind = "Endpoints" then result = "endpoints"
    else if kind = "Event" then result = "events"
    else if kind = "LimitRange" then result = "limitranges"
    else if kind = "Namespace" then result = "namespaces"
    else if kind = "Node" then result = "nodes"
    else if kind = "PersistentVolumeClaim" then result = "persistentvolumeclaims"
    else if kind = "PersistentVolume" then result = "persistentvolumes"
    else if kind = "Pod" then result = "pods"
    else if kind = "PodTemplate" then result = "podtemplates"
    else if kind = "ReplicationController" then result = "replicationcontrollers"
    else if kind = "ResourceQuota" then result = "resourcequotas"
    else if kind = "Secret" then result = "secrets"
    else if kind = "ServiceAccount" then result = "serviceaccounts"
    else if kind = "Service" then result = "services"
    else if kind = "MutatingWebhookConfiguration" then result = "mutatingwebhookconfigurations"
    else if kind = "ValidatingWebhookConfiguration" then result = "validatingwebhookconfigurations"
    else if kind = "CustomResourceDefinition" then result = "customresourcedefinitions"
    else if kind = "APIService" then result = "apiservices"
    else if kind = "ControllerRevision" then result = "controllerrevisions"
    else if kind = "DaemonSet" then result = "daemonsets"
    else if kind = "Deployment" then result = "deployments"
    else if kind = "ReplicaSet" then result = "replicasets"
    else if kind = "StatefulSet" then result = "statefulsets"
    else if kind = "TokenReview" then result = "tokenreviews"
    else if kind = "LocalSubjectAccessReview" then result = "localsubjectaccessreviews"
    else if kind = "SelfSubjectAccessReview" then result = "selfsubjectaccessreviews"
    else if kind = "SelfSubjectRulesReview" then result = "selfsubjectrulesreviews"
    else if kind = "SubjectAccessReview" then result = "subjectaccessreviews"
    else if kind = "HorizontalPodAutoscaler" then result = "horizontalpodautoscalers"
    else if kind = "CronJob" then result = "cronjobs"
    else if kind = "Job" then result = "jobs"
    else if kind = "CertificateSigningRequest" then result = "certificatesigningrequests"
    else if kind = "Lease" then result = "leases"
    else if kind = "EndpointSlice" then result = "endpointslices"
    else if kind = "Event" then result = "events"
    else if kind = "FlowSchema" then result = "flowschemas"
    else if kind = "PriorityLevelConfiguration" then result = "prioritylevelconfigurations"
    else if kind = "HelmChartConfig" then result = "helmchartconfigs"
    else if kind = "HelmChart" then result = "helmcharts"
    else if kind = "Addon" then result = "addons"
    else if kind = "IngressClass" then result = "ingressclasses"
    else if kind = "Ingress" then result = "ingresses"
    else if kind = "NetworkPolicy" then result = "networkpolicies"
    else if kind = "RuntimeClass" then result = "runtimeclasses"
    else if kind = "PodDisruptionBudget" then result = "poddisruptionbudgets"
    else if kind = "ClusterRoleBinding" then result = "clusterrolebindings"
    else if kind = "ClusterRole" then result = "clusterroles"
    else if kind = "RoleBinding" then result = "rolebindings"
    else if kind = "Role" then result = "roles"
    else if kind = "PriorityClass" then result = "priorityclasses"
    else if kind = "CSIDriver" then result = "csidrivers"
    else if kind = "CSINode" then result = "csinodes"
    else if kind = "CSIStorageCapacity" then result = "csistoragecapacities"
    else if kind = "StorageClass" then result = "storageclasses"
    else if kind = "VolumeAttachment" then result = "volumeattachments"
    else result = "unknown"
  }
}
