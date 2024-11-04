from locust import LoadTestShape

class DummyLoad(LoadTestShape):
  def __init__(self):
    super().__init__()
  
  def tick(self) -> tuple[int, float]:
    return 0, 1