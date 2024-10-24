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
from locust import FastHttpUser, between, LoadTestShape, task, tag
from typing import Tuple, Optional, List
from faker import Faker
import logging
import datetime

import locust.stats
locust.stats.CSV_STATS_INTERVAL_SEC = 10

fake = Faker()

products = [
    '0PUK6V6EV0',
    '1YMWWN1N4O',
    '2ZYFJ3GM2N',
    '66VCHSJNUP',
    '6E92ZMYYFZ',
    '9SIQT8TOJO',
    'L9ECAV7KIM',
    'LS4PSXUNUM',
    'OLJCESPC7Z']

class WebsiteUser(FastHttpUser):
    def __init__(self, environment):
        super().__init__(environment)

    def on_start(self):
        self.index()

    @tag('refresh')
    @task(3)
    def reset_index(self):
        self.client.get("/", headers={"Connection": "close"})

    # 1 req
    @task(10)
    def index(self):
        self.client.get("/")

    # 1 req
    @task(20)
    def setCurrency(self):
        currencies = ['EUR', 'USD', 'JPY', 'CAD', 'GBP', 'TRY']
        self.client.post("/setCurrency",
            {'currency_code': random.choice(currencies)})

    # 1 req
    @task(100)
    def browseProduct(self):
        self.client.get("/product/" + random.choice(products))

    # 1 req
    @task(30)
    def viewCart(self):
        self.client.get("/cart")

    # 2 reqs
    @task(30)
    def addToCart(self):
        product = random.choice(products)
        self.client.get("/product/" + product)
        self.client.post("/cart", {
            'product_id': product,
            'quantity': random.randint(1,10)})

    # 1 req
    @task(10)
    def empty_cart(self):
        self.client.post('/cart/empty')

    # 3 reqs
    @task(20)
    def checkout(self):
        self.addToCart()
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

    wait_time = between(1, 5)

