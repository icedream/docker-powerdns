# docker-powerdns
PowerDNS docker container, based on Debian Trixie.

## Docker Compose Example

Save the following snippet as docker-compose.yaml in any folder you like, or clone this repository, which contains a sample docker-compose.yml.

```
services:
  pdns:
    image: ghcr.io/icedream/powerdns:latest-mysql
    ports:
      - "53:53"
      - "53:53/udp"
      - "8088:8081"
    environment:
      - PDNSCONF_API_KEY=a_strong_api_key
      - PDNSCONF_GMYSQL_HOST=mysql
      - PDNSCONF_GMYSQL_USER=pdns
      - PDNSCONF_GMYSQL_DBNAME=pdns
      - PDNSCONF_GMYSQL_PASSWORD=pdnspw
  mysql:
    image: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=mysqlrootpw
      - MYSQL_DATABASE=pdns
      - MYSQL_USER=pdns
      - MYSQL_PASSWORD=pdnspw
```

For PostgreSQL, use image `ghcr.io/icedream/powerdns:latest-pgsql` instead.

## Environment Variables Supported

Any setting from https://doc.powerdns.com/authoritative/settings.html is supported. Just add the prefix "PDNSCONF\_" and replace any hyphens (-) with underscore (\_). Example: 

``` allow-axfr-ips ===> PDNSCONF_ALLOW_AXFR_IPS ```

### Additional Environment Variables:

 - SECALLZONES_CRONJOB: If set to 'yes', a Cron Job every half hour checks if any domain is not DNSSEC enabled. If so, it enables DNSSEC for that zone and fixes any DS records in parent zones hosted in the same server.

## Clustering

You can easily enable PowerDNS native "slaves" with bitnami/mariadb docker image. 
See <https://hub.docker.com/r/bitnami/mariadb>

## Running

```
cd <folder where docker-compose.yaml is>
docker compose up -d
```

## Building

### MySQL

To build the MySQL-compatible version of this image, simply leave all build arguments at their default.

```
docker build pdns
```

### PostgreSQL

To build the PostgreSQL-compatible version of this image, override the backend packages to be installed like this:

```
docker build --build-arg "PDNS_BACKEND_PACKAGES=pdns-backend-pgsql postgresql-client" --build-arg PDNSCONF_LAUNCH=pgsql pdns
```

## Different PowerDNS Auth versions

You can specify which version/branch of PowerDNS Auth to use for building the Docker image via the `PDNS_AUTH_VERSION` build arg:

```
docker build --build-arg "PDNS_AUTH_VERSION=4.8" -t localhost/pdns:4.8 pdns
docker build --build-arg "PDNS_AUTH_VERSION=4.7" -t localhost/pdns:4.7 pdns
```

## Different Debian version

You can specify which tag of the Debian base image to use for building the Docker image via the `DEBIAN_TAG` (default `12`) and `DEBIAN_TAG_SUFFIX` (default `-slim`) build arg:

```
docker build --build-arg "DEBIAN_TAG=bookworm" -t localhost/pdns:4.8-debian12-slim pdns
docker build --build-arg "DEBIAN_TAG=11" -t localhost/pdns:4.7-debian11-slim pdns
docker build --build-arg "DEBIAN_TAG=11" --build-arg "DEBIAN_TAG_SUFFIX=" -t localhost/pdns:4.7-debian11 pdns
```

## Contributing

Pull requests welcome!
