#!/bin/bash

# Define a function to display the help message
show_help() {
  echo "Usage: antsjointfusion.sh [option]"
  echo "Options:"
  echo "  -h, --help    Show help message"
  echo "  -m, --mainpath    Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  --ses    Specify the session id"
  echo "  -t, --t1    Specify the skullstripped T1 sequence name"
  echo "  -n, --num    Specify the number of templates used. Default is 9"
  echo "  --type    Specify the type of templates to use: WMGM, thal. Default is WMGM."
}

# Check if any argument is provided
if [ $# -eq 0 ]; then
  echo "Error: No arguments provided."
  show_help
  exit 1
fi

main_path=""
p=""
ses=""
t1_pattern=""
num=15
type="WMGM"

# Parse command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -m|--mainpath)
      shift
      main_path=$1
      ;;
    -p|--participant)
      shift
      p=$1
      ;;
    --ses)
      shift
      ses=$1
      ;;
    -t|--t1)
      shift
      t1_pattern=$1
      ;;
    -n|--num)
      shift
      num=$1
      ;;
    --type)
      shift
      type=$1
      ;;
    *)
      echo "Error: Invalid option '$1'."
      show_help
      exit 1
      ;;
  esac
  shift
done

outdir=$main_path/data/$p/$ses/JLF/JLF_"$type"/result
mkdir $outdir
t1=`find $main_path/data/$p/$ses -name $t1_pattern -type f`
declare -a atlas
declare -a se
# Fill arrays
iter=$(expr $num - 1)
for i in $(seq 0 $iter)
do
    atlas[$i]="$main_path/data/$p/$ses/JLF/JLF_"$type"/atlas_to_t1/jlf_template_reg$(expr $i + 1).nii.gz"
	  seg[$i]="$main_path/data/$p/$ses/JLF/JLF_"$type"/seg_to_t1/jlf_${type}_reg$(expr $i + 1).nii.gz"
done

echo 'Running antsJointFusion...'
antsJointFusion -t $t1 -g ${atlas[*]} -l ${seg[*]} -b 4.0 -c 0 -o "$outdir/fused_${type}_seg.nii.gz" -v 