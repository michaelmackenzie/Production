#!/usr/bin/bash

usage() { echo "Usage: $0
  [ --primary primary physics name ]
  [ --campaign campaign name ]
  [ --dver digi campaign version ]
  [ --rver reco campaign version ]
  [ --dbpurpose purpose of db e.g. perfect, startup, best  ]
  [ --dbversion db version ]
  [ --digitype OnSpill, OffSpill, Mix1BB, Mix2BB, etc. ]
  [ --stream Signal, Trk, Diag, Calo etc. ]
  [ --merge merge factor (opt) default 10]
  [ --owner (opt) default mu2e ]
  [ --samopt (opt) Options to samListLocation default "-f --schema=root" ]
  [ --cat (opt) If non-null, optionally add 'Cat' to the input digi collection name
  [ --digis (opt)  If specified, use this list of input dig.*.art files instead of the one generated by SAM ]
  e.g.  bash gen_Reco.sh --primary CeEndpoint --campaign MDC2020 --dver MDC2020v --rver MDC2020v  --dbpurpose perfect --dbversion v1_0 --merge 10 --digitype OnSpill --stream Signal --beam 1BB
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

PRIMARY="" # name of primary
CAMPAIGN="" # e.g. MDC2020
DIGI_VERSION="" # digi (input) campaign version
RECO_VERSION="" # reco (output) campaign resion
DB_PURPOSE="" # db purpose
DB_VERSION="" # db version
DIGITYPE="" # digitype
MERGE=10 # merge factor
OWNER=mu2e
STREAM=Signal
SAMOPT="-f --schema=root"
DIGIS=""
CAT=""

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        primary)
          PRIMARY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        campaign)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dver)
          DIGI_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rver)
          RECO_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbpurpose)
          DB_PURPOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbversion)
          DB_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        digitype)
          DIGITYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        merge)
          MERGE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        stream)
          STREAM=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        digis)
          DIGIS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        cat)
          CAT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        samopt)
          SAMOPT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        *)
          echo "Unnown option " ${OPTARG}
          exit_abnormal
          ;;
        esac;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Exit abnormally.
      ;;
    *)                                    # If unknown (any other) option:
      exit_abnormal                       # Exit abnormally.
      ;;
    esac
done

if [ -z "$PRIMARY" ] || [ -z "$CAMPAIGN" ] || [ -z "$RECO_VERSION" ]; then
  echo " Missing Arguments"
  exit_abnormal
fi

echo "Generating reco scripts for ${PRIMARY} digi type ${DIGITYPE} digi version ${DIGI_VERSION} output version ${RECO_VERSION} database purpose, version ${DB_PURPOSE} ${DB_VERSION}"

rm Digis.txt
if [[ -n $DIGIS ]];
then
  echo "Using user-provided input list of digs $DIGIS"
  ln -s $DIGIS Digis.txt
else
  samListLocations ${SAMOPT} --defname="dig.${OWNER}.${PRIMARY}${DIGITYPE}${CAT}${STREAM}.${CAMPAIGN}${DIGI_VERSION}_${DB_PURPOSE}_${DB_VERSION}.art" > Digis.txt
fi

if [[ "${DIGITYPE}" == "Extracted" || "${DIGITYPE}" == "NoField" ]]; then
  echo "#include \"Production/JobConfig/reco/${DIGITYPE}.fcl\"" > template.fcl
else
  echo '#include "Production/JobConfig/reco/Reco.fcl"' > template.fcl
fi


echo 'services.DbService.purpose:' ${CAMPAIGN}'_'${DB_PURPOSE} >> template.fcl
echo 'services.DbService.version:' ${DB_VERSION} >> template.fcl
echo 'services.DbService.verbose : 2' >> template.fcl

generate_fcl --dsowner=${OWNER} --override-outputs --auto-description --embed template.fcl --dsconf "${CAMPAIGN}${RECO_VERSION}_${DB_PURPOSE}_${DB_VERSION}" \
--inputs "Digis.txt" --merge-factor=${MERGE}

for dirname in 000 001 002 003 004 005 006 007 008 009; do
  if test -d $dirname; then
    echo "found dir $dirname"
    MDIR="${PRIMARY}${DIGITYPE}${CAT}${STREAM}Reco_${dirname}"
    if test -d $MDIR; then
      echo "removing $MDIR"
      rm -rf $MDIR
    fi
    echo "moving $dirname to $MDIR"
    mv $dirname $MDIR
  fi
done
