#!make
SHELL := /bin/bash
GEONAMES_VERSION := 20200106

all: pairs/amh_Ethi2Latn_ALA_1997.csv

geonames.zip:
	curl -sL http://geonames.nga.mil/gns/html/cntyfile/geonames_${GEONAMES_VERSION}.zip -o geonames.zip

geonames_${GEONAMES_VERSION}: geonames.zip
	unzip geonames.zip

geonames.db: geonames_${GEONAMES_VERSION}
	sqlite3 ".mode tabs" ".import geonames_${GEONAMES_VERSION}/Countries.txt countries" ".backup geonames.db"

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

clean:
	rm -rf geonames_${GEONAMES_VERSION}

distclean:
	rm -f geonames.zip geonames.db geonames_pairs.csv geonames_pairs.db sequence_system_all.sql
	rm -rf pairs

.PHONY: all clean

.SECONDARY: geonames.zip geonames.db geonames_pairs.db
