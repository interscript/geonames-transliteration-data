#!make
SHELL := /bin/bash

all: pairs/amh_Ethi2Latn_ALA_1997.csv

geonames.db: geonames_20200106.zip
	curl -sL http://geonames.nga.mil/gns/html/cntyfile/geonames_20200106.zip -o geonames_20200106.zip
	unzip geonames_20200106.zip
	sqlite3 ".mode tabs" ".import geonames_20200106/Countries.txt countries" ".backup geonames.db"

geonames_pairs.csv: geonames.db
	sqlite3 geonames.db < geonames_pairs.sql

geonames_pairs.db: geonames_pairs.csv
	sqlite3 ".mode csv" ".import geonames_pairs.csv countries" ".backup geonames_pairs.db"

sequence_system_all.sql:
	echo > sequence_system_all.sql; \
	for system in `cat translit_systems.txt`; do \
		export TRANSLIT_SYSTEM=$$system; \
		envsubst < sequence_system_each.sql.in >> sequence_system_all.sql; \
	done

pairs:
	mkdir -p $@

pairs/%.csv: geonames_pairs.db sequence_system_all.sql | pairs
	sqlite3 geonames_pairs.db < sequence_system_all.sql

.PHONY: watch-$(FORMAT)
