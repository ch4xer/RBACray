
import go
import Common::K8sApiType

module ClientGoCR {
  /**
   * CR 的 typed client 包：
   * - 模式1：任意路径/clientset/versioned/typed/组名/版本名
   *   - 例如：antrea.io/antrea/pkg/client/clientset/versioned/typed/crd/v1alpha1
   *           kubevirt.io/client-go/clientset/versioned/typed/core/v1
   * - 模式2：包装客户端包（例如 kubecli）
   *   - 例如：kubevirt.io/client-go/api/kubecli
   */
  class ApiPackage extends Package {
    ApiPackage() {
      this.getPath().regexpMatch(".*/clientset/versioned/typed/\\w+/\\w+$")
      or
      // 包装客户端包：通常包含 "client" 或 "kubecli" 等关键词
      (
        this.getPath().regexpMatch(".*/client.*") or
        this.getPath().regexpMatch(".*/kubecli.*")
      )
    }

    string getApiGroup() {
      if this.getPath().regexpMatch(".*/clientset/versioned/typed/\\w+/\\w+$") then
        result = this.getPath().regexpCapture(".*/clientset/versioned/typed/(\\w+)/\\w+$", 1)
      else
        // 对于包装客户端包，使用包路径的最后一部分作为组名
        result = this.getPath().regexpCapture(".*/([^/]+)$", 1)
    }

    string getApiVersion() {
      if this.getPath().regexpMatch(".*/clientset/versioned/typed/\\w+/\\w+$") then
        result = this.getPath().regexpCapture(".*/clientset/versioned/typed/\\w+/(\\w+)$", 1)
      else
        // 对于包装客户端包，使用 "v1" 作为默认版本
        result = "v1"
    }

    string getShortName() { result = this.getApiGroup() + "/" + this.getApiVersion() }
  }

  /**
   * CR 的 ResourceInterfaceGetter：
   * - 模式1：*Getter（例如 TrafficControlGetter, VirtualMachineInstanceGetter）
   * - 模式2：包装客户端（例如 KubevirtClient），它有返回 ResourceInterface 的方法
   * - 与内置资源的 Getter 结构相同
   */
  class ResourceInterfaceGetter extends Type {
    ApiPackage package;

    ResourceInterfaceGetter() {
      this.getPackage() = package and
      (
        // 标准模式：*Getter
        this.getName().regexpMatch("^\\w+Getter$")
        or
        // 包装客户端模式：例如 KubevirtClient, AntreaClient 等
        // 这些客户端有方法返回 ResourceInterface
        this.getName().regexpMatch(".*Client$")
      )
    }

    ApiPackage getApiPackage() { result = package }

    /**
     * 从 Getter 名称推导资源名：
     * - TrafficControlGetter -> trafficcontrol
     * - VirtualMachineInstanceGetter -> virtualmachineinstance
     * - KubevirtClient -> 需要从方法名推导（例如 VirtualMachineInstance 方法）
     * 
     * 注意：对于包装客户端，资源名需要从方法名推导，这里先返回空字符串
     * 实际的资源名会在 ResourceInterface 中通过方法名推导
     */
    string getResourceName() {
      if this.getName().regexpMatch("^\\w+Getter$") then
        result = this.getName().regexpCapture("^(\\w+)Getter$", 1).toLowerCase()
      else
        result = ""  // 包装客户端的情况，资源名从方法名推导
    }
  }

  /**
   * CR 的 ResourceInterface：
   * - 从 ResourceInterfaceGetter 的方法返回值中提取
   * - 例如：TrafficControlGetter.TrafficControls() -> TrafficControlInterface
   * - 或者：KubevirtClient.VirtualMachineInstance() -> VirtualMachineInstanceInterface
   */
  class ResourceInterface extends Type {
    ResourceInterfaceGetter getter;

    ResourceInterface() {
      exists(Method m |
        m.getReceiverType() = getter and
        this = m.getResultType(0) and
        // 方法名通常是资源名（单数或复数），例如 VirtualMachineInstance, TrafficControls
        m.getName().regexpMatch("^[A-Z]\\w+$")
      )
    }

    /**
     * 从接口名或 getter 方法名推导资源名：
     * - 如果 getter 是标准 *Getter，使用 getter 的资源名
     * - 如果是包装客户端，从接口名推导（例如 VirtualMachineInstanceInterface -> virtualmachineinstance）
     */
    string getResourceName() {
      // 先尝试从 getter 获取资源名（标准 *Getter 模式）
      exists(string getterResName |
        getterResName = getter.getResourceName() and
        getterResName != "" and
        result = getterResName
      )
      or
      // 如果 getter 没有资源名（包装客户端模式），从接口名推导
      (
        // 从接口名推导：VirtualMachineInstanceInterface -> virtualmachineinstance
        // 去掉 "Interface" 后缀，然后转小写
        this.getName().regexpMatch("^(\\w+)Interface$") and
        result = this.getName().regexpCapture("^(\\w+)Interface$", 1).toLowerCase()
      )
      or
      // 如果没有 Interface 后缀，直接转小写
      (
        not this.getName().regexpMatch(".*Interface$") and
        result = this.getName().toLowerCase()
      )
    }

    string getPkgVersionName() {
      result = getter.getApiPackage().getShortName() + "." + this.getName()
    }
  }

  /**
   * CR 的 ResourceMethod：
   * - 识别 ResourceInterface 上的标准 K8s API 方法
   * - Create, Update, Delete, DeleteCollection, Get, List, Watch, Patch, Apply
   */
  class ResourceMethod extends Method {
    ResourceInterface resource;

    ResourceMethod() {
      this.getReceiverType() = resource and
      this.getName().regexpMatch("^(Create|Update|Delete|DeleteCollection|Get|List|Watch|Patch|Apply)$")
    }

    ResourceInterface getResourceInterface() { result = resource }

    string getResourceName() {
      result = resource.getResourceName()
    }

    string getVerbName() { result = methodToVerb(this.getName()) }

    bindingset[method]
    private string methodToVerb(string method) {
      method = "Create" and result = "create"
      or
      method = "Update" and result = "update"
      or
      method = "Delete" and result = "delete"
      or
      method = "DeleteCollection" and result = "deletecollection"
      or
      method = "Get" and result = "get"
      or
      method = "List" and result = "list"
      or
      method = "Watch" and result = "watch"
      or
      method = "Patch" and result = "patch"
      or
      method = "Apply" and result = "patch"
    }

    override string toString() {
      result = "<CR::" + resource.getPkgVersionName() + "." + this.getName() + ">"
    }
  }

  /**
   * CR 的 API 调用：
   * - 识别对 ResourceMethod 的调用
   */
  class ApiCall extends CallExpr {
    ResourceMethod method;

    ApiCall() { this.getTarget() = method }

    ResourceMethod getResourceMethod() { result = method }

    string getVerbName() { result = method.getVerbName() }

    string getResourceName() { result = method.getResourceName() }

    override string toString() { result = "Call CR::" + method.toString() }
  }
}
