from locust import LoadTestShape
from typing import Tuple, Optional, List, Final

import logging

from os import getenv

from statistics import variance

WAIT_TIME = int(getenv("LOCUST_WAIT_TIME", "30")) # seconds
MAX_TAIL = int(getenv("LOCUST_MAX_TAIL", 200))
RAMP_RATE = float(getenv("LOCUST_RAMP_RATE", "10.0")) # users / second
RAMP_AMOUNT = int(getenv("LOCUST_SLOWLOAD_RAMP", 750))
PAUSE_TIME = int(getenv("LOCUST_SLOWER_PAUSE", 60)) # seconds

class SlowLoad(LoadTestShape):
    ramp_amount: Final = RAMP_AMOUNT # users
    """What is the first target to hit?"""
    
    slow_thresh: Final = 15_000
    slow_ramp_amount: Final = ramp_amount // 5

    ramp_rate: Final = RAMP_RATE

    max_tail: Final = MAX_TAIL # ms
    """When p99 latency >= this value, consider it violating."""


    pause_time: Final = PAUSE_TIME

    def __init__(self, *args, **kwargs):

        # === User Count vars ===

        self._slo_timer: int = WAIT_TIME
        """Timer that decreases during violation period. 
        If it hits 0, terminate test."""

        self._target: int = self.ramp_amount
        "What number of users are we trying to ramp to?"
        
        self._p99: float = 0
        """tail latency"""

        self._user_secs: float = 0.0

        super().__init__(*args, **kwargs)

    def tick(self) -> Optional[Tuple[int, float]]:
        log_string = ""
        cur_users : int = self.get_current_user_count()

        self._p50: float = self.runner.stats.total.get_current_response_time_percentile(0.50)

        self._p99: float = self.runner.stats.total.get_current_response_time_percentile(0.99)


        if cur_users < self.ramp_amount:
            return self.ramp_amount, self.ramp_rate

        if self._p99 == None:
            self._p99 = 0

        if self._slo_timer <= 0:
            return None

        log_string += f"users: {cur_users} \t P50: {self._p50} \t P99: {self._p99} \t SLO: {self._slo_timer} "

        if self._p99 > self.max_tail:
            log_string += f"SLO Vioilating..."
            self._slo_timer -= 1
            self._target = cur_users
            

        elif self._user_secs >= self.pause_time:
            self._slo_timer = WAIT_TIME
            
            if cur_users < self.slow_thresh:    
                self._target = cur_users + self.ramp_amount
            else:
                self._target = cur_users + self.slow_ramp_amount

            self._user_secs = 0
            log_string += f"stabilized, ramping up."
            
        else:
            self._user_secs += 1
            # self._slo_timer = WAIT_TIME # We don't want to make ramping up too easy...
            log_string += f"t: {self._user_secs}"
            self._target = cur_users
            

        logging.info(log_string)
        return self._target, self.ramp_rate
