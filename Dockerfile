FROM    postgres:alpine
COPY    *.sql /docker-entrypoint-initdb.d/
VOLUME  /var/lib/postgresql/data
ENV     POSTGRES_USER=aybee
ENV     POSTGRES_PASSWORD=senha
ENV     POSTGRES_DB=aybee
ENV     POSTGRES_ROLE=aybee_postgraphile
