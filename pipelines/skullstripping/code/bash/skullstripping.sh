#!/bin/bash

#module load ANTs/2.3.5
#module load singularity

# Define a function to display the help message
show_help() {
  echo "Usage: skullstripping.sh [option]"
  echo "Options:"
  echo "  -h, --help     Show help message"
  echo "  -m, --mainpath  Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  --ses    Specify the session id"
  echo "  -t, --type    Specify the type of skullstripping method: mass or hdbet. Default is mass"
  echo "  -f, --file    Select the MRI sequence to be skull-stripped"
  echo "  -n, --number  Select the number of templetes to be used. Default is 20."
  echo "  --mode   Specify whether to run the pipeline individually or in a batch: individual or batch. Default is batch"
  echo "  -c, --container   Specify the container to use: singularity, docker, local, cluster. Default is cluster"
  echo "  --sinpath   Specify the path to the singularity image if a singularity container is used. A default path is provided"
  echo "  --dockerpath   Specify the path to the docker image if a docker container is used. A default path is provided"
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
ses=""
type="mass"
file=""
num=20
mode=batch
c=cluster
tool_path=""
sin_path=""
docker_path=""


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
    -t|--type)
      shift
      type=$1
      ;;
    -n|--number)
      shift
      num=$1
      ;;
    -f|--file)
      shift
      file=$1
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


if [ -z "$file" ]; then
  echo "Error: MRI sequence not specified."
  show_help
  exit 1
fi

if [ "$type" == "hdbet" ] && [ -z "$sin_path" ]; then
  sin_path="/project/singularity_images/hd-bet_latest.sif"
elif [ "$type" == "mass" ] && [ -z "$sin_path" ]; then
  sin_path="/project/singularity_images/mass_latest.sif"
fi

if [ "$type" == "hdbet" ] && [ -z "$docker_path" ]; then
  docker_path="pennsive/hd-bet"
elif [ "$type" == "mass" ] && [ -z "$docker_path" ]; then
  docker_path="pennsive/mass"
fi

mkdir -p $main_path/log/output
mkdir -p $main_path/log/error

if [ "$type" == "mass" ]; then
  if [ "$mode" == "batch" ]; then
    patient=`ls $main_path/data`
    for p in $patient;
    do 
        ses=`ls $main_path/data/$p`
        for s in $ses;
        do
        t1_r=`find $main_path/data/$p/$s/anat -name $file -type f`
        if [ "$c" == "cluster" ]; then
          module load ANTs/2.3.5
          out_dir=$main_path/data/$p/$s
          mkdir $out_dir/t1_brain
          dest_dir=$out_dir/t1_brain
          bsub -oo $main_path/log/output/mass_output_${p}_${s}.log -eo $main_path/log/error/mass_error_${p}_${s}.log \
          mass -in "$t1_r" -dest "$dest_dir" -ref $tool_path/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num
        elif [ "$c" == "local" ]; then
          out_dir=$main_path/data/$p/$s
          mkdir $out_dir/t1_brain
          dest_dir=$out_dir/t1_brain
          mass -in "$t1_r" -dest "$dest_dir" -ref $tool_path/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num > $main_path/log/output/mass_output_${p}_${s}.log 2> $main_path/log/error/mass_error_${p}_${s}.log
        elif [ "$c" == "singularity" ]; then
          module load singularity
          out_dir=$main_path/data/$p/$s
          mkdir $out_dir/t1_brain
          dest_dir=$out_dir/t1_brain
          bsub -J "skullstripping" -oo $main_path/log/output/mass_output_${p}_${s}.log -eo $main_path/log/error/mass_error_${p}_${s}.log singularity run --cleanenv \
             -B $main_path \
             -B $tool_path \
             -B /scratch $sin_path \
             -in "$t1_r" -dest "$dest_dir" -ref $tool_path/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num
        elif [ "$c" == "docker" ]; then
          docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path -in "$t1_r" -dest "$dest_dir" -ref /home/tool/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num > /home/main/log/output/mass_output_${p}_${s}.log 2> /home/main/log/error/mass_error_${p}_${s}.log
        fi
        done
    done
  elif [ "$mode" == "individual" ]; then
    t1_r=`find $main_path/data/$p/$ses/anat -name $file -type f`
          if [ "$c" == "cluster" ]; then
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            bsub -oo $main_path/log/output/mass_output_${p}_${ses}.log -eo $main_path/log/error/mass_error_${p}_${ses}.log \
            mass -in "$t1_r" -dest "$dest_dir" -ref $tool_path/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num
          elif [ "$c" == "local" ]; then
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            mass -in "$t1_r" -dest "$dest_dir" -ref $tool_path/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num > $main_path/log/output/mass_output_${p}_${ses}.log 2> $main_path/log/error/mass_error_${p}_${ses}.log
          elif [ "$c" == "singularity" ]; then
            module load singularity
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            bsub -J "skullstripping" -oo $main_path/log/output/mass_output_${p}_${ses}.log -eo $main_path/log/error/mass_error_${p}_${ses}.log singularity run --cleanenv \
               -B $main_path \
               -B $tool_path \
               -B /scratch $sin_path \
               -in "$t1_r" -dest "$dest_dir" -ref $tool_path/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num
          elif [ "$c" == "docker" ]; then
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path -in "$t1_r" -dest "$dest_dir" -ref /home/tool/pipelines/skullstripping/template/WithCerebellum -NOQ -mem $num > /home/main/log/output/mass_output_${p}_${ses}.log 2> /home/main/log/error/mass_error_${p}_${ses}.log
          fi
  fi
fi


if [ "$type" == "hdbet" ]; then
  if [ "$mode" == "batch" ]; then
    patient=`ls $main_path/data`
    for p in $patient;
    do 
        ses=`ls $main_path/data/$p`
        for s in $ses;
        do
        t1_r=`find $main_path/data/$p/$s/anat -name $file -type f`
        if [ "$c" == "cluster" ]; then
          out_dir=$main_path/data/$p/$s
          mkdir $out_dir/t1_brain
          dest_dir=$out_dir/t1_brain
          bsub -oo $main_path/log/output/hdbet_output_${p}_${s}.log -eo $main_path/log/error/hdbet_error_${p}_${s}.log \
          hd-bet -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0
        elif [ "$c" == "local" ]; then
          out_dir=$main_path/data/$p/$s
          mkdir $out_dir/t1_brain
          dest_dir=$out_dir/t1_brain
          hd-bet -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0 > $main_path/log/output/hdbet_output_${p}_${s}.log 2> $main_path/log/error/hdbet_error_${p}_${s}.log
        elif [ "$c" == "singularity" ]; then
          module load singularity
          out_dir=$main_path/data/$p/$s
          mkdir $out_dir/t1_brain
          dest_dir=$out_dir/t1_brain
          bsub -J "skullstripping" -oo $main_path/log/output/hdbet_output_${p}_${s}.log -eo $main_path/log/error/hdbet_error_${p}_${s}.log singularity run --cleanenv \
             -B $main_path \
             -B $tool_path \
             -B /scratch $sin_path \
             -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0
        elif [ "$c" == "docker" ]; then
          docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0 > /home/main/log/output/hdbet_output_${p}_${s}.log 2> /home/main/log/error/hdbet_error_${p}_${s}.log
        fi
        done
    done
  elif [ "$mode" == "individual" ]; then
    t1_r=`find $main_path/data/$p/$ses/anat -name $file -type f`
          if [ "$c" == "cluster" ]; then
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            bsub -oo $main_path/log/output/hdbet_output_${p}_${ses}.log -eo $main_path/log/error/hdbet_error_${p}_${ses}.log \
            hd-bet -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0
          elif [ "$c" == "local" ]; then
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            hd-bet -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0 > $main_path/log/output/hdbet_output_${p}_${ses}.log 2> $main_path/log/error/hdbet_error_${p}_${ses}.log
          elif [ "$c" == "singularity" ]; then
            module load singularity
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            bsub -J "skullstripping" -oo $main_path/log/output/hdbet_output_${p}_${ses}.log -eo $main_path/log/error/hdbet_error_${p}_${ses}.log singularity run --cleanenv \
               -B $main_path \
               -B $tool_path \
               -B /scratch $sin_path \
               -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0
          elif [ "$c" == "docker" ]; then
            out_dir=$main_path/data/$p/$ses
            mkdir $out_dir/t1_brain
            dest_dir=$out_dir/t1_brain
            docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path -i $t1_r -o $dest_dir/brain.nii.gz -device cpu -mode fast -tta 0 > /home/main/log/output/hdbet_output_${p}_${ses}.log 2> /home/main/log/error/hdbet_error_${p}_${ses}.log
          fi
  fi
fi


