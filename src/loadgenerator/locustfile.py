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

from urllib3 import PoolManager

CONN_POOL = int(os.getenv("LOCUST_CONN_POOL", "0")) # 1 = True, 0 = False
REQ_RATE = float(os.getenv("LOCUST_REQ_RATE", "1")) 

def get_conn_pool():
    if CONN_POOL:
        return PoolManager(maxsize=2500, block=False)
    else:
        return None


RESET_CONN = int(os.getenv("LOCUST_RESET_CONN", "0")) # 1 = True, 0 = False

RESET_FREQ      = 5 * RESET_CONN # 5 if HPA is enabled, 0 otherwise. 
INDEX_FREQ      = 20 # GET /
CURRENCY_FREQ   = 10 # POST /setCurrency
BROWSE_FREQ     = 20 # GET /product/<product_id>
VIEW_CART_FREQ  = 20 # GET /cart
ADD_CART_FREQ   = 30 # POST /cart
EMPTY_CART_FREQ = 10 # POST /cart/empty
CHECKOUT_FREQ   = 10 # POST /cart/checkout


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
	"f668e2bc0b",
	"aa9834b37d",
	"75753c49a4",
	"b513792f8d",
	"c6ee2f6679",
	"2ac80cbeb6",
	"c952015d1f",
	"dd30814e25",
	"bb291f6e5d",
	"328a7f79d0",
	"9a9dd201e9",
	"7127f7b444",
	"3384848bf7",
	"e0b31e82f7",
	"6516ac97fb",
	"64a2f6c4a7",
	"663def2d79",
	"6c57afa199",
	"192dbff783",
	"83f4531288",
	"925afa11e0",
	"6f665fa9ed",
	"4b381bf103",
	"5db6f7707c",
	"7658466695",
	"3516b7513b",
	"83cc0c6efb",
	"7b5ab6f3e5",
	"c1225a62d2",
	"490d44cff9",
	"e3356d40f6",
	"4b80e19292",
	"5dc94b1f42",
	"e398ce2761",
	"d6bc3e19cc",
	"94ebe18975",
	"2bd4ffec0f",
	"7d6e6f287b",
	"eb2a7844b4",
	"e1bd4f4150",
	"e58f6f23a0",
	"733acc1de4",
	"87393c8a81",
	"9dceff68ee",
	"510a91f5da",
	"8f93ea862a",
	"a581434692",
	"3e75f9698c",
	"928ecffb53",
	"be92e211f9",
	"de1a5bd961",
	"d675e018a4",
	"9c6ae8aa14",
	"a6e133a348",
	"c42e29c865",
	"86486b40c1",
	"5e66d36bde",
	"617ddeb079",
	"4429708036",
	"0aaa9a4916",
	"b7a06daf86",
	"2c430db343",
	"58da3ae8a3",
	"c1034817df",
	"599aaeb2dd",
	"148665c4da",
	"7ed4413b0d",
	"cebe647db7",
	"c2f4c94f17",
	"1ec830b907",
	"acb16862c3",
	"141e1b5ca2",
	"e32f4fe474",
	"7695f523e3",
	"328263424d",
	"59180bda79",
	"59f39ec0a1",
	"c668cbbab9",
	"3d79f111d6",
	"57af9597a4",
	"8cdad0fc86",
	"e9462e5bb6",
	"78b24fd1e2",
	"cb51e898ac",
	"384315bf7d",
	"3e7e3e8274",
	"fb168c1d3f",
	"c7560f1869",
]

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


