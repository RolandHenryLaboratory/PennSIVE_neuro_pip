#!/bin/bash


# Define a function to display the help message
show_help() {
  echo "Usage: freesurfer.sh [option]"
  echo "Options:"
  echo "  -h, --help     Show help message"
  echo "  -m, --mainpath  Look for files in the mainpath"
  echo "  --mode  Specify whether you want to run it individually or in batch: individual, batch. Default is batch"
  echo "  -p, --participant  Specify the name of the participant if run individually"
  echo "  --ses  Specify the session name of the participant if run individually"
  echo "  -n, --name  Specify the name pattern of T1 images"
  echo "  -t, --toolpath  Specify the path to useful scripts or licenses"
  echo "  -c, --container  Specify the type of container to use. docker or singularity. Default is singularity"
  echo "  -s, --step   Specify the step of pipeline. segmentation, estimation or consolidation. Default is segmentation"
}

# Check if any argument is provided
if [ $# -eq 0 ]; then
  echo "Error: No arguments provided."
  show_help
  exit 1
fi

# Initialize variables
main_path=""
tool_path=""
name=""
step=segmentation
container=singularity
mode=batch

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
    --mode)
      shift
      mode=$1
      ;;
    -p|--participant)
      shift
      p=$1
      ;;
    --ses)
      shift
      ses=$1
      ;;
    -n|--name)
      shift
      name=$1
      ;;
    -t|--toolpath)
      shift
      tool_path=$1
      ;;
    -c|--container)
      shift
      container=$1
      ;;
    -s|--step)
      shift
      step=$1
      ;;
    *)
      echo "Error: Invalid option '$1'."
      show_help
      exit 1
      ;;
  esac
  shift
done

if [ "$mode" = "batch" ];then
  if [ "$container" = "singularity" ];then
    module load singularity
    if [ "$step" = "segmentation" ];then
      for inv in $(find $main_path/data -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          bsub -J "segmentation" singularity run --cleanenv \
          -B $main_path \
          -B $tool_path \
          -B /scratch \
          --env SUBJECTS_DIR=$main_path/data/$subject/$session \
          --env SURFER_FRONTDOOR=1 \
          --env FS_LICENSE=$tool_path/license/license.txt $tool_path/code/image/neuror.sif recon-all -i $inv -subject $SUBJECTS_DIR/freesurfer -all
      done 
    fi

    if [ "$step" = "estimation" ];then
    for inv in $(find $main_path/data -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          bsub -J "estimation" singularity run --cleanenv \
          -B $main_path \
          -B $tool_path \
          -B /scratch \
          --env SUBJECTS_DIR=$main_path/data/$subject/$session \
          --env SURFER_FRONTDOOR=1 \
          --env FS_LICENSE=$tool_path/license/license.txt $tool_path/code/image/neuror.sif Rscript $tool_path/code/R/extraction.R -m $main_path -p $subject -s $session
      done 
    fi

    if [ "$step" = "consolidation" ];then
      bsub -J "segmentation" singularity run --cleanenv \
           -B $main_path \
           -B $tool_path \
           -B /scratch \
      $tool_path/code/image/neuror.sif \
      Rscript $tool_path/code/R/consolidation.R -m $main_path
    fi

  fi

  if [ "$container" = "docker" ];then
    if [ "$step" = "segmentation" ];then
      for inv in $(find $main_path/data -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          new_inv=$(echo "$inv" | sed "s|$main_path|/home/main|g")
          docker run --rm -it \
          -v $main_path:/home/main \
          -v $tool_path:/home/tool \
          -e SUBJECTS_DIR=/home/main/data/$subject/$session \
          -e SURFER_FRONTDOOR=1 \
          -e FS_LICENSE=/home/tool/license/license.txt \
          pennsive/neuror \
          recon-all -i $new_inv -subject $SUBJECTS_DIR/freesurfer -all
      done 
    fi

    if [ "$step" = "estimation" ];then
    for inv in $(find $main_path/data -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          #new_inv=$(echo "$inv" | sed "s|$main_path|/home|g")
          docker run --rm -it \
          -v $main_path:/home/main \
          -v $tool_path:/home/tool \
          -e SUBJECTS_DIR=/home/main/data/$subject/$session \
          -e SURFER_FRONTDOOR=1 \
          -e FS_LICENSE=/home/tool/license/license.txt \
          pennsive/neuror \
          Rscript /home/tool/code/R/extraction.R -m /home/main -p $subject -s $session
      done 
    fi

    if [ "$step" = "consolidation" ];then
      docker run --rm -it \
      -v $main_path:/home/main \
      -v $tool_path:/home/tool \
      pennsive/neuror \
      Rscript /home/tool/code/R/consolidation.R -m /home/main
    fi
  fi
fi

if [ "$mode" = "individual" ];then
  if [ "$container" = "singularity" ];then
    if [ "$step" = "segmentation" ];then
      module load singularity
      bsub -J "segmentation" singularity run --cleanenv \
      -B $main_path \
      -B $tool_path \
      -B /scratch \
      --env SUBJECTS_DIR=$main_path/data/$p/$ses \
      --env SURFER_FRONTDOOR=1 \
      --env FS_LICENSE=$tool_path/license/license.txt $tool_path/code/image/neuror.sif recon-all -i $inv -subject $SUBJECTS_DIR/freesurfer -all
    fi

    if [ "$step" = "estimation" ];then
    for inv in $(find $main_path/data/$p/$ses -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          bsub -J "estimation" singularity run --cleanenv \
          -B $main_path \
          -B $tool_path \
          -B /scratch \
          --env SUBJECTS_DIR=$main_path/data/$subject/$session \
          --env SURFER_FRONTDOOR=1 \
          --env FS_LICENSE=$tool_path/license/license.txt $tool_path/code/image/neuror.sif Rscript $tool_path/code/R/extraction.R -m $main_path -p $subject -s $session
      done 
    fi

  fi

  if [ "$container" = "docker" ];then
    if [ "$step" = "segmentation" ];then
      for inv in $(find $main_path/data/$p/$ses -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          new_inv=$(echo "$inv" | sed "s|$main_path|/home/main|g")
          docker run --rm -it \
          -v $main_path:/home/main \
          -v $tool_path:/home/tool \
          -e SUBJECTS_DIR=/home/main/data/$subject/$session \
          -e SURFER_FRONTDOOR=1 \
          -e FS_LICENSE=/home/tool/license/license.txt \
          pennsive/neuror \
          recon-all -i $new_inv -subject $SUBJECTS_DIR/freesurfer -all
      done 
    fi

    if [ "$step" = "estimation" ];then
    for inv in $(find $main_path/data/$p/$ses -name $name -type f);
      do
          subject=`echo $inv |rev | cut -f 4 -d '/' | rev`
          session=`echo $inv |rev | cut -f 3 -d '/' | rev`
          docker run --rm -it \
          -v $main_path:/home/main \
          -v $tool_path:/home/tool \
          -e SUBJECTS_DIR=/home/main/data/$subject/$session \
          -e SURFER_FRONTDOOR=1 \
          -e FS_LICENSE=/home/tool/license/license.txt \
          pennsive/neuror \
          Rscript /home/tool/code/R/extraction.R -m /home/main -p $subject -s $session
      done 
    fi
  fi
fi




