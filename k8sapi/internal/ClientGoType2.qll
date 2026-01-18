import go

module ClientGoType2 {
  import Common::K8sApiType

  class ApiFunction extends Function {
    ApiFunction() {
      this.hasQualifiedName("k8s.io/client-go/tools/cache",
        [
          "NewIndexerInformer", "NewReflector", "NewSharedIndexInformer",
          "NewSharedIndexInformerWithOptions", "NewSharedInformer"
        ])
    }

    int getResourceArgIndex() { result = methodToArgIndex(this.getName()) }

    string getVerbName() { result = methodToVerb(this.getName()) }

    bindingset[method]
    private string methodToVerb(string method) {
      method = "NewIndexerInformer" and result = "list"
      or
      method = "NewIndexerInformer" and result = "watch"
      or
      method = "NewReflector" and result = "list"
      or
      method = "NewReflector" and result = "watch"
      or
      method = "NewSharedIndexInformer" and result = "list"
      or
      method = "NewSharedIndexInformer" and result = "watch"
      or
      method = "NewSharedIndexInformerWithOptions" and result = "list"
      or
      method = "NewSharedIndexInformerWithOptions" and result = "watch"
      or
      method = "NewSharedInformer" and result = "list"
      or
      method = "NewSharedInformer" and result = "watch"
    }

    bindingset[method]
    private int methodToArgIndex(string method) {
      method = "NewIndexerInformer" and result = 1
      or
      method = "NewReflector" and result = 1
      or
      method = "NewSharedIndexInformer" and result = 1
      or
      method = "NewSharedIndexInformerWithOptions" and result = 1
      or
      method = "NewSharedInformer" and result = 1
    }
  }

  class CandidateApiCall extends CallExpr {
    ApiFunction method;

    CandidateApiCall() { this.getTarget() = method }

    string getVerbName() { result = method.getVerbName() }

    string getTypeHint() {
      result =
        this.getResourceArg().getType().getPackage().toString() + " @ " +
          this.getResourceArg().getType().pp()
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

    override string toString() {
      result = "Call <" + resource.getPkgVersionName() + "." + method.getName() + ">"
    }
  }
}
