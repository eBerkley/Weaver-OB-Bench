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
MAX_TAIL = float(getenv("LOCUST_MAX_TAIL", "150")) # ms

class StableRampLoad(LoadTestShape):
    """
    
    A load generator shape that will ramp up user generation speed to lower test duration, up until a point in which latency is high enough that it indicates that we may want to start collecting statistics.

    Keyword arguments:

        init_users      --  What is the first target to hit? Required since otherwise 
                            ramp_change will always initialize to 0.

        init_time       --  How long should it take to hit init_users? 
                            Note, will not be honored if it would require more than 100
                            users to be generated per second.

        max_tail        --  When p99 latency >= this value, consider it violating.

        ramp_pause      --  When we reach a user count we were ramping to, 
                            how long do we wait before resuming?

        ramp_duration   --  How much time do we spend reaching the new user count?
                            Affects users spawned per second, but not overall users spawned per ramp.
    """

    init_users: Final = 1000 # users
    """What is the first target to hit?"""

    init_time: Final = 30 # seconds
    """How long should it take to hit init_users? """

    max_tail: Final = MAX_TAIL # ms
    """When p99 latency >= this value, consider it violating."""

    ramp_duration: Final = RAMP_DURATION
    """How much time do we spend reaching the new user count?
    Affects users spawned per second, but not overall users spawned per ramp."""

    stable_tail: Final = STABLE_TAIL
    """While p99 latency is less than this value, we can accelerate scaling to avoid wasting time.
    When it becomes greater, we DRASTICALLY lower ramp speed to aid in stabilizing latency calculations."""

    variance_window: Final = VARIANCE_WINDOW
    """When calculating the ratio of p99 / p50, we will use this number of past ratios to calculate the variance."""

    max_variance: Final = MAX_VARIANCE
    """What is the 30-second window's max variance to be considered stabilized?"""

    stable_alt: Final = 120
    """If we have been at this user count for this long, say we are stabilized anyways."""

    sustainable_granularity: Final = 1000
    """When #users is sustainable, and within `sustainable_granularity`
    users from a value we know to be unsustainable, 
    we consider #users as the maximum sustainable number of users.

    We then terminate the test."""

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

        self._stabilizing: bool = False
        "have we started ramping slow?"

        self._history = []
        """Previous 30 ratios between p99 latency and p50 latency. 
        Once this array is of len(30), we can start using it to calculate the variance.
        If the variance is less than `max_variance`, we can ramp up.
        When we ramp up, we clear the list so it is of size 0 again."""

        self._history_insertion_idx = 0
        """What is the index of `self._med_tail_ratio_history` that we put values into?"""

        self._user_secs = 0
        """How long have we been at this user count?"""

        self._cur_variance = None
        """What is the variance of `self._med_tail_ratio_history`?"""

        # === Converging algorithm vars ===
        self._converging: bool = False
        """Have we found an unsustainable user count?
        When this is True, use a binary search algorithm to approach a max sustainable user count."""

        self._prev_sustainable_users: int = 0
        """If we find that the current user count is sustainable,
        set `self._prev_sustainable_users = cur_users`.
        If we find that the current user count is actually unsustainable, 
        decrease user count back down to `(cur_users + self._prev_sustainable_users) / 2`."""

        self._prev_unsustainable_users: int = 0
        """If we find that the current user count is unsustainable,
        set `self._prev_unsustainable_users = cur_users`.
        If we find that the current user count is actually sustainable, AND we are converging, 

        IF `self._prev_unsustainable_users - cur_users < self.sustainable_granularity`:
            end test
        ELSE:
            increase user count back up to `(cur_users + self._prev_unsustainable_users) / 2`."""

        super().__init__(*args, **kwargs)
    
    # placeholder
    def is_sustainable(self) -> bool:
        if len(self._history) > self.variance_window / 2:
            return True
        return True

        
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
        rate = 1.125
        if self._stabilizing:
          if   self._p99 < 5:   rate = 1.115
          elif self._p99 < 10:  rate = 1.100
          elif self._p99 < 20:  rate = 1.085
          elif self._p99 < 30:  rate = 1.075
          elif self._p99 < 40:  rate = 1.060
          elif self._p99 < 50:  rate = 1.050
          elif self._p99 < 60:  rate = 1.040
          elif self._p99 < 70:  rate = 1.030
          elif self._p99 < 80:  rate = 1.020
          elif self._p99 < 90:  rate = 1.015
          elif self._p99 < 100: rate = 1.010
          elif self._p99 < 125: rate = 1.006
          else:                 rate = 1.005
        
        self._target = int(cur_users * rate)
        self._ramp_speed = (self._target - cur_users) / self.ramp_duration
        self._user_secs = 0 # reset timer
        self._history.clear() # So we can have all new vals again.

    
    def tick(self) -> Optional[Tuple[int, float]]:
        log_string = ""
        cur_users: int = self.get_current_user_count()
        self._p50: float = self.runner.stats.total.get_current_response_time_percentile(0.50)
        self._p99: float = self.runner.stats.total.get_current_response_time_percentile(0.99)

        if cur_users < self.init_users:
            return self.init_users, self.init_time

        if self._p99 == None:
            self._p99 = 0


        if self._p99 > self.stable_tail:
            self._stabilizing = True

        if self._slo_timer <= 0:
            return None

        ratio = self._p99 / self._p50
        
        log_string += f"SLO Timer: {self._slo_timer} \t P50: {self._p50} \t P99: {self._p99}\t ratio: {ratio} \t users: {cur_users}. \t "

        if not self._stabilizing:
            log_string += "not stabilizing, ramping up."
            self.set_ramp(cur_users)

        elif self._p99 > self.max_tail:
            log_string += f"SLO Violating!"
            self._slo_timer -= 1
            self._target = cur_users
            self._ramp_speed = 10.0

        else:
            self._slo_timer = WAIT_TIME
            #if self.get_variance_stabilized(ratio): # if we are stabilized, ramp up
            if self.get_variance_stabilized(self._p99): # if we are stabilized, ramp up
                self.set_ramp(cur_users)
                log_string += f"stabilized (var={self._cur_variance}), ramping up."
            
            else:
                log_string += f"unstable (var={self._cur_variance}), holding."
                self._target = cur_users
                self._ramp_speed = 10.0
                
        logging.info(log_string)
        return self._target, self._ramp_speed