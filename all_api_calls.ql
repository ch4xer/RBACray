import go
import analyse.RefGraph
import analyse.Function
import k8sapi.General

predicate edges(RefGraph::PathNode pred, RefGraph::PathNode succ) {
    RefGraph::edges(pred, succ)
}

from
    string resourceName
where
    exists(K8sApiCall apiCall | resourceName = apiCall.getResourceName())
select
    resourceName,
    concat(string verb |
        exists(K8sApiCall apiCall |
            apiCall.getResourceName() = resourceName
            and verb = apiCall.getVerbName()) |
        verb, ", ")
