package main

import "fmt"

const DELIMITER = "_"

type GenGrp struct {
	Group CompSet
	Next  []GenGrp
}

func (g GenGrp) Print(depth int) string {
	ret := ""
	for range depth {
		ret += "  "
	}
	if g.Group.Len() != 1 {
		s := g.Group.String()
		baseline := false
		if len(s) == 0 {
			baseline = true
		}
		for c := range extended.Components.All() {
			if !g.Group.Contains(c) {
				s += fmt.Sprintf("%v%v", DELIMITER, c)
			}
		}
		if baseline {
			s = s[len(DELIMITER):]
		}
		ret += s + "\n"
	}
	for _, n := range g.Next {
		ret += n.Print(depth + 1)
	}
	return ret
}

func GroupGen() GenGrp {
	assert(extended != nil)
	ret := GenGrp{
		Group: NewCompSet(),
		Next:  make([]GenGrp, 0),
	}

	for c := range extended.Components.All() {

		cpy := extended.Components.Copy()
		cpy.Remove(c)
		g := NewCompSet()
		g.Add(c)

		ret.Next = append(ret.Next, generate(g, cpy))
	}

	return ret
}

func generate(G CompSet, R CompSet) GenGrp {
	ret := GenGrp{
		Group: G, // Ok to not copy
		Next:  make([]GenGrp, 0),
	}

	N := NewCompSet()
	for c := range G.All() {
		N.IUnion(extended.ChildrenOf(c))
	}
	N = N.Intersection(R)
	R_next := R.Copy()

	// fmt.Fprintf(os.Stderr, "G: %v, R: %v, N: %v\n", G, R, N)

	for n := range N.All() {
		R_next.Remove(n)
		G_next := G.Copy()
		G_next.Add(n)
		ret.Next = append(ret.Next, generate(G_next, R_next))
	}
	return ret
}
