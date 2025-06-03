package set

import (
	"hash/fnv"
	"iter"
	"slices"
	"sort"
)

type ConcreteSet[T Cmp] struct {
	ls  CmpSlice[T]
	set map[Key]struct{}
}

func NewSet[T Cmp]() Set[T] {
	return &ConcreteSet[T]{
		ls:  make([]T, 0),
		set: make(map[Key]struct{}),
	}
}

func (s *ConcreteSet[T]) Len() int {
	return len(s.ls)
}

func (s *ConcreteSet[T]) Copy() Set[T] {
	ret := &ConcreteSet[T]{ls: make([]T, len(s.ls)), set: make(map[Key]struct{})}
	copy(ret.ls, s.ls)
	for k := range s.All() {
		ret.set[k.Key()] = struct{}{}
	}
	return ret
}

func (s *ConcreteSet[T]) Add(x T) {
	if _, ok := s.set[x.Key()]; ok {
		return
	}

	s.set[x.Key()] = struct{}{}
	s.ls = append(s.ls, x)
	sort.Sort(s.ls)
}

func (s *ConcreteSet[T]) Remove(x T) {
	k := x.Key()
	if _, ok := s.set[k]; !ok {
		return
	}

	i, _ := sort.Find(s.Len(), func(i int) int {
		v := s.ls[i]
		return int(k - v.Key())
	})
	// Remove element by shifting every element after back one.
	// Preserves ordering
	for j := i; j < len(s.ls)-1; j++ {
		s.ls[j] = s.ls[j+1]
	}
	s.ls = s.ls[:len(s.ls)-1]

	delete(s.set, k)
}

func (s *ConcreteSet[T]) At(i int) T {
	return s.ls[i]
}

func (s *ConcreteSet[T]) Union(x Set[T]) Set[T] {
	ret := s.Copy()
	ret.IUnion(x)
	return ret
}

func (s *ConcreteSet[T]) IUnion(x Set[T]) {
	for c := range x.All() {
		s.Add(c)
	}
}

func (s *ConcreteSet[T]) Intersection(x Set[T]) Set[T] {
	ret := NewSet[T]()
	for _, c := range s.ls {
		if x.Contains(c) {
			ret.Add(c)
		}
	}
	return ret
}

func (s *ConcreteSet[T]) Contains(x T) bool {
	_, ok := s.set[x.Key()]
	return ok
}

func (s *ConcreteSet[T]) All() iter.Seq[T] {
	return func(yield func(T) bool) {
		for _, c := range s.ls {
			if !yield(c) {
				return
			}
		}
	}
}

func (s *ConcreteSet[T]) All2() iter.Seq2[int, T] {
	return func(yield func(int, T) bool) {
		for i, c := range s.ls {
			if !yield(i, c) {
				return
			}
		}
	}
}

func (s *ConcreteSet[T]) Difference(x Set[T]) Set[T] {
	ret := NewSet[T]()
	for _, c := range s.ls {
		if !x.Contains(c) {
			ret.Add(c)
		}
	}
	return ret
}

func (s *ConcreteSet[T]) IsDisjoint(x Set[T]) bool {
	return !slices.ContainsFunc(s.ls, x.Contains)
}

func (s *ConcreteSet[T]) String() string {
	str := make([]byte, 0, s.Len())
	for c := range s.All() {
		str = append(str, c.String()...)
	}
	return string(str)
}

func (s *ConcreteSet[T]) Key() uint64 {
	h := fnv.New64a()
	h.Write([]byte(s.String()))
	return h.Sum64()
}

func (s *ConcreteSet[T]) Less(x Cmp) bool { return s.Key() < x.Key() }

type fakeCmp struct{}

func (fakeCmp) Key() Key       { return 0 }
func (fakeCmp) String() string { return "" }
func (fakeCmp) Less(Cmp) bool  { return false }

var _ Cmp = (*fakeCmp)(nil)
var _ Set[fakeCmp] = (*ConcreteSet[fakeCmp])(nil)
