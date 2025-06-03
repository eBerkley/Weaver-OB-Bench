package main

import (
	"fusr/set"
)

type Component int

var ComponentMap = make(map[Component]string)
var MapComponent = make(map[string]Component)

var _cCount Component = 1

func (c Component) String() string      { return ComponentMap[c] }
func (c Component) Less(x set.Cmp) bool { return c.Key() < x.Key() }
func (c Component) Key() Key            { return Key(c) }

var _ set.Cmp = (*Component)(nil)

func RegisterComponent(s string) {
	ComponentMap[_cCount] = s
	MapComponent[s] = _cCount
	_cCount++
}

var extended *ExtendedTopology

func SetExtended(ext *ExtendedTopology) { extended = ext }

/// CompSet

type CompSet = set.Set[Component]

func NewCompSet() CompSet {
	return set.NewSet[Component]()
}
