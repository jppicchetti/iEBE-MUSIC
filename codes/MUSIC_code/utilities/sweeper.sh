#!/usr/bin/env bash

folder_name=$1
echo Moving all the results into $folder_name ... 

shopt -s nullglob

# combine multiple surface files
for ii in surface_eps_*_*.dat
do
    jj=`echo $ii | cut -f 1-3 -d _ `
    cat $ii >> $jj.dat
done
rm -f surface_eps_*_*.dat

mkdir $folder_name
mv *.dat $folder_name 2>/dev/null
if compgen -G "*.err" > /dev/null; then
    mv *.err $folder_name
fi
if compgen -G "*.log" > /dev/null; then
    mv *.log $folder_name
fi
cp music_input_mode_2 $folder_name/music_input
