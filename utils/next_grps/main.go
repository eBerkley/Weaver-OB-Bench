package main

import (
	"flag"
	"fmt"
	"os"
	"slices"
	"strings"
	"unicode"
)

const grpFile = "../../grpFile.txt"

var curGroup = flag.String("grp", "", "what group do you want the next groups of?")
var prevMode = flag.Bool("prev", false, "if set, return the previous group instead of the next groups.")
var allMode = flag.Bool("all", false, "if set, return all groups descendants/anscentors from this group.")
var rComponent = flag.String("rm", "", "if set, gets curGroup with the value removed.")
var fullMode = flag.Bool("full", false, "if set, get every fusion group that can be derived from grp fusing components to it.")

func getPrev(allGrps []string, grp string) string {

	i := slices.IndexFunc(allGrps, func(g string) bool { return strings.Contains(g, grp) })
	if i == -1 {
		fmt.Fprintf(os.Stderr, "Error: %v not in %v\n", grp, grpFile)
		os.Exit(3)
	}

	d1 := strings.Count(allGrps[i], "  ")

	for j := i - 1; j >= 0; j-- {
		d2 := strings.Count(allGrps[j], "  ")
		if d1-1 == d2 {
			s := strings.Trim(allGrps[j], " ")
			return s
		}
	}

	return ""
}

func getNext(allGrps []string, grp string) []string {
	ret := make([]string, 0)

	i := slices.IndexFunc(allGrps, func(g string) bool { return strings.Contains(g, grp) })
	if i == -1 {
		fmt.Fprintf(os.Stderr, "Error: %v not in %v\n", grp, grpFile)
		os.Exit(3)
	}

	d1 := strings.Count(allGrps[i], "  ")

	for j := i + 1; j < len(allGrps); j++ {
		d2 := strings.Count(allGrps[j], "  ")
		if d1 == d2 {
			break
		}
		if d1+1 == d2 {
			s := strings.Trim(allGrps[j], " ")
			ret = append(ret, s)
		}
	}

	return ret
}

func SplitFunc(s string, f func(rune) bool) []string {
	spans := make([]int, 0, 32)

	for i, rune := range s {
		if f(rune) {
			spans = append(spans, i)
		}
	}

	// Create strings from recorded field indices.
	a := make([]string, 0)
	prev := 0
	for _, span := range spans[1:] {
		a = append(a, s[prev:span])
		prev = span
	}
	a = append(a, s[prev:])

	return a
}

type grp_t []string

func (g grp_t) removed(c string) grp_t {
	ret := make(grp_t, 0)
	for _, v := range g {
		if v != c {
			ret = append(ret, v)
		}
	}
	return ret
}

func (g grp_t) String() string {
	return strings.Join(g, "")
}

func (g grp_t) canDerive(g2 grp_t) bool {
	if g[0] != g2[0] {
		return false
	}
	for _, c := range g {
		found := slices.Contains(g2, c)
		if !found {
			return false
		}
	}
	return true
}

func makeGroup(s string) grp_t {
	return SplitFunc(s, unicode.IsUpper)
}

func getFull(allGrps []string, group string) []string {
	grp := strings.Split(group, "_")[0]

	ret := make([]string, 0)
	gcs := makeGroup(grp)

	for _, next := range allGrps {
		nxt := strings.Trim(next, " ")
		n := strings.Split(nxt, "_")[0]
		if n == grp || n == "" {
			continue
		}
		ncs := makeGroup(n)

		if gcs.canDerive(ncs) {
			ret = append(ret, nxt)
		}
	}

	return ret
}

func main() {
	flag.Parse()
	if *curGroup == "" {
		flag.CommandLine.Usage()
		os.Exit(1)
	}

	b, err := os.ReadFile(grpFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(2)
	}

	allGrps := strings.Split(string(b), "\n")

	if *rComponent != "" {

		fmt.Print(makeGroup(strings.Split(*curGroup, "_")[0]).removed(*rComponent).String())
		os.Exit(0)
	}

	if *fullMode {
		ret := getFull(allGrps, *curGroup)
		for i := range ret {
			fmt.Println(ret[i])
		}
		os.Exit(0)
	}

	if *prevMode {
		ret := make([]string, 0)
		c := getPrev(allGrps, *curGroup)

		if *allMode {
			for c != "" {
				ret = append(ret, c)
				c = getPrev(allGrps, c)
			}
		}

		for i := range ret {
			fmt.Println(ret[i])
		}
	} else {

		ret := make([]string, 0)

		cs := getNext(allGrps, *curGroup)
		ret = append(ret, cs...)

		if *allMode {
			for len(cs) > 0 {
				var next []string

				for _, c := range cs {

					next = append(next, getNext(allGrps, c)...)
				}
				cs = next
				ret = append(ret, cs...)
			}
		}

		for i := range ret {
			fmt.Println(ret[i])
		}
	}
}
