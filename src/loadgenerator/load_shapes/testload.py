from locust import LoadTestShape

from os import getenv

CONST_USERS = int(getenv("LOCUST_CONST_USERS", "5000"))
class TestLoad(LoadTestShape):
    """
    A load generator shape that will increase user count until a constant value is hit, and then it will end the test.
    
    Keyword arguments:
        
        max_users     -- What is the maximum number of users?
        
        ramp_speed    -- How fast (in ups) should it get there?
    
    """
    max_users = CONST_USERS # users

    ramp_speed = 50 # users per second

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
    
    def tick(self):
        cur_users = self.get_current_user_count()
        if cur_users == self.max_users:
            return None
        return self.max_users, self.ramp_speed