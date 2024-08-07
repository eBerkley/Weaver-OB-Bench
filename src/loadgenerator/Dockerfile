FROM python:3.12.4-slim@sha256:2fba8e70a87bcc9f6edd20dda0a1d4adb32046d2acbca7361bc61da5a106a914 as base

FROM base as builder

COPY requirements.txt .

RUN pip install --prefix="/install" -r requirements.txt

FROM base

WORKDIR /loadgen

COPY --from=builder /install /usr/local

# Add application code.
COPY locustfile.py .
COPY entrypoint.sh .

RUN chmod +x entrypoint.sh

# enable gevent support in debugger
ENV GEVENT_SUPPORT=True

EXPOSE 5557 5558 8089

ENTRYPOINT [ "./entrypoint.sh" ]
# ENTRYPOINT locust --host="http://${FRONTEND_ADDR}" --headless -u "${USERS:-10}" 2>&1
