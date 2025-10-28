from locust import HttpUser, task, between, LoadTestShape
import math

class TrafficSurgeShape(LoadTestShape):
    """
    A load test shape that simulates traffic surges at specific times
    
    This creates a realistic pattern:
    - Baseline traffic
    - Gradual ramp up
    - Peak surge
    - Gradual ramp down
    - Return to baseline
    """
    
    # Configuration
    baseline_users = 10
    peak_users = 200
    surge_start_time = 300  # 5 minutes
    surge_duration = 600    # 10 minutes
    ramp_duration = 120     # 2 minutes
    
    def tick(self):
        """
        Returns a tuple (user_count, spawn_rate) or None to stop the test
        """
        run_time = self.get_run_time()
        
        if run_time < self.surge_start_time:
            # Baseline period
            return (self.baseline_users, 1)
        
        elif run_time < self.surge_start_time + self.ramp_duration:
            # Ramp up period
            progress = (run_time - self.surge_start_time) / self.ramp_duration
            user_count = int(self.baseline_users + (self.peak_users - self.baseline_users) * progress)
            return (user_count, 5)
        
        elif run_time < self.surge_start_time + self.ramp_duration + self.surge_duration:
            # Peak surge period
            return (self.peak_users, 5)
        
        elif run_time < self.surge_start_time + self.ramp_duration * 2 + self.surge_duration:
            # Ramp down period
            progress = (run_time - self.surge_start_time - self.ramp_duration - self.surge_duration) / self.ramp_duration
            user_count = int(self.peak_users - (self.peak_users - self.baseline_users) * progress)
            return (user_count, 5)
        
        elif run_time < self.surge_start_time + self.ramp_duration * 2 + self.surge_duration + 300:
            # Return to baseline
            return (self.baseline_users, 1)
        
        else:
            # Stop the test
            return None


class SinusoidalTrafficShape(LoadTestShape):
    """
    Simulates cyclical traffic patterns using a sine wave
    Useful for testing auto-scaling over longer periods
    """
    
    min_users = 10
    max_users = 150
    cycle_duration = 900  # 15 minutes per cycle
    total_duration = 3600  # 1 hour total
    
    def tick(self):
        run_time = self.get_run_time()
        
        if run_time > self.total_duration:
            return None
        
        # Calculate user count using sine wave
        progress = (run_time % self.cycle_duration) / self.cycle_duration
        user_count = int(
            self.min_users + 
            (self.max_users - self.min_users) * 
            (math.sin(2 * math.pi * progress) + 1) / 2
        )
        
        return (user_count, 3)


class StepLoadShape(LoadTestShape):
    """
    Creates step-wise load increases to test scaling thresholds
    """
    
    step_time = 180  # 3 minutes per step
    step_load = 25    # Increase by 25 users each step
    start_users = 10
    max_users = 200
    
    def tick(self):
        run_time = self.get_run_time()
        
        step = int(run_time / self.step_time)
        user_count = min(self.start_users + step * self.step_load, self.max_users)
        
        if user_count >= self.max_users and run_time > self.step_time * 10:
            return None
        
        return (user_count, 2)


class FlashSaleShape(LoadTestShape):
    """
    Simulates a flash sale event with sudden spike in traffic
    """
    
    baseline_users = 20
    flash_sale_users = 300
    flash_sale_start = 300    # Flash sale starts at 5 minutes
    flash_sale_duration = 180  # Lasts 3 minutes
    total_test_time = 900      # 15 minutes total
    
    def tick(self):
        run_time = self.get_run_time()
        
        if run_time > self.total_test_time:
            return None
        
        if self.flash_sale_start <= run_time < self.flash_sale_start + self.flash_sale_duration:
            # Flash sale period - sudden spike
            return (self.flash_sale_users, 20)
        elif run_time >= self.flash_sale_start + self.flash_sale_duration and run_time < self.flash_sale_start + self.flash_sale_duration + 60:
            # Immediate drop after flash sale
            return (self.baseline_users, 10)
        else:
            # Normal baseline traffic
            return (self.baseline_users, 1)
