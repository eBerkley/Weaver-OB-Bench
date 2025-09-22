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
    init_users = min(max_users / 2, 3000)
    ramp_speed = 100 # users per second

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
    
    def tick(self):
        cur_users = self.get_current_user_count()
        self._p50: int = self.runner.stats.total.get_current_response_time_percentile(0.50) or 0
        self._p99: int = self.runner.stats.total.get_current_response_time_percentile(0.99) or 0
        logging.info(f"users: {cur_users} \t P50: {self._p50} \t P99: {self._p99}")
        if cur_users < self.init_users:
            return self.init_users, 10.0
        # if cur_users == self.max_users:
        #     logging.info("Ramp completed.")
        return self.max_users, self.ramp_speed