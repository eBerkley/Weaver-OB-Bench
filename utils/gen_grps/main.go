package main

import (
	"fmt"
	"os"
)

type Params struct {
	Clist []string
	Top   map[string][]string
}

var OBStateless = Params{
	Clist: []string{"M", "Ch", "R", "S", "A", "Cu", "Ca", "E", "Pa", "Pr"},
	Top: map[string][]string{
		"M":  {"R", "S", "Ch", "A", "Cu", "Ca", "Pr"},
		"Ch": {"R", "Ca", "S", "E", "Pa", "Cu", "Pr"},
		"R":  {"Pr"},
		// "Ca": {"Cc"},
	},
}

func main() {
	t := OBStateless
	for _, c := range t.Clist {
		RegisterComponent(c)
	}

	SetExtended(MakeExtended(t))
	g := GroupGen()
	fmt.Fprintf(os.Stdout, "%v\n", g.Print(-1))
}
