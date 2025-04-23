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

class BinarySlowLoad(LoadTestShape):
    ramp_amount: Final = RAMP_AMOUNT # users
    """What is the first target to hit?"""

    ramp_rate: Final = RAMP_RATE

    max_tail: Final = MAX_TAIL # ms
    """When p99 latency >= this value, consider it violating."""

    search_granularity: Final[float] = 500.0
    """If the current min unsustainable throughput is this far from 
    current max sustainable throughput, terminate."""

    pause_time: Final = PAUSE_TIME

    def __init__(self, *args, **kwargs):

        # === User Count vars ===

        self._slo_timer: int = WAIT_TIME
        """Timer that decreases during violation period. 
        If it hits 0, terminate test."""

        self._target: int = self.ramp_amount
        "What number of users are we trying to ramp to?"
        
        self._p99: float = 0.0
        """tail latency"""

        self._user_secs: float = 0.0

        self._searching: bool = False

        self._valid: float = 0.0
        """Current candidate for maximal sustainable throughput"""

        self._invalid: float = 0.0
        """Current candidate for min unsustainable throughput"""

        self._fallback_target: float = 0.0
        """What value do we scale down to?"""

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

        if not self._searching: # We haven't seen an unsustainable throughput yet
            log_string += f"users: {cur_users} \t P50: {self._p50} \t P99: {self._p99} \t SLO: {self._slo_timer} "

            if self._slo_timer <= 0: # We just found one
                self._searching = True
                log_string += f"BEGINNING SEARCH!"
                self._invalid = cur_users
                
                self._slo_timer = WAIT_TIME
                self._user_secs = 0
                self._fallback_target = self._valid - self.ramp_amount
                self._target = self._fallback_target

            elif self._p99 > self.max_tail: # We are currently violating SLO
                log_string += f"SLO Vioilating..."
                self._slo_timer -= 1
                self._target = cur_users
            
            elif self._user_secs >= self.pause_time: # We are within SLO, and waiting
                self._slo_timer = WAIT_TIME
                self._target = cur_users + self.ramp_amount
                self._user_secs = 0
                self._valid = cur_users
                log_string += f"stabilized, ramping up."
                
            else: # We are within SLO, and we just finished waiting.
                self._user_secs += 1
                self._slo_timer = WAIT_TIME
                log_string += f"t: {self._user_secs}"
                self._target = cur_users
                
        else: # self._searching == True
            log_string += f"users: {cur_users} \t valid: {self._valid} \t P50: {self._p50} \t P99: {self._p99} \t SLO: {self._slo_timer} "
            if self._slo_timer <= 0:
                if self.search_granularity > cur_users - self._valid: # We found a termination point!
                    return None
                log_string += f"\t Invalid. Ramping down..."
                self._invalid = cur_users

                self._slo_timer = WAIT_TIME / 2
                self._user_secs = 0
                self._target = self._fallback_target
            
            elif self._p99 > self.max_tail: 
                log_string += f"SLO Vioilating..."
                self._slo_timer -= 1
                self._target = cur_users
            
            elif self._user_secs >= self.pause_time:
                self._slo_timer = WAIT_TIME / 2
                self._valid = max(self._valid, cur_users)

                self._target = (self._valid + self._invalid) // 2

                self._user_secs = 0
                log_string += f"stabilized, ramping up."
                
            else:
                self._user_secs += 1
                # self._slo_timer = WAIT_TIME / 2 # We don't want to make it too easy to complete a ramp up
                log_string += f"t: {self._user_secs}"
                self._target = cur_users
                
            
        logging.info(log_string)
        return self._target, self.ramp_rate
