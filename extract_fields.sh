#!/bin/bash

usage() {
    echo "Usage: `basename $0` -d DATASET -f REQUIRED_FIELDS_FILE -p PATH -o OUTPUT_PREFIX [-h]" 1>&2
    echo
    echo "  -d      RAP dataset to extract fields from e.g. /app648_20231207195939.dataset"
    echo "  -f      File containing UK Biobank field ID per line"
    echo "  -p      RAP path for output files"
    echo "  -o      Basename for output files"
    echo "  -h      Display this help"
    echo
    echo "Example:"
    echo "          $(basename $0) -d /app648_20231207195939.dataset -f fields_require.txt -p /Lung_function -o LF_pheno"
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

while getopts ":d:f:p:o:h" opt; do
    case "${opt}" in
        h)
            usage
            exit 0
            ;;
        d)
            DATASET=$OPTARG
            ;;
        f)
            REQUIRED_FIELDS=$OPTARG
            ;;
        p)
            RAP_PATH=$OPTARG
            ;;
        o)
            BASE=$OPTARG
            ;;
        :)                                  
            echo "Error: -${OPTARG} requires an argument."
            usage
            exit 1
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

FIELDS_USE=${BASE}.fields

dx mkdir -p $RAP_PATH &&
    dx ls ${RAP_PATH}/$FIELDS_USE 2> /dev/null && dx rm -a ${RAP_PATH}/$FIELDS_USE

dx extract_dataset "$DATASET" --list-fields | cut -f1 | cut -f2 -d. |
    grep -Ef <(awk 'NR == 1 { print "eid"} {print "p"$0"($|_)"}' $REQUIRED_FIELDS) >| $FIELDS_USE &&
    dx upload --path ${RAP_PATH}/ $FIELDS_USE &&

dx run table-exporter \
    -idataset_or_cohort_or_dashboard=$DATASET \
    -ientity="participant" \
    -ifield_names_file_txt="${RAP_PATH}/$FIELDS_USE" \
    -iheader_style=FIELD-TITLE \
    -ioutput="$BASE" \
    --destination $RAP_PATH \
    --instance-type mem2_ssd2_x16 \
    --name extract_fields \
    --ignore-reuse \
    --brief -y
