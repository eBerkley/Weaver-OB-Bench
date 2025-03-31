FROM python:3.12.4-slim@sha256:2fba8e70a87bcc9f6edd20dda0a1d4adb32046d2acbca7361bc61da5a106a914 AS base
FROM base AS builder

RUN apt-get update -y && \
  apt-get install --no-install-recommends -y -q \
  git libpq-dev python-dev-is-python3 build-essential libsnappy-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


COPY requirements.txt .

RUN pip install --prefix="/install" -r requirements.txt

FROM base

RUN apt-get update && \ 
  apt-get install -y procps && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /loadgen

COPY --from=builder /install /usr/local

# Add application code.
COPY locustfile.py .
COPY entrypoint.sh .

COPY load_shapes/rampload.py .
COPY load_shapes/dummyload.py .
COPY load_shapes/constload.py .
COPY load_shapes/slowload.py .
COPY load_shapes/stable_rampload.py .
COPY load_shapes/scaleload.py .
COPY load_shapes/testload.py .
COPY load_shapes/slo_rampload.py .
COPY load_shapes/slowerload.py .

RUN chmod +x entrypoint.sh

# enable gevent support in debugger
ENV GEVENT_SUPPORT=True

EXPOSE 5557 5558 8089

ENTRYPOINT [ "./entrypoint.sh" ]

