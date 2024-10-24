from locust import LoadTestShape
from typing import Tuple, Optional, List
import logging
class MultiLoad(LoadTestShape):
    """
    A step load shape
    Keyword arguments:
        
        step_time       -- Time between steps
        step_load       -- User increase amount at each step
        spawn_rate      -- Users to stop/start per second at every step
        num_steps       -- When to terminate
    """
    
    # Time between steps
    step_time = 12 * 60 # 12 minutes
    
    # Users at each step
    step_load = [1000, 2500, 5000, 7500, 10000, 12500, 15000, 17500, 20000, 25000, 30000]
    # Users to stop/start per second while amount is changing.
    spawn_rate = 5
    # When to terminate
    num_steps = len(step_load)
    def __init__(self, *args, **kwargs):
        self._step = 0
        self._target_timestamp = 0
        super().__init__(*args, **kwargs)
    def tick(self) -> Optional[Tuple[int, float]]:
        cur_users = self.get_current_user_count()
        cur_time = self.get_run_time()
        target_users = self.step_load[self._step]
        out_str = f"users: {cur_users}/{target_users}"
        
        # if we are done spawning
        if cur_users == target_users:
            # if we *just* reached target
            if self._target_timestamp == 0:
                # start timer
                self._target_timestamp = cur_time 
            else:
                elapsed = cur_time - self._target_timestamp
                # out_str += f"\t time remaining: {self.step_time[self._step] - elapsed:.2f}"
                out_str += f"\t time remaining: {self.step_time - elapsed:.2f}"
                # logging.info(f"elapsed: {elapsed}\n")
                # if time has gone on long enough
                if elapsed >= self.step_time:
                    self._target_timestamp = 0
                    self._step += 1
                    
                    if self._step == self.num_steps:
                        return None
        logging.info(out_str)
        return target_users, self.spawn_rate
