#!/bin/bash

if [ -z "$1" ]; then
    echo "Input file not provided."
    exit 1
fi

INPUT=$1
OUTPUT=""
if [[ "$INPUT" == *.tif ]]; then
    OUTPUT="${INPUT::-4}.output.tif"
elif [[ "$INPUT" == *.tiff ]]; then
    OUTPUT="${INPUT::-5}.output.tiff"
else
    OUTPUT="$INPUT.out"
fi

gdalwarp -t_srs EPSG:3857 "$INPUT" "$INPUT.stage1"
gdal_translate -co "BIGTIFF=YES" -co "COMPRESS=LZW" -co "PREDICTOR=2" -co "TILED=YES" -co "NUM_THREADS=4" -b 1 -b 2 -b 3 "$INPUT.stage1" "$INPUT.stage2" && rm "$INPUT.stage1"
gdaladdo -r cubic --config COMPRESS_OVERVIEW LZW "$INPUT.stage2" 12 14 16 18 20
mv "$INPUT.stage2" "$OUTPUT"

