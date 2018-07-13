kentSrc = /kent/kent/src
# Make your private trackDb with 
#	make update
# Your private trackDb with additional options, for example:
#       make EXTRA="-strict -settings" update
# Make it for genome-test with
#	make alpha
# Make for ENCODE reporting (includes release alpha and release beta)
#	make encodeReport

# DO NOT RUN MULTIPLE INSTANCES OF THIS SCRIPT 
# Because it creates temporary files in the current directory 
# before loading them into the database.

# Browser supports multiple trackDb's so that individual developers
# can change things rapidly without stepping on other people's toes. 
# Usually when updating it is best to update your own trackDb and
# test it to make sure it works and that you have git updated all
# of trackDb/ before doing a make alpha. Note that you
# must specify which trackDb you are using in your .hg.conf file
# or in the cgi-bin-$(USER)/hg.conf file. Something like: 
# db.trackDb=trackDb_YourUserName

# note:  new group ARCHIVED_DBS created for assemblies still needed
# to support Conservation tracks in other assemblies.  These should
# have only chromInfo table on hgwbeta and RR.  make will not rebuild
# trackDb on hgwdev unless the db is specified explicitly on the 
# command line.

include ${kentSrc}/inc/common.mk

DBS = sacCer3
ARCHIVED_DBS =

# if trix build breaks, disable by setting to /bin/true instead of ./buildTrix
BUILD_TRIX = /bin/true
# BUILD_TRIX = ./buildTrix
HIVE_TRIX = /hive/data/inside/trix
DATA_TRIX = /data/trix
ALPHA_MACHINE = hgwdev.cse.ucsc.edu
BETA_MACHINE = qateam@hgwbeta.cse.ucsc.edu

update: ${DBS:%=%_update}
	${MKDIR} ${CGI_BIN}-${USER}/encode
%_update:
	./loadTracks ${EXTRA} trackDb_${USER} hgFindSpec_${USER} $*
	./checkMetaDb alpha metaDb_${USER} $*

#  if you want to test track search tool with your own trix file
#	rm -f ${DBS:%=${HIVE_TRIX}/%_trackDb_${USER}.{ixx,ix}}
#	HGDB_TRACKDB=trackDb_${USER} ${BUILD_TRIX} trackDb_${USER} metaDb_${USER} ${CGI_BIN}-${USER}/encode/cv.ra ${ALPHA_MACHINE} ${HIVE_TRIX} ${DBS}
# you'll also need to set browser.trixPath to point to your trix file
# see kent/src/product/ex.hg/conf for details

alpha: clean
	${GIT} pull
	${MKDIR} ${CGI_BIN}/encode
	${MAKE} alpha_all

alpha_all: ${DBS:%=%_alpha}

%_alpha:
	./loadTracks ${EXTRA} -release=alpha trackDb hgFindSpec $*
	./checkMetaDb alpha metaDb $*
	rm -f ${HIVE_TRIX}/$*_trackDb.{ixx,ix}}
	HGDB_TRACKDB=trackDb ${BUILD_TRIX} trackDb metaDb cv/alpha/cv.ra ${ALPHA_MACHINE} ${HIVE_TRIX} $*
	./makeTrixLinks trackDb ${HIVE_TRIX} $*

onbeta:	/cluster/home/${USER}/.hg.conf.beta

beta: onbeta clean 
	${GIT} pull
	${MAKE} beta_all

beta_all: ${DBS:%=%_beta}

%_beta:
	# now do loads on hgwbeta
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta ./loadTracks ${EXTRA} -strict -release=beta trackDb hgFindSpec $*
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta ./checkMetaDb beta metaDb $*
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta HGDB_TRACKDB=trackDb ${BUILD_TRIX} trackDb metaDb cv/beta/cv.ra ${BETA_MACHINE} ${DATA_TRIX} $*
	# now make files for hgwdev-beta (we share the tables with hgwbeta)
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta HGDB_TRACKDB=trackDb ${BUILD_TRIX} trackDb metaDb cv/beta/cv.ra ${ALPHA_MACHINE} ${HIVE_TRIX} $*

public: onbeta clean
	${GIT} pull
	${MAKE} public_all

public_all: ${DBS:%=%_public}

%_public:
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta ./loadTracks ${EXTRA} -strict -release=public trackDb_public hgFindSpec_public $*
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta ./checkMetaDb public metaDb_public $*
	HGDB_CONF=/cluster/home/${USER}/.hg.conf.beta HGDB_TRACKDB=trackDb_public ${BUILD_TRIX} trackDb_public metaDb_public cv/public/cv.ra ${BETA_MACHINE} ${DATA_TRIX} $*

# this will fail if we are not in a beta checkout:
checkbeta:
	${GIT} branch | egrep '^[*] v[0-9]+_branch' > /dev/null

# not sure if anyone actually uses the target below. It used to be "beta".
buildBeta: checkbeta clean strict

encodeReport:
	${GIT} pull
	./loadTracks ${EXTRA} trackDb_encodeReport hgFindSpec ${DBS}

listDbs:
	@echo "# databases listed in trackDb/makefile DBS variable, with table counts"
	@for D in ${DBS}; do \
	    C=`hgsql -N -e "show tables;" $${D} 2> /dev/null | wc -l`; \
	    if [ "$${C}" -gt 0 ]; then \
		echo -e "$${D}\t$${C}"; \
	    fi \
	done

# Get rid of symbolic links (created by lower-level makefiles):
clean:
	find . -type l -exec rm {} \;

