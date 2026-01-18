import go

module ControllerRuntime {
  import Common::K8sApiType

  class ClientApi extends Function {
    ClientApi() {
      this.hasQualifiedName("sigs.k8s.io/controller-runtime/pkg/client.Client",
        ["Get", "List", "Create", "Update", "Delete", "Patch", "DeleteAllOf"])
        or
      this.hasQualifiedName("sigs.k8s.io/controller-runtime/pkg/client.WithWatch", "Watch")
        or
      this.hasQualifiedName("sigs.k8s.io/controller-runtime/pkg/controller/controllerutil",
        ["CreateOrPatch", "CreateOrUpdate"])
    }

    int getResourceArgIndex() { result = methodToArgIndex(this.getName()) }

    string getVerbName() { result = methodToVerb(this.getName()) }

    bindingset[method]
    private string methodToVerb(string method) {
      method = "Get" and result = "get"
      or
      method = "List" and result = "list"
      or
      method = "Create" and result = "create"
      or
      method = "Update" and result = "update"
      or
      method = "Delete" and result = "delete"
      or
      method = "Patch" and result = "patch"
      or
      method = "DeleteAllOf" and result = "deletecollection"
      or
      method = "Watch" and result = "watch"
      or
      method = "CreateOrPatch" and result = "create"
      or
      method = "CreateOrPatch" and result = "patch"
      or
      method = "CreateOrUpdate" and result = "create"
      or
      method = "CreateOrUpdate" and result = "update"
    }

    bindingset[method]
    private int methodToArgIndex(string method) {
      method = "Get" and result = 2
      or
      method = "List" and result = 1
      or
      method = "Create" and result = 1
      or
      method = "Update" and result = 1
      or
      method = "Delete" and result = 1
      or
      method = "Patch" and result = 1
      or
      method = "DeleteAllOf" and result = 1
      or
      method = "Watch" and result = 1
      or
      method = "CreateOrPatch" and result = 2
      or
      method = "CreateOrUpdate" and result = 2
    }
  }

  class CandidateApiCall extends CallExpr {
    ClientApi method;

    CandidateApiCall() { this.getTarget() = method }

    string getVerbName() { result = method.getVerbName() }

    string getTypeHint() {
      result = this.getResourceArg().getType().getPackage().toString() + " @ " + this.getResourceArg().getType().pp()
    }

    Expr getResourceArg() { result = this.getArgument(method.getResourceArgIndex()) }
  }

  class ApiCall extends CandidateApiCall {
    AnyK8sResourceType resource;

    /**
     * 使用更宽松的资源解析逻辑：
     * - 内置资源：仍然映射到 Common::ResourceType
     * - CR：只要参数类型是带 TypeMeta/ObjectMeta 的 struct 指针，也会被识别为 AnyK8sResourceType
     */
    ApiCall() { exprPointsToAnyResource(this.getResourceArg(), resource) }

    string getResourceName() { result = resource.getResourceName() }

    /**
     * 判断是否是 CustomResource 调用：
     * - 如果资源类型的包路径不在 k8s.io/api 下，就是 CR
     */
    predicate isCustomResource() {
      not resource.getPackage().getPath().regexpMatch("^k8s\\.io/api/.*")
    }

    override string toString() {
      result = "Call <" + resource.getPkgVersionName() + "." + method.getName() + ">"
    }
  }
}
