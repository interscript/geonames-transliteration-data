#!make
SHELL := /bin/bash
GNDB_PAGE := https://geonames.nga.mil/gns/html/namefiles.html
GNDB_FILE_PATTERN := cntyfile/geonames_\d*.zip

all: pairs/GNDB_VERSION pairs/amh_Ethi2Latn_ALA_1997.csv

data:
	mkdir -p $@

data/translit_systems.txt: db/geonames.db | data
	sqlite3 $< < sql/translit_systems.sql > $@

data/VERSION: | data
	export GNDB_VERSION=`curl -sSL ${GNDB_PAGE} | sed -n 's/.*geonames_\([0-9]*\)\.zip.*/\1/p'`; \
	echo $$GNDB_VERSION > $@

CHECKDATE_TIMES ?= 1
# Used to check release date of the latest GNDB package
checkdate:
	for ((i=1; i<=$(CHECKDATE_TIMES); i++)); do \
		echo `curl -sSL ${GNDB_PAGE} | sed -n 's/.*geonames_\([0-9]*\)\.zip.*/\1/p'`; \
	done


data/geonames.zip: data/VERSION
	export VERSION=`cat data/VERSION`; \
	curl -sSL \
		https://geonames.nga.mil/gns/html/cntyfile/geonames_$$VERSION.zip \
		-o $@

# Touch it once so make considers data/Countries.txt newer than data/geonames.zip.
data/Countries.txt: data/geonames.zip | data
	unzip $< -d data
	touch $@

db:
	mkdir -p $@

# The GeoNames database contains text fields with single double quotes,
# they need to be escaped prior to import.
# https://stackoverflow.com/questions/15212489/sqlite3-import-with-quotes
data/Countries.quoted.txt: data/Countries.txt
	sed $$'s/"/""/g;s/[^\t]*/"&"/g' $< > $@

db/geonames.db: data/Countries.quoted.txt | db
	sqlite3 $@ '.mode csv' '.separator "\t"' ".import $< countries"

data/geonames_pairs.csv: db/geonames.db | data
	TMPFILE=`mktemp` && \
	FILENAME=$@ envsubst < sql/geonames_pairs.sql.in > $$TMPFILE; \
	sqlite3 $< < $$TMPFILE

db/geonames_pairs.db: data/geonames_pairs.csv | db
	sqlite3 $@ ".mode csv" ".import $< countries"

sql/sequence_system_all.sql: data/translit_systems.txt
	echo > $@; \
	for system in `cat data/translit_systems.txt`; do \
		export TRANSLIT_SYSTEM=$$system; \
		envsubst < sql/sequence_system_each.sql.in >> $@; \
	done

pairs:
	mkdir -p $@

pairs/GNDB_VERSION: data/VERSION | pairs
	cp -f $< $@

pairs/%.csv: db/geonames_pairs.db sql/sequence_system_all.sql | pairs
	sqlite3 $< < sql/sequence_system_all.sql

pairs.zip: pairs/GNDB_VERSION pairs/amh_Ethi2Latn_ALA_1997.csv
	zip -j $@ pairs/*

distclean: clean
	rm -rf data

clean:
	rm -f data/Countries.quoted.txt sql/sequence_system_all.sql data/geonames_pairs.csv
	rm -rf db pairs

.PHONY: all clean distclean checkdate

.SECONDARY: data/geonames.zip db/geonames.db db/geonames_pairs.db
