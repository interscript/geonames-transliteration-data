#!make
SHELL := /bin/bash
GEONAMES_VERSION := 20200106

all: pairs/amh_Ethi2Latn_ALA_1997.csv

data:
	mkdir -p $@

data/geonames.zip: | data
	curl -sL http://geonames.nga.mil/gns/html/cntyfile/geonames_${GEONAMES_VERSION}.zip -o $@

# Touch it once so make considers data/Countries.txt newer than data/geonames.zip.
data/Countries.txt: data/geonames.zip | data
	unzip $< -d data
	touch $@

db:
	mkdir -p $@

db/geonames.db: data/Countries.txt | db
	sqlite3 $@ ".mode tabs" ".import $< countries"

data/geonames_pairs.csv: db/geonames.db | data
	TMPFILE=`mktemp` && \
	FILENAME=$@ envsubst < sql/geonames_pairs.sql.in > $$TMPFILE; \
	sqlite3 $< < $$TMPFILE

db/geonames_pairs.db: data/geonames_pairs.csv | db
	sqlite3 $@ ".mode csv" ".import $< countries"

sql/sequence_system_all.sql:
	echo > $@; \
	for system in `cat data/translit_systems.txt`; do \
		export TRANSLIT_SYSTEM=$$system; \
		envsubst < sql/sequence_system_each.sql.in >> $@; \
	done

pairs:
	mkdir -p $@

pairs/%.csv: db/geonames_pairs.db sql/sequence_system_all.sql | pairs
	sqlite3 $< < sql/sequence_system_all.sql

distclean: clean
	rm -rf data

clean:
	rm -f sql/sequence_system_all.sql
	rm -rf db pairs

.PHONY: all clean distclean

.SECONDARY: data/geonames.zip db/geonames.db db/geonames_pairs.db
