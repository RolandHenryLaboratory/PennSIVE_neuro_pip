#!/bin/bash

# Define a function to display the help message
show_help() {
  echo "Usage: QC.sh [option]"
  echo "Options:"
  echo "  -h, --help    Show help message"
  echo "  -m, --mainpath    Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  -f, --flair   Specify the FLAIR sequence name"
  echo "  --mimosa   Specify the mimosa mask or lesion mask name"
  echo "  --step   Specify the step of pipeline. prep, qc. Default is prep"
  echo "  --cores   Specify number of cores used for paralleling computing. Default is 1"
  echo "  -o, --out   Specify the path to save outputs. A default path is provided by th pipeline"
  echo "  --mode   Specify whether to run the pipeline individually or in a batch: individual or batch. Default is batch"
  echo "  -c, --container   Specify the container to use: singularity, docker, local, cluster. Default is cluster"
  echo "  --sinpath   Specify the path to the singularity image if a singularity container is used"
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
flair=""
mimosa=""
step=prep
cores=1
out=""
mode=batch
c=cluster
sin_path=""
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
    -f|--flair)
      shift
      flair=$1
      ;;
    --mimosa)
      shift
      mimosa=$1
      ;;
    --cores)
      shift
      cores=$1
      ;;
    -o|--out)
      shift
      out=$1
      ;;
    --step)
      shift
      step=$1
      ;;
    --mode)
      shift
      mode=$1
      ;;
    -c|--container)
      shift
      c=$1
      ;;
    --sinpath)
      shift
      sin_path=$1
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

# Check if required options are provided
if [ -z "$main_path" ]; then
  echo "Error: Main path not specified."
  show_help
  exit 1
fi

out=$main_path/qc

if [ "$step" == "prep" ]; then

  if [ -z "$flair" ]; then
    echo "Error: FLAIR not specified."
    show_help
    exit 1
  fi

  if [ -z "$mimosa" ]; then
    echo "Error: Lesion mask not specified."
    show_help
    exit 1
  fi

  mkdir -p $main_path/log/output
  mkdir -p $main_path/log/error
  mkdir $main_path/qc

  if [ "$mode" == "batch" ]; then
    patient=`ls $main_path/data`
    for p in $patient;
    do 
      if [ "$c" == "cluster" ]; then
        bsub -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log \
        Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app $tool_path/pipelines/QC_design 
      elif [ "$c" == "local" ]; then
        Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app $tool_path/pipelines/QC_design > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      elif [ "$c" == "singularity" ]; then
        module load singularity
        bsub -J "QC" -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log singularity run --cleanenv \
           -B $main_path \
           -B $tool_path \
           -B /scratch $sin_path \
           Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
           --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app $tool_path/pipelines/QC_design 
      elif [ "$c" == "docker" ]; then
        docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool pennsive/neuror Rscript /home/tool/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app /home/tool/pipelines/QC_design > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      fi
    done
  elif [ "$mode" == "individual" ]; then
    if [ -z "$p" ]; then
      echo "Error: Participant id not provided for individual processing."
      show_help
      exit 1
    fi

    if [ "$c" == "cluster" ]; then
        bsub -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log \
        Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app $tool_path/pipelines/QC_design 
      elif [ "$c" == "local" ]; then
        Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app $tool_path/pipelines/QC_design > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      elif [ "$c" == "singularity" ]; then
        module load singularity
        bsub -J "QC" -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log singularity run --cleanenv \
           -B $main_path \
           -B $tool_path \
           -B /scratch $sin_path \
           Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
           --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app $tool_path/pipelines/QC_design 
      elif [ "$c" == "docker" ]; then
        docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool pennsive/neuror Rscript /home/tool/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --flair $flair --mimosa $mimosa --cores $cores --out $out --app /home/tool/pipelines/QC_design > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      fi
  fi
fi

if [ "$step" == "qc" ]; then
  if [ "$c" == "cluster" ]; then
    Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path/qc --app $tool_path/pipelines/QC_design 
  elif [ "$c" == "local" ]; then
    Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path/qc --app $tool_path/pipelines/QC_design 
  elif [ "$c" == "singularity" ]; then
    module load singularity
    bsub -J "QC" singularity run --cleanenv \
       -B $main_path \
       -B $tool_path \
       -B /scratch $sin_path \
       Rscript $tool_path/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path $main_path/qc --app $tool_path/pipelines/QC_design 
  elif [ "$c" == "docker" ]; then
    docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool pennsive/neuror Rscript /home/tool/pipelines/QC_design/code/R/QC_CLI.R --stage $step --path /home/main/qc --app /home/tool/pipelines/QC_design 
  fi
fi