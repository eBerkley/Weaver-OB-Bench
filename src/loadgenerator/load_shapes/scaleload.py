from locust import LoadTestShape
from typing import Tuple, Optional, List, Final

import logging

from os import getenv

from statistics import variance

WAIT_TIME = int(getenv("LOCUST_WAIT_TIME", "30")) # seconds
RAMP_DURATION = float(getenv("LOCUST_RAMP_DURATION", "5.0")) # seconds
STABLE_TAIL = int(getenv("LOCUST_STABLE_P99", "25")) # ms
VARIANCE_WINDOW = int(getenv("LOCUST_VARIANCE_WINDOW", "30"))
MAX_VARIANCE = float(getenv("LOCUST_MAX_VARIANCE", "0.3"))

class SlowLoad(LoadTestShape):
    init_users: Final = 1000 # users
    """What is the first target to hit?"""

    init_time: Final = 30 # seconds
    """How long should it take to hit init_users? """

    ramp_duration: Final = RAMP_DURATION
    """How much time do we spend reaching the new user count?
    Affects users spawned per second, but not overall users spawned per ramp."""

    variance_window: Final = VARIANCE_WINDOW
    """When calculating var(p99), we will use this number of past vals to calculate the variance."""

    max_variance: Final = MAX_VARIANCE
    """What is the 30-second window's max variance to be considered stabilized?"""

    stable_alt: Final = 120
    """If we have been at this user count for this long, say we are stabilized anyways."""

    def __init__(self, *args, **kwargs):

        # === User Count vars ===

        self._ramp_speed: float = 0
        """Users per second."""

        self._target: int = self.init_users
        "What number of users are we trying to ramp to?"
        
        self._p99: float = 0
        """tail latency"""

        # === Stabilization algorithm vars ===

        self._history = []
        """Previous n ratios between p99 latency and p50 latency. 
        Once this array is of len(30), we can start using it to calculate the variance.
        If the variance is less than `max_variance`, we can ramp up.
        When we ramp up, we clear the list so it is of size 0 again."""

        self._history_insertion_idx = 0
        """What is the index of `self._med_tail_ratio_history` that we put values into?"""

        self._user_secs = 0
        """How long have we been at this user count?"""

        self._cur_variance = None
        """What is the variance of `self._med_tail_ratio_history`?"""

        super().__init__(*args, **kwargs)
    
    def get_variance_stabilized(self, val: float) -> bool:
        self._user_secs += 1

        if len(self._history) < self.variance_window:
            self._history.append(val)
            self._cur_variance = None
            return False

        if self._user_secs > self.stable_alt:
          return True
        
        self._history[self._history_insertion_idx] = val
        
        self._history_insertion_idx = (self._history_insertion_idx + 1) % self.variance_window

        self._cur_variance = variance(self._history)

        return self._cur_variance <= self.max_variance

    def set_ramp(self, cur_users: int) -> None:
        rate = 0
        if   self._p99 < 50:    rate =  1.15
        elif self._p99 < 75:    rate =  1.125
        elif self._p99 < 100:   rate =  1.110
        elif self._p99 < 125:   rate =  1.100
        elif self._p99 < 150:   rate =  1.075
        elif self._p99 < 200:   rate =  1.050
        elif self._p99 < 250:   rate =  1.025
        elif self._p99 < 300:   rate = -1.025
        else:                   rate = -1.050

        self._target = int(cur_users * rate)
        self._ramp_speed = (self._target - cur_users) / self.ramp_duration
        self._user_secs = 0
        self._history.clear()

    def tick(self) -> Optional[Tuple[int, float]]:
        log_string = ""
        cur_users : int = self.get_current_user_count()

        self._p50: float = self.runner.stats.total.get_current_response_time_percentile(0.50)

        self._p99: float = self.runner.stats.total.get_current_response_time_percentile(0.99)


        if cur_users < self.init_users:
            return self.init_users, self.init_time

        if self._p99 == None:
            self._p99 = 0

        log_string += f"users: {cur_users} \t P50: {self._p50} \t P99: {self._p99}"

        if self.get_variance_stabilized(self._p99):
            self.set_ramp(cur_users)
            log_string += f"stabilized, ramping up."
        else:            
            log_string += f"unstable (var={self._cur_variance})"
            self._target = cur_users
            self._ramp_speed = 10.0

        logging.info(log_string)
        return self._target, self._ramp_speed
