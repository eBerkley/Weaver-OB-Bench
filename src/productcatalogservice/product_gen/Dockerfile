FROM bitnami/mongodb-sharded:8.0.13-debian-12-r0
ARG BASE_DIR

WORKDIR /build/init

COPY ${BASE_DIR}/products products

COPY ${BASE_DIR}/product_gen/init.js .
COPY ${BASE_DIR}/product_gen/scripts/* .

ENTRYPOINT [ "./init.sh" ]