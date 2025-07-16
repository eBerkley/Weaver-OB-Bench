from locust import LoadTestShape
from os import getenv

import logging
CONST_USERS = int(getenv("LOCUST_CONST_USERS", "5000"))

class ConstLoad(LoadTestShape):
    """
    A load generator shape that will increase user count until a constant value is hit, and then it will hold that value indefinitely.
    
    Keyword arguments:
        
        max_users     -- What is the maximum number of users?
        
        ramp_speed    -- How fast (in ups) should it get there?
    
    """
    max_users = CONST_USERS # users

    ramp_speed = 100 # users per second

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
    
    def tick(self):
        cur_users = self.get_current_user_count()
        if cur_users < 3000:
            return 3000, 10.0
        if cur_users == self.max_users:
            logging.info("Ramp completed.")
        return self.max_users, self.ramp_speed