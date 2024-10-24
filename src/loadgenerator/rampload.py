from locust import LoadTestShape
from typing import Tuple, Optional, List
import locust.stats

import logging

WAIT_TIME = 30

class RampLoad(LoadTestShape):
    """
    
    A load generator shape that will ramp up user generation speed to lower test duration, as well as respond to high latency by ending the test early.

    Keyword arguments:

        init_target_users       --  What is the first target to hit? Required since otherwise 
                                    ramp_change will always initialize to 0.

        init_target_time        --  How long should it take to hit init_target_users? 
                                    Note, will not be honored if it would require more than 100
                                    users to be generated per second.

        ramp_hold               --  When we do hit the target user count for this iteration, how
                                    long do we wait before starting to generate more users? 

        ramp_time               --  What is our goal for how fast to hit the next user count? 
                                    Note, will not be honored if it would require more than 100
                                    users to be generated per second.

        ramp_check_frequency    --  How frequently, in seconds, should violations be checked 
                                    while *ramping*?  While holding, will always be 1 time per
                                    second.

        ramp_change             --  When ramping up, next users is set to 
                                    current users * (ramp_change + 1).

        violation_factor        --  If p50 latency * violation_factor > p99 latency, 
                                    trigger a violation.

    """
    init_target_users = 300 # users
    """What is the first target to hit?"""

    init_target_time = 30 # seconds
    """How long should it take to hit init_target_users? """
    
    ramp_hold = 30 # seconds
    """How long do we wait and collect metrics after hitting a target?"""

    ramp_time = 10 # seconds
    """Over what timespan do we hit target?"""

    ramp_check_frequency = 10 # seconds
    """While ramping, how often do we check if we are violating?"""

    ramp_change = 0.05 # percent
    """What % do we increase by?"""

    violation_factor = 5 # 
    """when p99 latency / p50 latency hits this val, break."""    

    def __init__(self, *args, **kwargs):
        self._holding = False
        """False: Increasing users.  
        True: Getting metrics."""

        self._cur_target_users = self.init_target_users
        self._ramp_speed = self.init_target_users / self.init_target_time

        # Used when holding.
        self._cur_target_time_change = self.ramp_hold
        self._cur_target_time = 0 # self.init_target_time
        """when == cur_time, stop holding. """

        self._slo_timer = WAIT_TIME
        
        self._num_ramp_phases = self.init_target_time // self.ramp_check_frequency
        
        increase_per_phase = self._cur_target_users / self._num_ramp_phases

        # len(self._phases) == self._ramp_phases
        self._phases = [x for x in range(
            int(0 + increase_per_phase), 
            int(self._cur_target_users + increase_per_phase),
            int(increase_per_phase)
        )]         
        self._cur_phase = 0 # should be less than self._ramp_phases

        super().__init__(*args, **kwargs)
        self._transition = 0
        self._pausing = False
        self._ever_paused = False
    

    def isViolating(self) -> bool:
        if self.runner == None:
            logging.error("RampLoad.runner == None...")
            return False # Assume that it will populate soon.

        self._p50 = self.runner.stats.total.get_response_time_percentile(0.50)
        self._p99 = self.runner.stats.total.get_response_time_percentile(0.99)

        if self._p50 * self.violation_factor < self._p99:
            return True
        
        return False
    
    """
    def getNextTargetInfo(self, cur_users: int):
        next_target = int(cur_users * (self.ramp_change + 1))
        users_to_add = next_target - cur_users
        
        # in users/sec
        ramp_rate = users_to_add // self.ramp_time 
        ramp_rate = min(ramp_rate, 100) # max ramp, enforced by locust
        
        # if time_change > self.ramp_time, ramp_rate > 100.
        time_change = users_to_add // ramp_rate

        # start setting variables for ramping

        self._cur_target_users = next_target
        self._ramp_speed = ramp_rate
        self._num_ramp_phases = time_change // self.ramp_check_frequency
        increase_per_phase = users_to_add // self._num_ramp_phases
        self._phases = [x for x in range( # range: [start, stop) --> (start, stop]
            cur_users + increase_per_phase, 
            next_target + increase_per_phase,
            increase_per_phase)
        ]
        self._cur_phase = 0
        return 
    """
        
    def tick(self) -> Optional[Tuple[int, float]]:
        cur_users = self.get_current_user_count()
        self._p99 = self.runner.stats.total.get_current_response_time_percentile(0.99)
        if self._p99 == None:
            self._p99 = 0
        if self._p99 < 100:
            self._slo_timer = WAIT_TIME

        logging.info(f"SLO Timer: {self._slo_timer}")
        logging.info(f"P99: {self._p99}")
        if self._slo_timer < 0:
            return None

        if cur_users < 1000:
            return 1000, 20.0

        if self._transition <= 0: #transition now
            logging.info("RampLoad: Checking.")
            # Violating SLO while paused for 30 seconds
            if self._pausing and self._slo_timer < WAIT_TIME/2:
                return None

            self._pausing = self._slo_timer != WAIT_TIME

            if self._pausing:
                self._slo_timer = WAIT_TIME
                logging.error("RampLoad: Pausing.")
                self._transition = WAIT_TIME
                self._target = cur_users
                self._ramp_speed = 10.0 #must be greater than 0
                self._ever_paused = True
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
                logging.info(f"RampLoad: P99: {self._p99}, Rate: {rate}")
                self._transition = 5
                self._target = int(cur_users * rate)
                self._ramp_speed = (self._target - cur_users) / 5.0


        self._transition -= 1
        self._slo_timer -= 1
        return self._target, self._ramp_speed



