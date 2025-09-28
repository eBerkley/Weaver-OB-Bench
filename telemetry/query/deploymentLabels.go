package query

import "net/url"

var (
	QUERY_DEPLOYMENT_LABELS = PROM_BASE_QUERY + url.QueryEscape(
		"kube_deployment_labels{label_serviceweaver_app=\"sw\"}")
)

type DeploymentLabelsResult struct {
	Deployment string `json:"deployment"`
	Group      string `json:"label_serviceweaver_group"`
}

// Get using [QUERY_DEPLOYMENT_LABELS]
type DeploymentLabels BaseResp[DeploymentLabelsResult]

func (dl *DeploymentLabels) GetDeployments() map[string]string {
	depMap := make(map[string]string)
	for _, m := range dl.Data.Result {
		met := m.Metric
		depMap[met.Group] = met.Deployment
	}

	return depMap
}
