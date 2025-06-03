package main

import (
	"gonum.org/v1/gonum/stat/combin"
)

type Key = uint64

func TODO() { panic("unimplemented") }

func assert(b bool) {
	if !b {
		panic("Assertion Failed")
	}
}

// mean, min, max
func stats(arr []int) (int, int, int) {
	const defaultSmall = 99999999999999999
	sum := 0
	small := defaultSmall
	large := 0
	total := 0

	for _, x := range arr {
		if x == 0 {
			continue
		}
		small = min(small, x)
		large = max(large, x)
		sum += x
		total++
	}
	if small == defaultSmall {
		return 0, 0, 0
	}
	return sum / total, small, large
}

func combinations(idxs []int) [][]int {
	ret := make([][]int, 0)
	for l1 := 1; l1 < len(idxs)+1; l1++ {
		tmp := combin.Combinations(len(idxs), l1)
		tmp2 := make([][]int, len(tmp))
		for i, v := range tmp {
			tmp2[i] = make([]int, len(v))
			for ii, j := range v {
				tmp2[i][ii] = idxs[j]
			}
		}
		ret = append(ret, tmp2...)
	}
	return ret
}

func remove[T any](arr []T, i int) []T {
	if i == len(arr)-1 {
		return arr[:i]
	}
	arr[i] = arr[len(arr)-1]
	return arr[:len(arr)-1]
}
