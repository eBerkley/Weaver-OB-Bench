from locust import LoadTestShape
from typing import Tuple, Optional, List, Final

import logging

from os import getenv

from statistics import variance

WAIT_TIME = int(getenv("LOCUST_WAIT_TIME", "30")) # seconds
RAMP_DURATION = float(getenv("LOCUST_RAMP_DURATION", "5.0")) # seconds
VARIANCE_WINDOW = int(getenv("LOCUST_VARIANCE_WINDOW", "30"))
MAX_VARIANCE = float(getenv("LOCUST_MAX_VARIANCE", "0.3"))
MAX_TAIL = int(getenv("LOCUST_MAX_TAIL", 200))
USERS_ADDED = int(getenv("LOCUST_SLOWLOAD_RAMP", 750))

class SlowLoad(LoadTestShape):
    init_users: Final = USERS_ADDED*15 # users
    """What is the first target to hit?"""

    init_time: Final = RAMP_DURATION*200 # seconds
    """How long should it take to hit init_users? """

    max_tail: Final = MAX_TAIL # ms
    """When p99 latency >= this value, consider it violating."""

    ramp_duration: Final = RAMP_DURATION
    """How much time do we spend reaching the new user count?
    Affects users spawned per second, but not overall users spawned per ramp."""

    variance_window: Final = VARIANCE_WINDOW
    """When calculating var(p99), we will use this number of past vals to calculate the variance."""

    max_variance: Final = MAX_VARIANCE
    """What is the 30-second window's max variance to be considered stabilized?"""

    stable_alt: Final = 35
    """If we have been at this user count for this long, say we are stabilized anyways."""

    def __init__(self, *args, **kwargs):

        # === User Count vars ===

        self._ramp_speed: float = 0
        """Users per second."""

        self._slo_timer: int = WAIT_TIME
        """Timer that decreases during violation period. 
        If it hits 0, terminate test."""

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
        self._target = cur_users + USERS_ADDED
        self._ramp_speed = USERS_ADDED / self.ramp_duration
        self._user_secs = 0
        self._history.clear()

    def tick(self) -> Optional[Tuple[int, float]]:
        log_string = ""
        cur_users : int = self.get_current_user_count()

        self._p50: float = self.runner.stats.total.get_current_response_time_percentile(0.50)

        self._p99: float = self.runner.stats.total.get_current_response_time_percentile(0.99)


        if cur_users < self.init_users:
            return self.init_users, float(self.init_users) / self.init_time

        if self._p99 == None:
            self._p99 = 0

        if self._slo_timer <= 0:
            return None

        log_string += f"users: {cur_users} \t P50: {self._p50} \t P99: {self._p99} \t SLO: {self._slo_timer} "

        if self._p99 > self.max_tail:
            log_string += f"SLO Vioilating..."
            self._slo_timer -= 1
            self._target = cur_users
            self._ramp_speed = 10.0

        elif self.get_variance_stabilized(self._p99):
            self._slo_timer = WAIT_TIME
            self.set_ramp(cur_users)
            log_string += f"stabilized, ramping up."
            
        else:
            self._slo_timer = WAIT_TIME
            log_string += f"unstable (var={self._cur_variance})"
            self._target = cur_users
            self._ramp_speed = 10.0

        logging.info(log_string)
        return self._target, self._ramp_speed
