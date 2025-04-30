package main

import (
	"flag"
	"fmt"
	"os"
	"path"
	"regexp"

	yaml "gopkg.in/yaml.v2"
)

var spec = flag.String("scheme", "", "the name of the fusion scheme.")

type YamlSpec struct {
	Groups []struct {
		Name       string
		Components []string
	}
}

var Setter = map[string]string{
	"github.com/eBerkley/Weaver-OB-Bench/adservice/AdService":                         "A",
	"github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService":                     "Ca",
	"github.com/eBerkley/Weaver-OB-Bench/cartservice/cartCache":                       "Cc",
	"github.com/eBerkley/Weaver-OB-Bench/checkoutservice/CheckoutService":             "Ch",
	"github.com/eBerkley/Weaver-OB-Bench/currencyservice/CurrencyService":             "Cu",
	"github.com/eBerkley/Weaver-OB-Bench/emailservice/EmailService":                   "E",
	"github.com/eberkley/weaver/Main":                                                 "M",
	"github.com/eBerkley/Weaver-OB-Bench/paymentservice/PaymentService":               "Pa",
	"github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService": "Pr",
	"github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService":            "R",
	"github.com/eBerkley/Weaver-OB-Bench/shippingservice/ShippingService":             "S",
}

func main() {
	flag.Parse()

	if *spec == "" {
		fmt.Fprintf(os.Stderr, "usage parse_spec --scheme=<name>.\n")
		os.Exit(1)
	}
	dir, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Getwd: %s\n", err)
		os.Exit(2)
	}
	spec_file := path.Join(dir, "..", "..", "release", "base", "colocation", *spec, "spec.yaml")
	b, err := os.ReadFile(spec_file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: os.ReadFile(%s): %s\n", spec_file, err)
		os.Exit(3)
	}

	sb := string(b)
	reg := regexp.MustCompile(`\<[a-zA-Z_\-]+\>`)

	sb2 := reg.ReplaceAllLiteralString(sb, "")

	var groups YamlSpec
	err = yaml.Unmarshal([]byte(sb2), &groups)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: yaml.Unmarshal(%s): %s\n", sb2, err)
	}

	fmt.Printf("%s: { ", *spec)

	for _, g := range groups.Groups {
		fmt.Print("{ ")
		for _, c := range g.Components {
			fmt.Printf("%v ", Setter[c])
		}
		fmt.Print("} ")
	}
	fmt.Println("}")

	// fmt.Printf("%+v\n", groups)
}
