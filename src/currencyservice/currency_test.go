package currencyservice

import (
	"context"
	// "encoding/json"
	"math"
	"testing"

	"github.com/ServiceWeaver/onlineboutique/types/money"
	"github.com/ServiceWeaver/weaver/weavertest"
	// "github.com/iancoleman/orderedmap"
)

func TestGetSupportedCurrencies(t *testing.T) {
	// om := orderedmap.New()
	// json.Unmarshal(currencyData, &om)
	// for _, k := range om.Keys() {
	// 	t.Run(k, func(t *testing.T) {
	// 		t.Error(k)
	// 	})
	// }
	weavertest.Local.Test(t, func(t *testing.T, i *impl) {
		out, _ := i.GetSupportedCurrencies(context.TODO())
		t.Error(out)

	})

}

func TestConvert(t *testing.T) {
	const DIVISOR = 10000000.0
	testCases := []struct {
		desc   string
		money  money.T
		toCode string
	}{
		{
			desc: "",
			money: money.T{
				CurrencyCode: "USD",
				Units:        5,
				Nanos:        990000000,
			},
			toCode: "USD",
		},
		{
			desc: "",
			money: money.T{
				CurrencyCode: "USD",
				Units:        5,
				Nanos:        950000000,
			},
			toCode: "USD",
		},
		{
			desc: "",
			money: money.T{
				CurrencyCode: "USD",
				Units:        5,
				Nanos:        990000001,
			},
			toCode: "USD",
		},
		{
			desc: "",
			money: money.T{
				CurrencyCode: "JPY",
				Units:        5,
				Nanos:        990000000,
			},
			toCode: "JPY",
		},
	}
	for _, tC := range testCases {
		t.Run(tC.desc, func(t *testing.T) {
			weavertest.Local.Test(t, func(t *testing.T, i *impl) {

				out, _ := i.Convert(context.TODO(), tC.money, tC.toCode)

				inNanos := math.Round(float64(tC.money.Nanos) / DIVISOR)
				outNanos := math.Round(float64(out.Nanos) / DIVISOR)

				if tC.money.Units != out.Units || inNanos != outNanos {
					t.Errorf("moneyIn %v.%v != moneyOut %v.%v", tC.money.Units, inNanos, out.Units, outNanos)
				}
				t.Errorf("%d.%02.f", out.Units, outNanos)

			})

		})
	}
}
