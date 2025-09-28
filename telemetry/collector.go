package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"telCol/jaeger"
	"telCol/query"
	traceclient "telCol/traceClient"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	// "k8s.io/client-go/kubernetes"
	// "k8s.io/client-go/rest"
	// v1 "k8s.io/api/apps/v1"
	// metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	// "k8s.io/apimachinery/pkg/util/wait"
	// "k8s.io/apimachinery/pkg/watch"
	// "k8s.io/client-go/kubernetes"
	// "k8s.io/client-go/rest"
	// "k8s.io/client-go/tools/cache"
	// watch2 "k8s.io/client-go/tools/watch"
)

var (
	SPEC = os.Getenv("SPEC")
)

var (
	JAEGER_ADDR = flag.String("addr", "jaeger-query", "the ip address of the jaeger-query svc. Only needs set if running on bare-metal.")
)

const (
	// JAEGER_ADDR     = "10.43.149.159:16685" // "127.0.0.1:8080"
	PROM_ADDR       = "http://prometheus:80"
	PROM_BASE_QUERY = PROM_ADDR + "/api/v1/query?query="
)

func getDeploymentLabelQuery(groupname string) string {
	return fmt.Sprintf("kube_deployment_labels{label_serviceweaver/group=\"%v\"}", groupname)
}

type Collector struct {
	promClient   *http.Client
	jaegerClient jaeger.QueryServiceClient

	components  map[string]string // abbr -> service weaver canonical name
	revComps    map[string]string // canon -> abbr
	groups      map[string]string // component -> Group it resides in
	deployments map[string]string // group -> kubernetes deployment name

	dump []int

	e2e map[string]float32
	// clientset  *kubernetes.Clientset

}

func NewCollector(abbrFname string, jaegerAddr string) (*Collector, error) {

	jc, err := grpc.NewClient(jaegerAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("grpc.NewClient: %w", err)
	}
	c := &Collector{
		dump:         make([]int, 0),
		promClient:   &http.Client{Timeout: 3 * time.Second},
		jaegerClient: jaeger.NewQueryServiceClient(jc),

		e2e: make(map[string]float32),
	}

	// c.components, _ = GetAbbreviations(abbrFname)
	// if err := c.FillGroups(); err != nil {
	// 	return nil, fmt.Errorf("NewCollector: %w", err)
	// }
	return c, nil
}

func (c *Collector) FillGroups() error {
	var dl query.DeploymentLabels

	if err := c.getJson(query.QUERY_DEPLOYMENT_LABELS, &dl); err != nil {
		return fmt.Errorf("Collector.FillGroups: %w", err)
	}

	c.deployments = dl.GetDeployments()

	return nil
}

func (c *Collector) Collect(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:

			// err := c.GetE2ELat()
			// if err != nil {
			// 	return fmt.Errorf("GetE2ELat: %w", err)
			// }

			// c.Export()
			time.Sleep(10 * time.Second)
		}
	}
}

func (c *Collector) Export() {
	outfile := os.Stdout
	fmt.Fprintf(outfile, "Current time: %v\n", time.Now().Format(time.RFC3339))
	fmt.Fprintf(outfile, "E2E: \n")
	fmt.Fprintf(outfile, "%v\n", query.PrettyPrintE2E(c.e2e))
	fmt.Fprintf(outfile, "\n\n")
}

func (c *Collector) GetE2ELat() error {

	for name, metricQuery := range query.E2E_P99_ALL {
		var vr query.ValResp
		err := c.getJson(metricQuery, &vr)
		if err != nil {
			return fmt.Errorf("getJson(%v): %w", metricQuery, err)
		}
		res := vr.GetValue()
		if res == query.ERR_STRING {
			return fmt.Errorf("getJson(%v) returned %v", metricQuery, query.ERR_STRING)
		}
		f, err := strconv.ParseFloat(res, 32)
		if err != nil {
			return fmt.Errorf("ParseFloat(%v): %w", res, err)
		}
		c.e2e[name] = float32(f)
	}
	return nil
}

func (c *Collector) getJson(url string, target any) error {
	r, err := c.promClient.Get(url)
	if err != nil {
		return err
	}
	defer r.Body.Close()

	return json.NewDecoder(r.Body).Decode(target)
}

func main() {

	flag.Parse()

	c, err := NewCollector("abbrfile.txt", fmt.Sprintf("%s:16685", *JAEGER_ADDR))
	if err != nil {
		fmt.Fprintf(os.Stderr, "NewCollector: %v", err)
		os.Exit(1)
	}
	tracer := traceclient.NewClient(c.jaegerClient)
	if err = tracer.Start(os.Stdout, context.Background()); err != nil {
		fmt.Fprintf(os.Stderr, "tracer.Start: %v", err)
		os.Exit(0)
	}

	// err = c.Collect(context.Background())
	// if err != nil {
	// 	fmt.Fprintf(os.Stderr, "c.Collect: %v", err)
	// 	os.Exit(2)
	// }
	// res, err := http.Get()
	// if err != nil {
	// 	fmt.Printf("%v\n", err)
	// 	os.Exit(1)
	// }
	// var b []byte

	// if _, err := res.Body.Read(b); err != nil {
	// 	fmt.Printf("%v\n", err)
	// 	os.Exit(1)
	// }

	// var dl query.DeploymentLabels
	// json.Unmarshal(b, &dl)
	// fmt.Printf("%+v\n", dl)

}

// func (c *Collector) WatchPods(ctx context.Context) error {
// 	opts := metav1.ListOptions{LabelSelector: "PLACEHOLDER"}
// 	var watcher watch.Interface
// 	var err error
// 	err = wait.ExponentialBackoff(wait.Backoff{
// 		Duration: 1 * time.Second,
// 		Factor:   1.5,
// 		Jitter:   0.2,
// 		Steps:    10, // Maximum retry attempts
// 	}, func() (bool, error) {
// 		watcher, err = watch2.NewRetryWatcher("1", &cache.ListWatch{
// 			WatchFunc: func(options metav1.ListOptions) (watch.Interface, error) {
// 				return c.clientset.AppsV1().Deployments("").Watch(ctx, opts)
// 				// Pods("").Watch(ctx, opts)
// 			},
// 		})
// 		if err != nil {
// 			return false, err // retry to create the watcher
// 		}
// 		return true, nil // watcher created successfully
// 	})
// 	if err != nil {
// 		return err
// 	}

// 	for {
// 		select {
// 		case <-ctx.Done():
// 			watcher.Stop()
// 			return ctx.Err()
// 		case event, ok := <-watcher.ResultChan():
// 			if !ok {
// 				return nil
// 			}
// 			rep := event.Object.(*v1.Deployment).Status.Replicas

// 		}
// 	}
// }

func (c *Collector) QueryMps() {
	// for c, p := range c.components {

	// 	if c == "M" {

	// 	}
	// }
}
