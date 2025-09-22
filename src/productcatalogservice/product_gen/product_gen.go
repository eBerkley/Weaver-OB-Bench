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

const productsPerFile = 1000

type category uint8

type ObjectProto struct {
	name        string
	categories  []category
	description string
}

func obj(name string, categories []category, description string) ObjectProto {
	return ObjectProto{name: name, categories: categories, description: description}
}

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

var (
	colors = [...]string{"Red", "Orange", "Yellow", "Blue", "Indigo", "Violet",
		"Pink", "Cyan", "Purple", "Black", "White", "Gold", "Silver", "Sage",
		"Amber", "Offwhite", "Aqua", "Maroon", "Aquamarine", "Fuchsia", "Rose",
		"Tangerine", "Azure", "Beige", "Almond", "Charcoal", "Khaki", "Salmon",
		"Magnolia", "Carrot", "Mustard", "Pear", "Peridot", "Periwinkle", "Pumpkin",
		"Raspberry", "Tan", "Turquoise", "Vermilion", "Viridian", "Wheat", "Lavender",
		"Magenta", "Orchid", "Lime", "Coral", "Lemon",

		"Blush", "Crimson", "Teal", "Olive", "Mint", "Peach", "Ruby", "Ivory", "Cobalt",
		"Emerald", "Jade", "Lilac", "Mauve", "Ochre", "Plum", "Sapphire", "Scarlet", "Taupe", "Topaz",
		"Amethyst", "Burgundy", "Cerulean", "Chartreuse", "Sepia", "Umber", "Zaffre",
	}

	objects = map[string]ObjectProto{
		"Sunglasses":    obj("Sunglasses", []category{accessories}, "Add a modern touch to your outfits with these sleek aviator sunglasses."),
		"Tanktop":       obj("Tanktop", []category{clothing, tops}, "Perfectly cropped tank, with a scooped neckline."),
		"Watch":         obj("Watch", []category{accessories}, "This watch will work with most of your outfits."),
		"Bracelet":      obj("Bracelet", []category{accessories}, "This bracelet will work with most of your outfits."),
		"Hairtie":       obj("Hairtie", []category{hair, accessories}, "This hair tie will surely tie your hair."),
		"Loafers":       obj("Loafers", []category{footwear}, "A neat addition to your summer wardrobe."),
		"Hairdryer":     obj("Hairdryer", []category{hair, beauty}, "This lightweight hairdryer has 3 heat and speed settings. It's perfect for travel."),
		"Candlestick":   obj("Candlestick", []category{home, decor}, "This small but intricate candle stick is an excellent gift"),
		"Jar":           obj("Jar", []category{kitchen, home}, "This jar can hold 57 oz (1.7 l)."),
		"Cup":           obj("Cup", []category{kitchen, home}, "This beautiful vintage cup is sure to elevate your meals."),
		"Mug":           obj("Mug", []category{kitchen, home}, "A simple mug."),
		"Bedsheets":     obj("Bedsheets", []category{home}, "These bedsheets are so comfy."),
		"Tshirt":        obj("Tshirt", []category{clothing, tops}, "The comfiest T-Shirt in the world."),
		"Sweatpants":    obj("Sweatpants", []category{clothing}, "These sweatpants are even comfier than our T-Shirts."),
		"Hoodie":        obj("Hoodie", []category{clothing, tops}, "Perfect for any lazy saturday."),
		"Pajamas":       obj("Pajamas", []category{clothing}, "These pajamas are perfect for sleeping."),
		"Vase":          obj("Vase", []category{home, decor}, "This vase is so pretty. Flowers not included."),
		"Sneakers":      obj("Sneakers", []category{footwear}, "These will make you run so fast."),
		"Sandals":       obj("Sandals", []category{footwear}, "Perfect for any beach."),
		"Socks":         obj("Socks", []category{footwear, clothing}, "Our socks rock!"),
		"Chair":         obj("Chair", []category{home, kitchen}, "Our kitchen chairs are as durable as they get"),
		"Table":         obj("Table", []category{kitchen}, "Our kitchen tables are perfect for both meals and entertainment!"),
		"TV":            obj("TV", []category{home}, "We have the smartest TVs in the world."),
		"Cabinet":       obj("Cabinet", []category{home, decor}, "Each cabinet fits up to 250 pairs of socks"),
		"Painting":      obj("Painting", []category{home, decor}, "Absolutely stunning, gorgeous paintings."),
		"Desk":          obj("Desk", []category{home}, "You'll never be more productive than you will using our desks"),
		"Lamp":          obj("Lamp", []category{home, decor}, "Can be used to set any mood."),
		"Jeans":         obj("Jeans", []category{clothing}, "Our jeans are the baggiest in the world."),
		"Crewneck":      obj("Crewneck", []category{clothing, tops}, "Perfect for every occasion."),
		"Coat":          obj("Coat", []category{clothing, tops}, "Our coats will keep you warm in the coldest weather!"),
		"Jacket":        obj("Jacket", []category{clothing, tops}, "Our jackets are great for both form and function."),
		"Scarf":         obj("Scarf", []category{clothing, accessories}, "Our scarfs are so warm and comfy!"),
		"Rainboots":     obj("Rainboots", []category{footwear}, "Waterproof, yet comfy!"),
		"Snowboots":     obj("Rainboots", []category{footwear}, "One size fits most."),
		"Mirror":        obj("Mirror", []category{home, decor}, "See yourself like never before"),
		"Glasses":       obj("Glasses", []category{accessories}, "See EVERYTHING like never before"),
		"Frame":         obj("Frame", []category{home, decor}, "Perfect for framing our beautiful pictures!"),
		"Slippers":      obj("Slippers", []category{home, footwear}, "Your feet will never be as comfy as they are when you are wearing our slippers."),
		"Refridgerator": obj("Refridgerator", []category{home}, "Your food will never be as cold!"),
		"Microwave":     obj("Microwave", []category{home}, "Your food will never be as hot!"),
		"Laptop":        obj("Laptop", []category{home}, "Our laptops have over 25 USB ports!"),
		"Printer":       obj("Printer", []category{home}, "Can print over 4 pages per minute!"),
		"Keyboard":      obj("Keyboard", []category{home}, "Has over 200 keys!"),
		"Mouse":         obj("Mouse", []category{home}, "The computer equipment, not the animal."),
		"Shampoo":       obj("Shampoo", []category{hair, beauty}, "Unfortunately only a 1-in-1"),
		"Conditioner":   obj("Conditioner", []category{hair, beauty}, "Buy with our shampoo for a DIY 2-in-1!"),
		"Toothpaste":    obj("Toothpaste", []category{beauty}, "Combine with our shampoo and conditioner for a DIY 3-in-1!"),
		"Pencil":        obj("Pencil", []category{home, accessories}, "Tuck it behind your ear!"),
		"Microphone":    obj("Microphone", []category{home}, "So loud, your neighbors will love it!"),
		"Orb":           obj("Orb", []category{home}, "We have the most magical orbs in town!"),
		"Wand":          obj("Wand", []category{accessories}, "Our magic wands can cast any spell!"),
		"Grill":         obj("Grill", []category{home}, "Our grill is sure to fire your guests up!"),
		"Pan":           obj("Pan", []category{home, kitchen}, "Our pans are as nonstick as they get! "),
		"Sponge":        obj("Sponge", []category{home, kitchen}, "Our sponges are super funny!"),
		"Backpack":      obj("Backpack", []category{accessories}, "Our backpacks can fit 100 laptop chargers!"),
		"Firealarm":     obj("Firealarm", []category{home}, "Our Fire alarms are super satisfying to pull!"),
		"Deodorant":     obj("Deodorant", []category{beauty}, "Our deodorants are super smelly!"),
		"Book":          obj("Book", []category{accessories, decor}, "Our books are great for pretending to read!"),
		"Keys":          obj("Keys", []category{home}, "Our keys can unlock any door!"),
		"Camera":        obj("Camera", []category{accessories}, "Perfect for pretending you know what the rule of thirds means!"),
		"Tissue":        obj("Tissue", []category{home}, "Our tissues will have you wishing you were sick all the time!"),
		"Curtain":       obj("Curtain", []category{home}, "Our curtains are super private!"),
		"Toilet":        obj("Toilet", []category{home}, "Will have you feeling like royalty"),
		"Funnel":        obj("Funnel", []category{kitchen}, "Perfect for funneling!"),
		"Flashdrive":    obj("Flashdrive", []category{accessories}, "Our flashdrives have enough storage for over 10 unique videos!"),
		"GPU":           obj("GPU", []category{home, decor}, "Our GPUs are perfect for LLM Inference!"),
		"Surfboard":     obj("Surfboard", []category{accessories}, "Our surfboards will make you go super fast!"),
		"Raincoat":      obj("Raincoat", []category{tops, clothing}, "Our raincoats would keep you dry in a swimming pool!"),
		// At this point I stopped typing them out by hand
		"Umbrella": obj("Umbrella", []category{accessories}, "Stay dry with our stylish umbrellas."),
		"Wallet":   obj("Wallet", []category{accessories}, "Keep your cash and cards organized."),
		"Hat":      obj("Hat", []category{accessories}, "Our hats are perfect for any occasion."),
		"Gloves":   obj("Gloves", []category{accessories}, "Stay warm with our cozy gloves."),
		"Necklace": obj("Necklace", []category{accessories, beauty}, "Add elegance to your outfit with our necklaces."),
		"Earrings": obj("Earrings", []category{accessories, beauty}, "Our earrings are the perfect accessory."),
		// "Slippers":      obj("Slippers", []category{footwear}, "Relax in comfort with our soft slippers."),
		"Boots":         obj("Boots", []category{footwear}, "Durable and stylish boots for any weather."),
		"Blender":       obj("Blender", []category{kitchen}, "Blend your favorite smoothies with ease."),
		"Toaster":       obj("Toaster", []category{kitchen}, "Perfectly toast your bread every time."),
		"Knife":         obj("Knife", []category{kitchen}, "Our knives are sharp and durable."),
		"Cutting Board": obj("Cutting Board", []category{kitchen}, "A must-have for any kitchen."),
		"Apron":         obj("Apron", []category{kitchen}, "Cook in style with our aprons."),
		"Clock":         obj("Clock", []category{home, decor}, "Keep track of time with our elegant clocks."),
		"Rug":           obj("Rug", []category{home, decor}, "Add warmth to your home with our rugs."),
		"Bookshelf":     obj("Bookshelf", []category{home, decor}, "Organize your books with our sturdy bookshelves."),
		"Fan":           obj("Fan", []category{home}, "Stay cool with our powerful fans."),
		"Purifier":      obj("Purifier", []category{home}, "Breathe clean air with our air purifiers."),
		"Vacuum":        obj("Vacuum", []category{home}, "Keep your home clean with our efficient vacuums."),
		// "Desk Lamp":     obj("Desk Lamp", []category{home, decor}, "Brighten your workspace with our desk lamps."),
		"Waterbottle": obj("Waterbottle", []category{accessories}, "Stay hydrated with our reusable water bottles."),
		"Thermos":     obj("Thermos", []category{kitchen}, "Keep your drinks hot or cold with our thermoses."),
		// "Backpack":      obj("Backpack", []category{accessories}, "Carry your essentials in style."),
		"Suitcase":    obj("Suitcase", []category{accessories}, "Travel with ease using our durable suitcases."),
		"Notebook":    obj("Notebook", []category{accessories}, "Jot down your thoughts in our notebooks."),
		"Pen":         obj("Pen", []category{accessories}, "Write smoothly with our premium pens."),
		"Stapler":     obj("Stapler", []category{home}, "Keep your documents organized with our staplers."),
		"Paperclips":  obj("Paperclips", []category{home}, "Secure your papers with our colorful paper clips."),
		"Calculator":  obj("Calculator", []category{home}, "Perform calculations quickly with our calculators."),
		"Headphones":  obj("Headphones", []category{accessories}, "Enjoy your music with our high-quality headphones."),
		"Speaker":     obj("Speaker", []category{home}, "Fill your room with sound using our speakers."),
		"Smartphone":  obj("Smartphone", []category{home}, "Stay connected with our latest smartphones."),
		"Tablet":      obj("Tablet", []category{home}, "Work and play on the go with our tablets."),
		"Charger":     obj("Charger", []category{accessories}, "Keep your devices powered with our chargers."),
		"Batteries":   obj("Batteries", []category{accessories}, "Charge your devices anywhere with our batteries."),
		"Drone":       obj("Drone", []category{accessories}, "Capture stunning aerial views with our drones."),
		"Binoculars":  obj("Binoculars", []category{accessories}, "See far and wide with our binoculars."),
		"Fishingrod":  obj("Fishingrod", []category{accessories}, "Catch your next big fish with our fishing rods."),
		"Helmet":      obj("Helmet", []category{accessories}, "Protect your head with our sturdy helmets."),
		"Lantern":     obj("Lantern", []category{home, decor}, "Light up your surroundings with our lanterns."),
		"Compass":     obj("Compass", []category{accessories}, "Find your way with our reliable compasses."),
		"Shovel":      obj("Shovel", []category{home}, "Dig with ease using our durable shovels."),
		"Basket":      obj("Basket", []category{home, decor}, "Carry your items in our stylish baskets."),
		"Plates":      obj("Plates", []category{kitchen}, "Serve your meals on our elegant plates."),
		"Bowls":       obj("Bowls", []category{kitchen}, "Perfect for soups and cereals."),
		"Fork":        obj("Fork", []category{kitchen}, "Our forks are perfect for any meal."),
		"Spoon":       obj("Spoon", []category{kitchen}, "Our spoons are great for soups and desserts."),
		"Spatula":     obj("Spatula", []category{kitchen}, "Flip your pancakes with our sturdy spatulas."),
		"Whisk":       obj("Whisk", []category{kitchen}, "Whip up your recipes with our efficient whisks."),
		"Colander":    obj("Colander", []category{kitchen}, "Drain your pasta with our durable colanders."),
		"Peeler":      obj("Peeler", []category{kitchen}, "Peel fruits and vegetables effortlessly."),
		"Grater":      obj("Grater", []category{kitchen}, "Grate cheese and more with our sharp graters."),
		"Thermometer": obj("Thermometer", []category{home}, "Measure temperature accurately."),
		"Ruler":       obj("Ruler", []category{accessories}, "Measure with precision using our rulers."),
		"Globe":       obj("Globe", []category{home, decor}, "Explore the world with our detailed globes."),
		"Puzzle":      obj("Puzzle", []category{home}, "Challenge your mind with our fun puzzles."),
		"Toy":         obj("Toy", []category{home}, "Keep your kids entertained with our toys."),
		"Drill":       obj("Drill", []category{home}, "Our drills are perfect for any DIY project."),
		"Saw":         obj("Saw", []category{home}, "Cut through materials with our sharp saws."),
		"Hammer":      obj("Hammer", []category{home}, "Drive nails with our sturdy hammers."),
		"Wrench":      obj("Wrench", []category{home}, "Tighten bolts with our reliable wrenches."),
		"Screwdriver": obj("Screwdriver", []category{home}, "Fix things with our versatile screwdrivers."),
		"Chisel":      obj("Chisel", []category{home}, "Carve wood with our durable chisels."),
		"Clamp":       obj("Clamp", []category{home}, "Hold items securely with our strong clamps."),
		"Level":       obj("Level", []category{home}, "Ensure precision with our accurate levels."),
		"Rope":        obj("Rope", []category{accessories}, "Tie things securely with our sturdy ropes."),
		"Net":         obj("Net", []category{accessories}, "Catch fish or secure items with our nets."),
		"Bucket":      obj("Bucket", []category{home}, "Carry water or other items with our durable buckets."),
		"Blouse":      obj("Blouse", []category{clothing, tops}, "A stylish blouse for any occasion."),
		"Skirt":       obj("Skirt", []category{clothing}, "A versatile skirt for casual or formal wear."),
		"Shorts":      obj("Shorts", []category{clothing}, "Comfortable shorts for warm weather."),
		"Leggings":    obj("Leggings", []category{clothing}, "Stretchy leggings for workouts or lounging."),
		"Cardigan":    obj("Cardigan", []category{clothing, tops}, "A cozy cardigan for layering."),
		"Blazer":      obj("Blazer", []category{clothing, tops}, "A sharp blazer for professional settings."),
		"Vest":        obj("Vest", []category{clothing, tops}, "A lightweight vest for added style."),
		"Overalls":    obj("Overalls", []category{clothing}, "Classic overalls for a casual look."),
		"Jumpsuit":    obj("Jumpsuit", []category{clothing}, "A trendy one-piece outfit."),
		"Poncho":      obj("Poncho", []category{clothing, tops}, "A stylish poncho for rainy days."),
		"Kimono":      obj("Kimono", []category{clothing, tops}, "A traditional kimono with modern flair."),
		"Swimsuit":    obj("Swimsuit", []category{clothing}, "A sleek swimsuit for the beach."),
		"Bathrobe":    obj("Bathrobe", []category{clothing}, "A plush bathrobe for ultimate comfort."),
		"Capris":      obj("Capris", []category{clothing}, "Casual capris for everyday wear."),
		"Tunic":       obj("Tunic", []category{clothing, tops}, "A flowy tunic for a relaxed look."),
		"Anorak":      obj("Anorak", []category{clothing, tops}, "A lightweight anorak for outdoor adventures."),
		"Tracksuit":   obj("Tracksuit", []category{clothing}, "A sporty tracksuit for active days."),
		"Romper":      obj("Romper", []category{clothing}, "A playful romper for summer outings."),
		"Slip":        obj("Slip", []category{clothing}, "A silky slip for layering."),
		"Camisole":    obj("Camisole", []category{clothing, tops}, "A delicate camisole for layering."),
		"Pullover":    obj("Pullover", []category{clothing, tops}, "A warm pullover for chilly days."),
		"Windbreaker": obj("Windbreaker", []category{clothing, tops}, "A lightweight windbreaker for breezy weather."),
		"Henley":      obj("Henley", []category{clothing, tops}, "A casual henley shirt for everyday wear."),
		"Blouson":     obj("Blouson", []category{clothing, tops}, "A chic blouson for a modern look."),
		"Peacoat":     obj("Peacoat", []category{clothing, tops}, "A classic peacoat for colder seasons."),
		"Parkas":      obj("Parkas", []category{clothing, tops}, "A warm parka for winter weather."),
		"Trenchcoat":  obj("Trenchcoat", []category{clothing, tops}, "A timeless trenchcoat for rainy days."),
		"Leotard":     obj("Leotard", []category{clothing}, "A flexible leotard for dance or gymnastics."),
		"Gown":        obj("Gown", []category{clothing}, "An elegant gown for formal events."),
		"Turtleneck":  obj("Turtleneck", []category{clothing, tops}, "A cozy turtleneck for layering."),
		"Booties":     obj("Booties", []category{footwear}, "Stylish and comfortable booties for any occasion."),
		"Clogs":       obj("Clogs", []category{footwear}, "Durable clogs perfect for casual wear."),
		"Espadrilles": obj("Espadrilles", []category{footwear}, "Lightweight espadrilles for summer."),
		"Flats":       obj("Flats", []category{footwear}, "Elegant flats for everyday use."),
		"Flipflops":   obj("Flipflops", []category{footwear}, "Casual flipflops for the beach."),
		"Highheels":   obj("Highheels", []category{footwear}, "Chic high heels for formal events."),
		"Slides":      obj("Slides", []category{footwear}, "Comfortable slides for lounging."),
		// "Boots":         obj("Boots", []category{footwear}, "Rugged boots for outdoor adventures."),
		"Wedges": obj("Wedges", []category{footwear}, "Stylish wedges for a modern look."),
		// "Loafers":       obj("Loafers", []category{footwear}, "Classic loafers for a polished appearance."),
		"Derbies": obj("Derbies", []category{footwear}, "Sophisticated derbies for formal wear."),
		"Oxfords": obj("Oxfords", []category{footwear}, "Timeless oxfords for professional settings."),
		// "Slippers":      obj("Slippers", []category{footwear}, "Cozy slippers for relaxing at home."),
		// "Sandals":       obj("Sandals", []category{footwear}, "Breathable sandals for warm weather."),
		"Trainers":  obj("Trainers", []category{footwear}, "Versatile trainers for active lifestyles."),
		"Cleats":    obj("Cleats", []category{footwear}, "Durable cleats for sports."),
		"Stilettos": obj("Stilettos", []category{footwear}, "Elegant stilettos for special occasions."),
		"Moccasins": obj("Moccasins", []category{footwear}, "Comfortable moccasins for casual wear."),
		"Chukkas":   obj("Chukkas", []category{footwear}, "Stylish chukkas for a modern look."),
		// "Sneakers":      obj("Sneakers", []category{footwear}, "Trendy sneakers for everyday wear."),
		"Blush":       obj("Blush", []category{beauty}, "Add a natural glow with our premium blush."),
		"Bronzer":     obj("Bronzer", []category{beauty}, "Achieve a sun-kissed look with our bronzer."),
		"Concealer":   obj("Concealer", []category{beauty}, "Hide imperfections with our smooth concealer."),
		"Foundation":  obj("Foundation", []category{beauty}, "Create a flawless base with our foundation."),
		"Highlighter": obj("Highlighter", []category{beauty}, "Illuminate your features with our highlighter."),
		"Lipstick":    obj("Lipstick", []category{beauty}, "Add a pop of color with our vibrant lipstick."),
		"Mascara":     obj("Mascara", []category{beauty}, "Enhance your lashes with our volumizing mascara."),
		"Eyeshadow":   obj("Eyeshadow", []category{beauty}, "Create stunning eye looks with our eyeshadow."),
		"Eyeliner":    obj("Eyeliner", []category{beauty}, "Define your eyes with our precise eyeliner."),
		"Powder":      obj("Powder", []category{beauty}, "Set your makeup with our lightweight powder."),
		"Primer":      obj("Primer", []category{beauty}, "Prepare your skin with our smoothing primer."),
		"Serum":       obj("Serum", []category{beauty}, "Nourish your skin with our hydrating serum."),
		"Moisturizer": obj("Moisturizer", []category{beauty}, "Keep your skin hydrated with our moisturizer."),
		"Cleanser":    obj("Cleanser", []category{beauty}, "Gently cleanse your skin with our facial cleanser."),
		"Scrub":       obj("Scrub", []category{beauty}, "Exfoliate your skin with our gentle scrub."),
		"Mask":        obj("Mask", []category{beauty}, "Rejuvenate your skin with our face mask."),
		"Toner":       obj("Toner", []category{beauty}, "Balance your skin with our refreshing toner."),
		"Palette":     obj("Palette", []category{beauty}, "Create endless looks with our makeup palette."),
		"Gloss":       obj("Gloss", []category{beauty}, "Add shine to your lips with our lip gloss."),
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
	ok := true
	var id string
	for ok {
		id = uuid.New().String()[25:35]
		_, ok = ids[id]
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
var idfilename = filepath.Clean(filepath.Join(outdirname, "..", "..", "loadgenerator", "products", "products.py"))

func WriteProducts(ps []Product, i int) error {

	b, err := json.Marshal(ps)
	if err != nil {
		return err
	}
	file, err := os.Create(fmt.Sprintf("%v.js", filepath.Join(outdirname, strconv.Itoa(i))))
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(file, "db = db.getSiblingDB(\"product-db\"); \ndb.products.insertMany(%v);",
		string(b))
	return err
	// return os.WriteFile(, b, 0750)
}

func main() {
	// fmt.Printf("idfile: %v\n", idfilename)
	// os.Exit(0)
	if err := os.RemoveAll(outdirname); err != nil {
		fmt.Println(err)
		os.Exit(2)
	}
	if err := os.Mkdir(outdirname, 0750); err != nil && !os.IsExist(err) {
		fmt.Println(err)
		os.Exit(2)
	}

	idFile, err := os.Create(idfilename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "os.Create(%v): %v", idfilename, err)
		os.Exit(2)
	}

	defer idFile.Close()

	fmt.Fprintf(idFile, "products = [\n")

	i := 0
	n := 0
	const FREQ = 10

	var ps []Product
	for _, p := range objects {
		for _, mat := range materials {
			for _, c := range colors {
				n++
				product := MakeProduct(p, mat, c)
				ps = append(ps, product)
				if n%FREQ == 0 {
					// in format:
					//	`		"<pid>",`
					fmt.Fprintf(idFile, "\t\"%v\",\n", product.ID)
				}
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
	fmt.Fprintf(idFile, "]\n")
}
