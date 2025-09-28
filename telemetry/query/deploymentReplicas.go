package query

import (
	"fmt"
	"net/url"
	"strconv"
)

var (
	QUERY_DEPLOYMENT_REPLICAS = PROM_BASE_QUERY + url.QueryEscape(
		"kube_deployment_status_replicas_ready * on (deployment) kube_deployment_labels{label_serviceweaver_app=\"sw\"}")
)

type DeploymentReplicasResult struct {
	Deployment string `json:"deployment"`
}

type DeploymentReplicas BaseKeyValResp[DeploymentReplicasResult]

func (dr *DeploymentReplicas) GetReplicas() map[string]int {
	repMap := make(map[string]int)
	for _, m := range dr.Data.Result {
		dep := m.Metric.Deployment
		rep, err := strconv.Atoi(m.GetValue())
		if err != nil {
			fmt.Printf("Warning! GetReplicas(%v) returned non-int value %v", dep, m.GetValue())
			rep = -1
		}

		repMap[dep] = rep
	}

	return repMap
}
