package main

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
