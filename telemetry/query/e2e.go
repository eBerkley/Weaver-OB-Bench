package query

import (
	"fmt"
	"net/url"
	"strings"
)

// Base metric names
const (

	// Frontend - Sync
	E2E_POST_SAVE              = "e2e_post_save_lat_hist"
	E2E_POST_SAVE_IMG_LAT_HIST = "e2e_post_save_img_lat_hist"
	E2E_POST_UPDATE_LAT_HIST   = "e2e_post_update_lat_hist"
	E2E_IMG_LAT_HIST           = "e2e_img_lat_hist"
	E2E_READ_TL_LAT_HIST       = "e2e_read_tl_lat_hist"

	// Recommend - Sync
	E2E_RECMD_REQ_LAT_HIST = "e2e_recmd_req_lat_hist"

	// Object Detect - Async
	E2E_OBJECT_DETECT_LAT_HIST = "e2e_object_detect_lat_hist"

	// Sentiment Analysis - Async
	E2E_SENTIMENT_LAT_HIST     = "e2e_sentiment_lat_hist"
	E2E_SENTIMENT_IMG_LAT_HIST = "e2e_sentiment_img_lat_hist"

	// Timeline Update - Async
	E2E_TL_UPDATE_LAT_HIST     = "e2e_tl_update_lat_hist"
	E2E_TL_UPDATE_IMG_LAT_HIST = "e2e_tl_update_img_lat_hist"
)

func getE2EQuery(qname string, percentile string) string {
	return PROM_BASE_QUERY + url.QueryEscape(
		fmt.Sprintf("histogram_quantile(%s, sum(rate(%s_bucket[30s])) by (le))", percentile, qname),
	)
}

var (
	// Frontend - Sync
	E2E_P99_POST_SAVE              = getE2EQuery(E2E_POST_SAVE, "0.99")
	E2E_P99_POST_SAVE_IMG_LAT_HIST = getE2EQuery(E2E_POST_SAVE_IMG_LAT_HIST, "0.99")
	E2E_P99_POST_UPDATE_LAT_HIST   = getE2EQuery(E2E_POST_UPDATE_LAT_HIST, "0.99")
	E2E_P99_IMG_LAT_HIST           = getE2EQuery(E2E_IMG_LAT_HIST, "0.99")
	E2E_P99_READ_TL_LAT_HIST       = getE2EQuery(E2E_READ_TL_LAT_HIST, "0.99")

	// Recommend - Sync
	E2E_P99_RECMD_REQ_LAT_HIST = getE2EQuery(E2E_RECMD_REQ_LAT_HIST, "0.99")

	// Object Detect - Async
	E2E_P99_OBJECT_DETECT_LAT_HIST = getE2EQuery(E2E_OBJECT_DETECT_LAT_HIST, "0.99")

	// Sentiment Analysis - Async
	E2E_P99_SENTIMENT_LAT_HIST     = getE2EQuery(E2E_SENTIMENT_LAT_HIST, "0.99")
	E2E_P99_SENTIMENT_IMG_LAT_HIST = getE2EQuery(E2E_SENTIMENT_IMG_LAT_HIST, "0.99")

	// Timeline Update - Async
	E2E_P99_TL_UPDATE_LAT_HIST     = getE2EQuery(E2E_TL_UPDATE_LAT_HIST, "0.99")
	E2E_P99_TL_UPDATE_IMG_LAT_HIST = getE2EQuery(E2E_TL_UPDATE_IMG_LAT_HIST, "0.99")
)

// To iterate over
var (
	E2E_P99_ALL = map[string]string{
		"Save":                        E2E_P99_POST_SAVE,
		"Save w/ Image":               E2E_P99_POST_SAVE_IMG_LAT_HIST,
		"Update":                      E2E_P99_POST_UPDATE_LAT_HIST,
		"Image":                       E2E_P99_IMG_LAT_HIST,
		"Read TL":                     E2E_P99_READ_TL_LAT_HIST,
		"Recommend":                   E2E_P99_RECMD_REQ_LAT_HIST,
		"Object Detect":               E2E_P99_OBJECT_DETECT_LAT_HIST,
		"Sentiment Analysis":          E2E_P99_SENTIMENT_LAT_HIST,
		"Sentiment Analysis w/ Image": E2E_P99_SENTIMENT_IMG_LAT_HIST,
		"Timeline Update":             E2E_P99_TL_UPDATE_LAT_HIST,
		"Timeline Update w/ Image":    E2E_P99_TL_UPDATE_IMG_LAT_HIST,
	}
)

var (
	_E2E_P99_ALL_KEYS = []string{
		"Save",
		"Save w/ Image",
		"Update",
		"Image",
		"Read TL",
		"Recommend",
		"Object Detect",
		"Sentiment Analysis",
		"Sentiment Analysis w/ Image",
		"Timeline Update",
		"Timeline Update w/ Image",
	}

	_max_len = len("Sentiment Analysis w/ Image")
)

func PrettyPrintE2E(in map[string]float32) string {
	out := ""
	for _, key := range _E2E_P99_ALL_KEYS {
		out += fmt.Sprintf("%s:%s %06.2f\n", key, strings.Repeat(" ", _max_len-len(key)), in[key])
	}
	return out

}
