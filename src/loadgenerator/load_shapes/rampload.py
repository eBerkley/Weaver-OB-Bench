from locust import LoadTestShape
from typing import Tuple, Optional, List, Final

import logging

from os import getenv

WAIT_TIME = int(getenv("LOCUST_WAIT_TIME", "30"))
RAMP_DURATION = float(getenv("LOCUST_RAMP_DURATION", "5.0")) # seconds
MAX_TAIL = float(getenv("LOCUST_MAX_TAIL", "150")) # ms

class RampLoad(LoadTestShape):
    """
    
    A load generator shape that will ramp up user generation speed to lower test duration, as well as respond to high latency by ending the test early.

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

    ramp_pause: Final = 10 # seconds
    """When we reach a user count we were ramping to, how long do we wait before resuming?"""

    ramp_duration: Final = RAMP_DURATION # seconds
    """How much time do we spend reaching the new user count?
    Affects users spawned per second, but not overall users spawned per ramp."""

    def __init__(self, *args, **kwargs):

        self._ramp_speed: int = 0
        """Users per second."""

        self._slo_timer: int = WAIT_TIME
        """Timer that decreases during violation period. 
        If it hits 0, terminate test."""
        
        self._transition: int = 0
        """Timer that decreases during both violation period and between phases. When it hits 0, we start the next phase."""

        self._pausing: bool = False
        "Are we waiting for p99 latency to dip back below 100?"
        
        self._ever_paused: bool = False
        """Has self._pausing ever been True?"""

        self._p99: int = 0
        """tail latency"""

        super().__init__(*args, **kwargs)
    
    
    def tick(self) -> Optional[Tuple[int, float]]:
        log_string = ""
        cur_users = self.get_current_user_count()
        self._p50 = self.runner.stats.total.get_current_response_time_percentile(0.50)
        self._p99 = self.runner.stats.total.get_current_response_time_percentile(0.99)

        if cur_users < self.init_users:
            return self.init_users, self.init_time

        if self._p99 == None:
            self._p99 = 0
        
        if self._p99 < self.max_tail:
            self._slo_timer = WAIT_TIME

        elif self._slo_timer < 0:
            return None

        log_string += f"SLO Timer: {self._slo_timer} \t P50: {self._p50} \t P99: {self._p99}\t self._transition: {self._transition} \t users: {cur_users} \t "

        if self._transition <= 0: #transition now
            log_string += "RampLoad: Checking.\t"

            # Violating SLO while paused for 30 seconds
            if self._pausing and self._slo_timer <= 0: # WAIT_TIME/2:
                return None

            self._pausing = self._slo_timer != WAIT_TIME

            if self._pausing:
                log_string += "RampLoad: Pausing.\t"
                self._ever_paused = True
                self._slo_timer = WAIT_TIME
                self._transition = WAIT_TIME
                self._target = cur_users
                self._ramp_speed = 10.0 #must be greater than 0

            else:
                if self._p99 < 25 and not self._ever_paused:
                    rate = 1.2
                elif self._p99 < 40 and not self._ever_paused:
                    rate = 1.1
                elif self._p99 < 75:
                    rate = 1.05
                elif self._p99 < 90:
                    rate = 1.02
                else:
                    rate = 1.01

                log_string += f"Rate: {rate}\t"
                self._transition = self.ramp_pause
                self._target = int(cur_users * rate)
                self._ramp_speed = (self._target - cur_users) / self.ramp_duration


        self._transition -= 1
        self._slo_timer -= 1
        logging.info(log_string)
        return self._target, self._ramp_speed
