FROM ubuntu:16.04

MAINTAINER Andrey S. Kamakin

# Обвновление списка пакетов
RUN apt-get -y update

#
# Установка postgresql
#
ENV PGVER 9.5
RUN apt-get install -y postgresql-$PGVER

# Run the rest of the commands as the ``postgres`` user created by the ``postgres-$PGVER`` package when it was ``apt-get installed``
USER postgres

# Create a PostgreSQL role named ``docker`` with ``docker`` as the password and
# then create a database `docker` owned by the ``docker`` role.
ADD /testdata/data.gz /tmp/
RUN /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
    createdb -E UTF8 -T template0 -O docker docker &&\
    gunzip -c /tmp/data.gz | psql docker &&\
    /etc/init.d/postgresql stop

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PGVER/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/$PGVER/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/$PGVER/main/postgresql.conf
RUN echo "synchronous_commit = off" >> /etc/postgresql/$PGVER/main/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

# Back to the root user
USER root

#datadog
RUN apt-get install -y apt-transport-https
RUN sh -c "echo 'deb https://apt.datadoghq.com/ stable main' > /etc/apt/sources.list.d/datadog.list"
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C7A7DA52
RUN apt-get -y update
RUN apt-get install -y datadog-agent
RUN sh -c "sed 's/api_key:.*/api_key: 60507f518353c8620812eabac5650aca/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"

#
# Сборка проекта
#

# Установка JDK
RUN apt-get install -y openjdk-8-jdk-headless
RUN apt-get install -y maven

# Копируем исходный код в Docker-контейнер
ENV WORK /opt/server
ADD server/db_api/ $WORK/db_api/

# Собираем и устанавливаем пакет
WORKDIR $WORK/db_api
RUN mvn package

# Объявлем порт сервера
EXPOSE 80

#
# Запускаем PostgreSQL и сервер
#
CMD service postgresql start && /etc/init.d/datadog-agent start && java -Xms256M -Xmx512M -jar $WORK/db_api/target/DB_Project-1.0-SNAPSHOT.jar
