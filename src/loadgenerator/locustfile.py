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
from products import products
import logging
import datetime
import os
import locust.stats
locust.stats.CSV_STATS_INTERVAL_SEC = int(os.getenv("LOCUST_CSV_INTERVAL", 1))

from urllib3 import PoolManager

CONN_POOL = int(os.getenv("LOCUST_CONN_POOL", "0")) # 1 = True, 0 = False
REQ_RATE = float(os.getenv("LOCUST_REQ_RATE", "1")) 

def get_conn_pool():
    if CONN_POOL:
        print("[YYYY-MM-DD HH:MM:SS,000] loadgenerator-xxxxxxxxxxx-xxxxx/INFO/root: LOCUST DEBUG: CONNECTION POOLING ENABLED")
        return PoolManager(maxsize=2500, block=False)
    else:
        print("[YYYY-MM-DD HH:MM:SS,000] loadgenerator-xxxxxxxxxxx-xxxxx/INFO/root: LOCUST DEBUG: CONNECTION POOLING DISABLED")
        return None


RESET_CONN = int(os.getenv("LOCUST_RESET_CONN", "0")) # 1 = True, 0 = False
print(f"[YYYY-MM-DD HH:MM:SS,001] loadgenerator-xxxxxxxxxxx-xxxxx/INFO/root: LOCUST DEBUG: RESET_CONN: {RESET_CONN}")
CHECKOUT_MOD 		= int(os.getenv("LOCUST_CHECKOUT_MOD", "1")) 

RESET_FREQ      = 5 * RESET_CONN 		# 5 if HPA is enabled, 0 otherwise. 
INDEX_FREQ      = 20 								# GET /
CURRENCY_FREQ   = 10 								# POST /setCurrency
BROWSE_FREQ     = 20 								# GET /product/<product_id>
VIEW_CART_FREQ  = 20 								# GET /cart
ADD_CART_FREQ   = 30 								# POST /cart
EMPTY_CART_FREQ = 10 								# POST /cart/empty
CHECKOUT_FREQ   = 10 * CHECKOUT_MOD # POST /cart/checkout

fake = Faker()

currencies = ['EUR', 'USD', 'JPY', 'CAD', 'GBP', 'TRY']
class WebsiteUser(FastHttpUser):
    
    wait_time = constant_pacing(REQ_RATE)

    # If LOCUST_CONN_POOL==1, pool connections.
    pool_manager = get_conn_pool()

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
        self.client.get("/product/" + random.choice(products), name="/product/[ID]")

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


