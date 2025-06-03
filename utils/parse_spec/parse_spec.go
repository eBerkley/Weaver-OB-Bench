package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path"
	"regexp"
	"strings"
	"unicode"

	"slices"

	yaml "gopkg.in/yaml.v2"
)

const DELIMITER = "_"

var spec = flag.String("scheme", "", "the name of the fusion scheme.")
var from = flag.Bool("fromYaml", true, "true if we are going from yaml file to formatted string. false if vice versa.")

type Group struct {
	Name       string
	Components []string
}

type YamlSpec struct {
	Groups []Group
}

// how many TABS do we add?
func addIndent(b []byte, i int) []byte {
	prefix1 := append(bytes.Repeat([]byte("  "), i), []byte("- ")...)
	prefix2 := append([]byte("\n  "), bytes.Repeat([]byte("  "), i)...)
	b = append(prefix1, b...)
	return bytes.ReplaceAll(b, []byte("\n"), prefix2)
}

func (g *Group) GetTags() string {
	s := fmt.Sprintf("\n<%s_RESOURCE_SPEC>\n", g.Name)
	s += fmt.Sprintf("<%s_SCALING_SPEC>\n", g.Name)
	if slices.Contains(g.Components, "github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService") {
		s += fmt.Sprintf("<%s_STATEFUL_SPEC>\n", g.Name)
	}
	return s + "\n"
}

func makeGroup(s string) *Group {
	shorts := SplitFunc(s, unicode.IsUpper)
	g := &Group{
		Name:       s,
		Components: make([]string, len(shorts)),
	}

	for i, s := range shorts {
		g.Components[i] = ReverseSetter[s]
	}

	return g
}

func Must[T any](t T, err error) T {
	if err != nil {
		panic(err)
	}
	return t
}

func (g *Group) GetText() []byte {
	b := Must(yaml.Marshal(g))
	return append(addIndent(b, 1), g.GetTags()...)
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

var ReverseSetter = make(map[string]string)

func toYaml() {
	strs := strings.Split(*spec, ",")
	if len(strs) < 2 {
		strs = strings.Split(*spec, DELIMITER)
	}
	gs := make([]*Group, len(strs))
	for i, s := range strs {
		gs[i] = makeGroup(s)
	}
	fmt.Println("groups:")
	for _, g := range gs {
		fmt.Print(string(g.GetText()))
	}
}

func fromYaml() {
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
	s := ""
	for _, g := range groups.Groups {
		// fmt.Print("")
		for _, c := range g.Components {
			s += fmt.Sprintf("%v", Setter[c])
		}
		s += DELIMITER
	}

	fmt.Println(s[0:len(s)-1] + " }")
}

func main() {
	flag.Parse()

	for k, v := range Setter {
		ReverseSetter[v] = k
	}

	if *spec == "" {
		fmt.Fprintf(os.Stderr, "usage parse_spec --scheme=<name>.\n")
		os.Exit(1)
	}

	if *from {
		fromYaml()
	} else {
		toYaml()
	}

}
