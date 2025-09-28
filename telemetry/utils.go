package main

import (
	"net/url"
	"os"
	"strings"
)

func Must[T any](t T, err error) T {
	if err != nil {
		panic(err)
	}
	return t
}

// setter: m => github.com/eberkley/weaver/Main
func GetAbbreviations(fname string) (setter, reverseSetter map[string]string) {
	setter = make(map[string]string)
	reverseSetter = make(map[string]string)

	s := string(Must(os.ReadFile(fname)))
	lines := strings.Split(s, "\n")
	for _, line := range lines {
		parts := strings.Split(line, "=")
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		setter[key] = value
		reverseSetter[value] = key
	}

	return
}

func GetQuery(rawQuery string) string {
	return url.QueryEscape(PROM_BASE_QUERY + rawQuery)
}

type PromRes struct {
}
