package main

import (
	"flag"
	"fmt"
	"os"
	"slices"
	"strings"
)

const grpFile = "../../grpFile.txt"

var curGroup = flag.String("grp", "", "what group do you want the next groups of?")

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
	i := slices.IndexFunc(allGrps, func(g string) bool { return strings.Contains(g, *curGroup) })
	if i == -1 {
		fmt.Fprintf(os.Stderr, "Error: %v not in %v\n", *curGroup, grpFile)
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
			fmt.Println(s)
		}
	}
}
