// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package paymentservice

import (
	"context"
	"time"
	goruntime "runtime"

	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	_ "go.uber.org/automaxprocs"

	imetrics "github.com/eberkley/weaver/runtime/codegen"
)

type CreditCardInfo struct {
	weaver.AutoMarshal
	Number          string
	CVV             int32
	ExpirationYear  int
	ExpirationMonth time.Month
}

func (s *impl) Init(ctx context.Context) error {
	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				imetrics.GroupGoroutineFor(imetrics.ComponentLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/paymentservice/PaymentService"}).Set(float64(goruntime.NumGoroutine()))
			}
		}
	}()
	return nil
}

// LastFour returns the last four digits of the card number.
func (c CreditCardInfo) LastFour() string {
	num := c.Number
	if len(num) > 4 {
		num = num[len(num)-4:]
	}
	return num
}

type PaymentService interface {
	Charge(ctx context.Context, amount money.T, card CreditCardInfo) (string, error)
}

type impl struct {
	weaver.Implements[PaymentService]
}

// Charge charges the given amount of money to the given credit card, returning
// the transaction id.
func (s *impl) Charge(ctx context.Context, amount money.T, card CreditCardInfo) (string, error) {
	initTime := time.Now()

	defer func() {
		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/paymentservice/PaymentService", Method: "Charge"}).Put(float64(time.Since(initTime).Microseconds()))
	}()
	return charge(amount, card, s.Logger(ctx))
}
