package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"

	"github.com/google/uuid"
)

// Not meant to be imported by anything, just create more json files.

const productsPerFile = 250

type category uint8

const (
	accessories category = iota
	clothing
	tops
	footwear
	hair
	beauty
	decor
	home
	kitchen
)

var categoryStrings = [...]string{"accessories", "clothing", "tops", "footwear", "hair", "beauty", "decor", "home", "kitchen"}

func (c category) String() string {
	return categoryStrings[c]
}

const picture = "/static/img/products/bamboo-glass-jar.jpg"

type ObjectProto struct {
	name        string
	categories  []category
	description string
}

func obj(name string, categories []category, description string) ObjectProto {
	return ObjectProto{name: name, categories: categories, description: description}
}

var (
	colors = [...]string{"Red", "Orange", "Yellow", "Blue", "Indigo", "Violet", "Pink", "Cyan", "Purple", "Black", "White", "Gold", "Silver"}

	materials = [...]string{"Wood", "Bamboo", "Cotton", "Paper", "Plastic", "Ceramic", "Glass"}

	objects = map[string]ObjectProto{
		"Sunglasses":  obj("Sunglasses", []category{accessories}, "Add a modern touch to your outfits with these sleek aviator sunglasses."),
		"Tanktop":     obj("Tanktop", []category{clothing, tops}, "Perfectly cropped tank, with a scooped neckline."),
		"Watch":       obj("Watch", []category{accessories}, "This watch will work with most of your outfits."),
		"Bracelet":    obj("Bracelet", []category{accessories}, "This bracelet will work with most of your outfits."),
		"Hairtie":     obj("Hairtie", []category{hair, accessories}, "This hair tie will surely tie your hair."),
		"Loafers":     obj("Loafers", []category{footwear}, "A neat addition to your summer wardrobe."),
		"Hairdryer":   obj("Hairdryer", []category{hair, beauty}, "This lightweight hairdryer has 3 heat and speed settings. It's perfect for travel."),
		"Candlestick": obj("Candlestick", []category{home, decor}, "This small but intricate candle stick is an excellent gift"),
		"Jar":         obj("Jar", []category{kitchen, home}, "This jar can hold 57 oz (1.7 l)."),
		"Cup":         obj("Cup", []category{kitchen, home}, "This beautiful vintage cup is sure to elevate your meals."),
		"Mug":         obj("Mug", []category{kitchen, home}, "A simple mug."),
		"Bedsheets":   obj("Bedsheets", []category{home}, "These bedsheets are so comfy."),
		"Tshirt":      obj("Tshirt", []category{clothing, tops}, "The comfiest T-Shirt in the world."),
		"Sweatpants":  obj("Sweatpants", []category{clothing}, "These sweatpants are even comfier than our T-Shirts."),
		"Pajamas":     obj("Pajamas", []category{clothing}, "These pajamas are perfect for sleeping."),
		"Vase":        obj("Vase", []category{home, decor}, "This vase is so pretty. Flowers not included."),
		"Sneakers":    obj("Sneakers", []category{footwear}, "These will make you run so fast."),
		"Socks":       obj("Socks", []category{footwear, clothing}, "Our socks rock!"),
	}
)

type price struct {
	CurrencyCode string `json:"currencyCode"`
	Units        int64  `json:"units"`
	Nanos        int32  `json:"nanos"`
}

type Product struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Picture     string   `json:"picture"`
	PriceUSD    price    `json:"priceUsd"`
	Categories  []string `json:"categories"`
}

var ids = map[string]struct{}{}

func MakeProduct(proto ObjectProto, color, mat string) Product {
	var p Product
	id := uuid.New().String()[25:35]
	if _, ok := ids[id]; ok {
		fmt.Println("FOUND DUPLICATE...")
		os.Exit(1)
	}
	ids[id] = struct{}{}

	p.ID = id
	p.Name = fmt.Sprintf("%s %s %s", color, mat, proto.name)
	p.Description = proto.description
	p.Picture = picture
	p.PriceUSD.CurrencyCode = "USD"
	p.PriceUSD.Units = rand.Int63n(95) + 5
	p.PriceUSD.Nanos = rand.Int31n(99) * 10000000
	for _, cat := range proto.categories {
		p.Categories = append(p.Categories, cat.String())
	}

	return p
}

func must[T any](t T, err error) T {
	if err != nil {
		panic(err)
	}
	return t
}

var outdirname = filepath.Clean(filepath.Join(filepath.Dir(must(os.Executable())), "..", "products"))

func WriteProducts(ps []Product, i int) error {
	b, err := json.Marshal(ps)
	if err != nil {
		return err
	}
	return os.WriteFile(fmt.Sprintf("%v.json", filepath.Join(outdirname, strconv.Itoa(i))), b, 0750)
}

func main() {
	if err := os.RemoveAll(outdirname); err != nil {
		fmt.Println(err)
		os.Exit(2)
	}
	if err := os.Mkdir(outdirname, 0750); err != nil && !os.IsExist(err) {
		fmt.Println(err)
		os.Exit(2)
	}

	i := 0
	var ps []Product
	for _, p := range objects {
		for _, mat := range materials {
			for _, c := range colors {
				ps = append(ps, MakeProduct(p, mat, c))
				if len(ps) >= productsPerFile {

					if err := WriteProducts(ps, i); err != nil {
						fmt.Printf("error while marshaling JSON: %s", err.Error())
						os.Exit(1)
					}
					i++
					ps = ps[:0] // Because `clear(ps)` doesn't do anything useful
				}
			}
		}
	}

	fmt.Println(i)
}
