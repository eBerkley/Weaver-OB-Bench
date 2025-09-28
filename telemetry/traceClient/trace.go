package traceclient

import (
	"fmt"
	"io"
	"strings"
	"time"
)

type Event struct {
	timestamp time.Time
	duration  time.Duration
}

type Trace struct {
	traceID string
	spans   map[string]*Span // spanID -> Span
	method  Method

	root *Span

	duration  time.Duration
	timestamp time.Time

	lastUpdated time.Time
}

type Span struct {
	t         Type
	parent    *Span
	children  map[string]*Span // In the case of a client, only a single.
	trace     *Trace
	operation Operation
	events    map[EventType]*Event // either start or end
	timestamp time.Time
	duration  time.Duration
}

func (t *Trace) PostProcess() {
	for spanid, span := range t.spans {
		if span.parent != nil {
			span.parent.children[spanid] = span
		}
	}
}

func (s *Span) Print(w io.Writer, nindent int) {
	indent := strings.Repeat("\t", nindent)
	procDuration := s.duration

	for _, child := range s.children {
		procDuration -= child.duration
	}
	for _, ev := range s.events {
		procDuration -= ev.duration
	}
	if s.t == TypeClient && procDuration == s.duration {
		procDuration = 0
	}
	fmt.Fprintf(w, "%s%s.%v: %v (%v)\n", indent, s.operation, s.t, s.duration, procDuration)
	for _, child := range s.children {
		child.Print(w, nindent+1)
	}

	for et, ev := range s.events {
		fmt.Fprintf(w, "%s\t%v: %v (%v)\n", indent, et.String(), ev.duration, ev.timestamp.Format(time.RFC3339))
	}

}

func (t *Trace) Print(w io.Writer) {

	if t.method == "" {
		t.method = "UNKNOWN"
	}

	t.PostProcess()

	fmt.Fprintf(w, "%s = %v (%v @ %v)\n", t.method, t.duration, t.traceID, t.timestamp.Format(time.RFC3339))

	t.root.Print(w, 0)
	// for _, span := range t.spans {
	// 	fmt.Fprintf(w, "\t%s.%v: %v\n", span.operation, span.t, span.duration)
	// 	for et, ev := range span.events {
	// 		fmt.Fprintf(w, "\t\t%v: %v (%v)\n", et.String(), ev.duration, ev.timestamp)
	// 	}
	// }

}
