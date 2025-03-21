#!/usr/bin/python
#
# Copyright 2018 Google LLC
# $HOME/.local/bin
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import random
from locust import FastHttpUser, constant_pacing, LoadTestShape, task, tag
from typing import Tuple, Optional, List
from faker import Faker
import logging
import datetime
import os
import locust.stats
locust.stats.CSV_STATS_INTERVAL_SEC = int(os.getenv("LOCUST_CSV_INTERVAL", 1))

RESET_CONN = int(os.getenv("LOCUST_RESET_CONN", "0")) # 1 = True, 0 = False

RESET_FREQ      = 5 * RESET_CONN
INDEX_FREQ      = 20
CURRENCY_FREQ   = 10
BROWSE_FREQ     = 20
VIEW_CART_FREQ  = 20
ADD_CART_FREQ   = 30
EMPTY_CART_FREQ = 10
CHECKOUT_FREQ   = 10


fake = Faker()

# products = [
#     '0PUK6V6EV0',
#     '1YMWWN1N4O',
#     '2ZYFJ3GM2N',
#     '66VCHSJNUP',
#     '6E92ZMYYFZ',
#     '9SIQT8TOJO',
#     'L9ECAV7KIM',
#     'LS4PSXUNUM',
#     'OLJCESPC7Z']

# Products must be hard coded.
products = [
    "f60b9a0918",
    "50bf7d0d7b",
    "2f90278351",
    "f668e2bc0b",
    "aa9834b37d",
    "6036b1e2b0",
    "75753c49a4",
    "b513792f8d",
    "9b44c94452",
    "c6ee2f6679",
    "2ac80cbeb6",
    "c952015d1f",
    "dd30814e25",
    "bb291f6e5d",
    "328a7f79d0",
    "9a9dd201e9",
    "025e67f5d9",
    "7127f7b444",
    "3384848bf7",
    "35affad863",
    "64a2f6c4a7",
    "4b381bf103",
    "128709e032",
    "3516b7513b",
]
currencies = ['EUR', 'USD', 'JPY', 'CAD', 'GBP', 'TRY']

class WebsiteUser(FastHttpUser):
    wait_time = constant_pacing(2.5)

    def __init__(self, environment):
        super().__init__(environment)

    def on_start(self):
        self.index()

    @tag('refresh')
    @task(RESET_FREQ)
    def reset_index(self):
        self.client.get("/", headers={"Connection": "close"})

    # 1 req
    @task(INDEX_FREQ)
    def index(self):
        self.client.get("/")

    # 1 req
    @task(CURRENCY_FREQ)
    def setCurrency(self):
        self.client.post("/setCurrency",
            {'currency_code': random.choice(currencies)})

    # 1 req
    @task(BROWSE_FREQ)
    def browseProduct(self):
        self.client.get("/product/" + random.choice(products))

    # 1 req
    @task(VIEW_CART_FREQ)
    def viewCart(self):
        self.client.get("/cart")

    # 1 reqs
    @task(ADD_CART_FREQ)
    def addToCart(self):
        product = random.choice(products)
        # self.client.get("/product/" + product)
        self.client.post("/cart", {
            'product_id': product,
            'quantity': random.randint(1,10)})

    # 1 req
    @task(EMPTY_CART_FREQ)
    def empty_cart(self):
        self.client.post('/cart/empty')

    # 1 reqs
    @task(CHECKOUT_FREQ)
    def checkout(self):
        # self.addToCart()
        current_year = datetime.datetime.now().year+1
        self.client.post("/cart/checkout", {
            'email': fake.email(),
            'street_address': fake.street_address(),
            'zip_code': fake.zipcode(),
            'city': fake.city(),
            'state': fake.state_abbr(),
            'country': fake.country(),
            'credit_card_number': fake.credit_card_number(card_type="visa"),
            'credit_card_expiration_month': random.randint(1, 12),
            'credit_card_expiration_year': random.randint(current_year, current_year + 70),
            'credit_card_cvv': f"{random.randint(100, 999)}",
        })

    # 1 req
    def logout(self):
        self.client.get('/logout')  


