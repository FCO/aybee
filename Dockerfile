FROM    postgres:alpine
COPY    pghashlib /pghashlib
RUN     apk add make gcc libc-dev && cd /pghashlib && make && make install
COPY    *.sql /docker-entrypoint-initdb.d/
VOLUME  /var/lib/postgresql/data
ENV     POSTGRES_USER=aybee
ENV     POSTGRES_PASSWORD=senha
ENV     POSTGRES_DB=aybee
ENV     POSTGRES_ROLE=aybee_postgraphile
