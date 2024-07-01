#!/bin/bash

# Define a function to display the help message
show_help() {
  echo "Usage: feature_extraction.sh [option]"
  echo "Options:"
  echo "  -h, --help     Show help message"
  echo "  -m, --mainpath  Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  -s, --session    Specify the session id"
  echo "  --step   Specify the step of pipeline. processing, extraction or consolidation. Default is processing"
  echo "  --toolpath   Specify the path to the saved pipeline folder, eg: /path/to/folder"
}

# Check if any argument is provided
if [ $# -eq 0 ]; then
  echo "Error: No arguments provided."
  show_help
  exit 1
fi

# Initialize variables
main_path=""
p=""
s=""
step=extraction
tool_path=""

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
    -s|--session)
      shift
      s=$1
      ;;
    --step)
      shift
      step=$1
      ;;
    --toolpath)
      shift
      tool_path=$1
      ;;
    *)
      echo "Error: Invalid option '$1'."
      show_help
      exit 1
      ;;
  esac
  shift
done

# Step 1: Feature Extraction Preparation
echo "Step 1: Feature Extraction Preparation"

b_path=$main_path/data/$p/$s/feature_extraction/FE_input_file
out_path=$main_path/data/$p/$s/feature_extraction/Features
Rscript $tool_path/pipelines/radiomic_feature/code/R/FE_pre.R -m $main_path -p $p -s $s --step $step && echo "Step 1 is done successfully!"

# Step 2: Feature Extraction
echo "Step 2: Feature Extraction"
python $tool_path/pipelines/radiomic_feature/code/python/pyradiomics.py $b_path/py_input.csv $out_path/pyradiomics_features.csv && echo "Step 2 is done successfully!"






