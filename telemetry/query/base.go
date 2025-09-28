package query

const (
	PROM_ADDR       = "http://prometheus:80"
	PROM_BASE_QUERY = PROM_ADDR + "/api/v1/query?query="

	RATE_WINDOW = "30s"

	ERR_STRING = "ERRNODATA"
)

type BaseResp[T any] struct {
	Status string `json:"status"`
	Data   struct {
		ResultType string `json:"resultType"`
		Result     []struct {
			Metric T `json:"metric"`
		} `json:"result"`
	} `json:"data"`
}

type KeyVal[T any] struct {
	Metric T     `json:"metric"`
	Value  []any `json:"value"`
}

func (kv KeyVal[T]) GetValue() string {
	return kv.Value[1].(string)
}

type BaseKeyValResp[T any] struct {
	Status string `json:"status"`
	Data   struct {
		ResultType string      `json:"resultType"`
		Result     []KeyVal[T] `json:"result"`
	} `json:"data"`
}

type ValResp struct {
	Status string `json:"status"`
	Data   struct {
		Result []struct {
			Value []any `json:"value"`
		} `json:"Result"`
	} `json:"data"`
}

func (vr *ValResp) GetValue() string {
	if len(vr.Data.Result) == 0 {
		return ERR_STRING
	}
	return vr.Data.Result[0].Value[1].(string)
}
