package set

import (
	"iter"
)

//	type CompSet interface {
//		sort.Interface
//		Copy() Set[Component]
//		Add(Component)
//		Union(CompSet) CompSet
//		IUnion(CompSet)
//		String() string
//		Key() uint64
//		Contains(Component) bool
//		All() iter.Seq[Component]
//		Difference(CompSet) CompSet
//		IsDisjoint(CompSet) bool
//	}
type Key = uint64

type Cmp interface {
	String() string
	Less(Cmp) bool
	Key() Key
}

type CmpSlice[T Cmp] []T

func (s CmpSlice[T]) Len() int           { return len(s) }
func (s CmpSlice[T]) Swap(i, j int)      { s[i], s[j] = s[j], s[i] }
func (s CmpSlice[T]) Less(i, j int) bool { return s[i].Less(s[j]) }

type Set[T Cmp] interface {
	Len() int
	Copy() Set[T] // To be used internally.
	Add(T)
	Union(Set[T]) Set[T]
	Intersection(Set[T]) Set[T]
	IUnion(Set[T])
	Contains(T) bool
	All() iter.Seq[T]
	All2() iter.Seq2[int, T]
	At(index int) T
	Difference(Set[T]) Set[T]
	IsDisjoint(Set[T]) bool
	String() string
	Key() uint64
	Remove(T)
	Less(Cmp) bool // Set implements Cmp
}

var _ Cmp = (Set[Cmp])(nil)

// type Set2[T Cmp] interface {
// 	Set[T]
// 	String() string
// 	Key() uint64
// 	Copy() Set2[T]
// }
