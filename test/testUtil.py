#!/bin/python3
import http.client
from faker import Faker
import random
from typing import Dict, Literal, Optional, Iterable, Tuple, List, Callable, Type

from ast import literal_eval

import datetime

MAX_SIZE=5

fake = Faker()

class Input:
    def __init__(self, 
        method: Literal["get", "post"], 
        url: str, 
        postdict: Optional[Dict[str, str]] = None
    ):
        self.method: Literal['get', 'post'] = method
        self.url: str                       = url
        self.dict: Optional[Dict[str, str]] = postdict

    @classmethod 
    def make(cls, s: str):
        l = s.split(",")
        dStr = ",".join(l[2:])
        return cls(l[0], l[1], literal_eval(dStr))

    def __str__(self) -> str:
        return f"{self.method},{self.url},{self.dict}"

class Task:
    def __init__(self, inputs: Iterable[Input]):
        self.inputs: List[Input] = []
        
        for i in inputs:
            self.inputs.append(i)

    
    @classmethod
    def make(cls, s: str):
        c = cls([])

        l = s.split("\n")
        for x in l:
            if ',' in x:
                c.inputs.append(Input.make(x))
            else:
                break    
        return c


    def __str__(self) -> str:
        s = ""
        for i in self.inputs:
            s += str(i) + "\n"
        return s

  

Products = [
    '0PUK6V6EV0',
    '1YMWWN1N4O',
    '2ZYFJ3GM2N',
    '66VCHSJNUP',
    '6E92ZMYYFZ',
    '9SIQT8TOJO',
    'L9ECAV7KIM',
    'LS4PSXUNUM',
    'OLJCESPC7Z']

Currencies = ['EUR', 'USD', 'JPY', 'CAD', 'GBP', 'TRY']

def index():
  return Input("get", "/"),

# index
def setCurrency():
  return *index(), Input("post", "/setCurrency", {'currency_code': random.choice(Currencies)}),

# index
def browseProduct():
  return *index(), Input("get", "/product/" + random.choice(Products)),



def _addToCart():
  product = random.choice(Products)
  return (
    Input("get", "/product/" + product), 
    Input("post", "/cart", {
      'product_id': product,
      'quantity': random.randint(1,10)
    })
  )


# index
def addToCart():
  num = random.randrange(MAX_SIZE)
  ret:List[Input] = []
  for i in range(num):
     ret.extend(_addToCart())

  return *index(), *[i for i in ret],

def viewCart():
  return *addToCart(), Input("get", "/cart"),

def empty_cart():

  return *addToCart(), Input("post", "/cart/empty"),

def checkout():
  current_year = datetime.datetime.now().year+1
  get = addToCart()

  post = Input("post", "/cart/checkout", {
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
  
  return *get, post


task_t = Type[Callable[[], Iterable[Input]]]

tasks: List[task_t] = [index, setCurrency, browseProduct, addToCart, viewCart, checkout]

def GetTask():
    fn: task_t = random.choice(tasks)
    t = Task(fn())
    return t

