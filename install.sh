exit

# install all software
wget -O - https://deb.openbuildingmap.org/archive.key | apt-key add -
wget -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
echo "deb https://deb.openbuildingmap.org/ buster main" | tee /etc/apt/sources.list.d/pgdg.list
apt update
apt -y install gnupg2 gdal-bin apache2 build-essential autoconf apache2-dev libcairo2-dev libcurl4-gnutls-dev libiniparser-dev libmapnik-dev libapache2-mod-tile renderd postgresql-13-postgis-3

# start postgress
pg_ctlcluster 13 main start
pg_ctlcluster 13 main status




# get repo
sudo su - postgres

git clone https://github.com/MichaelKreil/pianoforte.git
cd pianoforte

# prepare table
createuser --no-superuser --no-createrole --createdb tilery
createdb -E UTF8 -O tilery tilery
psql tilery -c "CREATE EXTENSION IF NOT EXISTS postgis"
echo "ALTER USER tilery WITH PASSWORD 'tilery';" | psql -d tilery

# download planet
wget https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf

# install imposm
#curl -L "https://github.com/omniscale/imposm3/releases/download/v0.11.1/imposm-0.11.1-linux-x86-64.tar.gz" | gzip -d > imposm.tar
mkdir imposm
curl -L "https://github.com/omniscale/imposm3/releases/download/v0.11.1/imposm-0.11.1-linux-x86-64.tar.gz" | tar -zxf - -C imposm --strip-components=1
#rm imposm-0.11.1-linux-x86-64.tar
#mv imposm-0.11.1-linux-x86-64 imposm

imposm/imposm import -config ./imposm.conf -read planet-latest.osm.pbf
imposm/imposm import -config ./imposm.conf -write


# https://github.com/tilery/mae-boundaries?????


# add city names

wget https://raw.githubusercontent.com/tilery/mae-boundaries/master/city.csv
ogr2ogr --config PG_USE_COPY YES -lco GEOMETRY_NAME=geometry -lco DROP_TABLE=IF_EXISTS -f PGDump city.sql city.csv -select name,'name:en','name:fr','name:ar',capital,type,prio,ldir -nln city -oo X_POSSIBLE_NAMES=Lon* -oo Y_POSSIBLE_NAMES=Lat* -oo KEEP_GEOM_COLUMNS=NO -a_srs EPSG:4326
psql -d tilery --file city.sql

# add index

psql -d tilery -c "CREATE INDEX IF NOT EXISTS idx_road_label ON osm_roads USING GIST(geometry) WHERE name!='' OR ref!=''"
psql -d tilery -c "CREATE INDEX IF NOT EXISTS idx_boundary_low ON osm_admin USING GIST(geometry) WHERE admin_level IN (3, 4)"

# config mod_tile
nano /etc/renderd.conf
   [fortede]
   URI=/fortede/
   TILEDIR=/root/hitzeinseln_data/data/tmptiles
   XML=/srv/tilery/pianoforte/fortede.xml
   HOST=localhost
   TILESIZE=256
   MAXZOOM=20
   CORS=*
   
   [fortede2x]
   URI=/fortede@2x/
   TILEDIR=/root/hitzeinseln_data/data/tmptiles
   XML=/srv/tilery/pianoforte/fortede.xml
   HOST=localhost
   TILESIZE=512
   SCALE=2
   MAXZOOM=20
   CORS=*
   
   [pianode]
   URI=/pianode/
   TILEDIR=/root/hitzeinseln_data/data/tmptiles
   XML=/srv/tilery/pianoforte/pianode.xml
   HOST=localhost
   TILESIZE=256
   MAXZOOM=20
   CORS=*
   
   [pianode2x]
   URI=/pianode@2x/
   TILEDIR=/root/hitzeinseln_data/data/tmptiles
   XML=/srv/tilery/pianoforte/pianode.xml
   HOST=localhost
   TILESIZE=512
   SCALE=2
   MAXZOOM=20
   CORS=*
renderd -f
















# add boundary.json
wget "http://nuage.yohanboniface.me/boundary.json"
ogr2ogr --config PG_USE_COPY YES -lco GEOMETRY_NAME=geometry -lco DROP_TABLE=IF_EXISTS -f PGDump boundary.sql /path/to/boundary.json -sql 'SELECT name,"name:en","name:fr","name:ar","name:es","name:de","name:ru",iso FROM boundary' -nln itl_boundary
psql -d tilery --file /path/to/boundary.sql





wget https://osmdata.openstreetmap.de/download/simplified-land-polygons-complete-3857.zip
unzip simplified-land-polygons-complete-3857.zip
wget https://osmdata.openstreetmap.de/download/land-polygons-split-3857.zip
unzip land-polygons-split-3857.zip