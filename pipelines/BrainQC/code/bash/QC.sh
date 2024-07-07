#!/bin/bash

# Define a function to display the help message
show_help() {
  echo "Usage: QC.sh [option]"
  echo "Options:"
  echo "  -h, --help    Show help message"
  echo "  -m, --mainpath    Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  -i, --img   Specify the brain image name"
  echo "  --seg   Specify the roi mask or lesion mask name"
  echo "  --step   Specify the step of pipeline. prep, qc, post. Default is prep"
  echo "  --cores   Specify number of cores used for paralleling computing. Default is 1"
  echo "  -t, --type   Specify the type of qc procedure. Default is lesion"
  echo "  --defaultseg   Select a default ROI to be evaluated first (when choosing freesurfer or JLF as the type of QC procedure). Default is NULL"
  echo "  --mode   Specify whether to run the pipeline individually or in a batch: individual or batch. Default is batch"
  echo "  -c, --container   Specify the container to use: singularity, docker, local, cluster. Default is cluster"
  echo "  --sinpath   Specify the path to the singularity image if a singularity container is used"
  echo "  --dockerpath   Specify the path to the docker image if a docker container is used"
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
img=""
seg=""
step=prep
cores=1
type=lesion
default_seg=NULL
out=""
mode=batch
c=cluster
sin_path=""
docker_path=""
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
    -i|--img)
      shift
      img=$1
      ;;
    --seg)
      shift
      seg=$1
      ;;
    --cores)
      shift
      cores=$1
      ;;
    -t|--type)
      shift
      type=$1
      ;;
    --defaultseg)
      shift
      default_seg=$1
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
    --dockerpath)
      shift
      docker_path=$1
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

out=$main_path/qc/${type}_qc

if [ "$step" == "prep" ]; then

  if [ -z "$img" ]; then
    echo "Error: Brain image not specified."
    show_help
    exit 1
  fi

  if [ -z "$seg" ]; then
    echo "Error: Segmentation image not specified."
    show_help
    exit 1
  fi

  mkdir -p $main_path/log/output
  mkdir -p $main_path/log/error
  mkdir -p $main_path/qc/${type}_qc

  if [ "$mode" == "batch" ]; then
    patient=`ls $main_path/data`
    for p in $patient;
    do 
      if [ "$c" == "cluster" ]; then
        bsub -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log \
        Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg
      elif [ "$c" == "local" ]; then
        Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      elif [ "$c" == "singularity" ]; then
        module load singularity
        bsub -J "QC" -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log singularity run --cleanenv \
           -B $main_path \
           -B $tool_path \
           -B /scratch $sin_path \
           Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg 
      elif [ "$c" == "docker" ]; then
        docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path /home/main \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg > /home/main/log/output/qc_output_$p.log 2> /home/main/log/error/qc_error_$p.log
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
        Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg 
      elif [ "$c" == "local" ]; then
        Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      elif [ "$c" == "singularity" ]; then
        module load singularity
        bsub -J "QC" -oo $main_path/log/output/qc_output_$p.log -eo $main_path/log/error/qc_error_$p.log singularity run --cleanenv \
           -B $main_path \
           -B $tool_path \
           -B /scratch $sin_path \
           Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg 
      elif [ "$c" == "docker" ]; then
        docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path \
        --participant $p --img $img --seg $seg --cores $cores --out $out --type $type --defaultseg $default_seg > $main_path/log/output/qc_output_$p.log 2> $main_path/log/error/qc_error_$p.log
      fi
  fi
fi

if [ "$step" == "qc" ]; then
  if [ "$c" == "cluster" ]; then
    Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path/qc/${type}_qc --type $type 
  elif [ "$c" == "local" ]; then
    Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path/qc/${type}_qc --type $type 
  elif [ "$c" == "singularity" ]; then
    module load singularity
    bsub -J "QC" singularity run --cleanenv \
       -B $main_path \
       -B $tool_path \
       -B /scratch $sin_path \
       Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path/qc/${type}_qc --type $type 
  elif [ "$c" == "docker" ]; then
    docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path /home/main/qc/${type}_qc --type $type 
  fi
fi

if [ "$step" == "post" ]; then
  if [ "$c" == "cluster" ]; then
    Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path/qc 
  elif [ "$c" == "local" ]; then
    Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path/qc 
  elif [ "$c" == "singularity" ]; then
    module load singularity
    bsub -J "QC" singularity run --cleanenv \
       -B $main_path \
       -B $tool_path \
       -B /scratch $sin_path \
       Rscript $tool_path/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path $main_path/qc
  elif [ "$c" == "docker" ]; then
    docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/BrainQC/code/R/QC_CLI.R --stage $step --path /home/main/qc
  fi
fi