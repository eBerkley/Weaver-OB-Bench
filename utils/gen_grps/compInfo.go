package main

import (
	"fmt"
)

type CompInfo struct {
	Name     Component
	Children CompSet
	Parents  CompSet
}

func (i CompInfo) AddParent(p Component)  { i.Parents.Add(p) }
func (i CompInfo) AddChild(c Component)   { i.Children.Add(c) }
func (i CompInfo) AddChildren(cs CompSet) { i.Children.IUnion(cs) }

func (i CompInfo) String() string {
	return fmt.Sprintf("{%v} -> %v -> {%v}", i.Parents, ComponentMap[i.Name], i.Children)
}

type Topology map[Component]CompSet

func MakeTopology(p Params) Topology {
	t := make(Topology)
	for p, cs := range p.Top {
		cset := NewCompSet()

		for _, c := range cs {
			cset.Add(MapComponent[c])
		}
		t[MapComponent[p]] = cset
	}

	return t
}

func (t Topology) Get(c Component) CompSet {
	cs, ok := t[c]
	if !ok {
		cs = NewCompSet()
	} else {
		cs = cs.Copy()
	}

	return cs
}

type ExtendedTopology struct {
	Info       map[Component]CompInfo
	Root       Component
	Components CompSet
}

// NEEDS COPY IF MODIFYING!
func (ext *ExtendedTopology) ChildrenOf(c Component) CompSet {
	return ext.Info[c].Children
}

// NEEDS COPY IF MODIFYING!
func (ext *ExtendedTopology) ParentsOf(c Component) CompSet {
	return ext.Info[c].Parents
}

func MakeExtended(p Params) *ExtendedTopology {
	ext := &ExtendedTopology{
		Info:       make(map[Component]CompInfo),
		Components: NewCompSet(),
	}

	for _, cStr := range p.Clist {
		c := MapComponent[cStr]
		if _, ok := ext.Info[c]; !ok {
			ext.Info[c] = CompInfo{Name: c, Children: NewCompSet(), Parents: NewCompSet()}
		}
		ext.Components.Add(c)
	}

	for kStr, vStr := range p.Top {

		k := MapComponent[kStr]
		v := NewCompSet()
		for _, c := range vStr {
			v.Add(MapComponent[c])
		}

		ext.Info[k].AddChildren(v)

		for c := range v.All() {
			ext.Info[c].AddParent(k)
		}
	}

	for k, v := range ext.Info {
		if v.Parents.Len() == 0 {
			ext.Root = k
			return ext
		}
	}

	return ext

}

func GetExtended(t Topology) *ExtendedTopology {
	ext := &ExtendedTopology{
		Info:       make(map[Component]CompInfo),
		Components: NewCompSet(),
	}
	for k, v := range t {
		if _, ok := ext.Info[k]; !ok {
			ext.Info[k] = CompInfo{Name: k, Children: v, Parents: NewCompSet()} // No copy is ok
		} else {
			ext.Info[k].AddChildren(v)
		}
		ext.Components.Add(k)
		for c := range v.All() {
			ext.Components.Add(c)
			if _, ok := ext.Info[c]; !ok {
				ext.Info[c] = CompInfo{Name: c, Children: NewCompSet(), Parents: NewCompSet()}
			}
			ext.Info[c].AddParent(k)
		}
	}

	for k, v := range ext.Info {
		if v.Parents.Len() == 0 {
			ext.Root = k
			return ext
		}
	}

	panic("could not find root component")
	// return ext

}
