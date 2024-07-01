#!/bin/bash

# Define a function to display the help message
show_help() {
  echo "Usage: t1t2.sh [option]"
  echo "Options:"
  echo "  -h, --help    Show help message"
  echo "  -m, --mainpath    Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  --ses    Specify the session id"
  echo "  --t1    Specify the T1 sequence name"
  echo "  --t2   Specify the T2 sequence name"
  echo "  -f, --flair   Specify the FLAIR sequence name"
  echo "  -n, --n4   Specify whether to run bias correction step. Default is FALSE"
  echo "  -s, --skullstripping   Specify whether to run skull stripping step. Default is FALSE"
  echo "  -r, --registration   Specify whether to run registration step. Default is FALSE"
  echo "  -w, --whitestripe   Specify whether to run whitestripe step. Default is FALSE"
  echo "  -l, --lesion   Specify whether to extract lesion volumes. Default is TRUE"
  echo "  --t2type   Specify the T2 sequence to use to generate T1/T2 ratio: t2, flair. Default is flair"
  echo "  --masktype   Specify the type of segmentation to use to generate ROI T1/T2 ratio. eg: fast, jlf, freesurfer. Default is freesurfer"
  echo "  --step   Specify the step of pipeline. estimation or consolidation. Default is estimation"
  echo "  --mode   Specify whether to run the pipeline individually or in a batch: individual or batch. Default is batch"
  echo "  -c, --container   Specify the container to use: singularity, docker, local, cluster. Default is cluster"
  echo "  --sinpath   Specify the path to the singularity image if a singularity container is used. A default path is provided: /project/singularity_images/neuror_latest.sif"
  echo "  --dockerpath   Specify the path to the docker image if a docker container is used. A default path is provided: pennsive/neuror"
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
t1=""
t2=""
flair=""
n4=FALSE
skullstripping=FALSE
registration=FALSE
whitestripe=FALSE
lesion=TRUE
t2type=flair
masktype=freesurfer
step=estimation
mode=batch
c=cluster
sin_path="/project/singularity_images/neuror_latest.sif"
tool_path=""
docker_path=pennsive/neuror

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
    --t1)
      shift
      t1=$1
      ;;
    --t2)
      shift
      t2=$1
      ;;
    -f|--flair)
      shift
      flair=$1
      ;;
    -n|--n4)
      shift
      n4=$1
      ;;
    -s|--skullstripping)
      shift
      skullstripping=$1
      ;;
    -r|--registration)
      shift
      registration=$1
      ;;
    -w|--whitestripe)
      shift
      whitestripe=$1
      ;;
    -l|--lesion)
      shift
      lesion=$1
      ;;
    --t2type)
      shift
      t2type=$1
      ;;
    --masktype)
      shift
      masktype=$1
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

mkdir -p $main_path/log/output
mkdir -p $main_path/log/error

if [ "$step" == "estimation" ]; then
  
  if [ "$mode" == "batch" ]; then
    patient=`ls $main_path/data`
    for p in $patient;
    do 
        ses=`ls $main_path/data/$p`
        for s in $ses;
        do
          t1_r=`find $main_path/data/$p/$s/anat -name $t1 -type f | xargs -I {} basename {}`
          flair_r=`find $main_path/data/$p/$s/anat -name $flair -type f | xargs -I {} basename {}`
          t2_r=`find $main_path/data/$p/$s/anat -name $t2 -type f | xargs -I {} basename {}`
          if [ "$c" == "cluster" ]; then
            if [ -z "$flair_r" ]; then
              bsub -oo $main_path/log/output/t1t2_output_${p}_${s}.log -eo $main_path/log/error/t1t2_error_${p}_${s}.log \
              Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
              --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath $tool_path
            elif [ -z "$t2_r" ]; then
              bsub -oo $main_path/log/output/t1t2_output_${p}_${s}.log -eo $main_path/log/error/t1t2_error_${p}_${s}.log \
              Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
              --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath $tool_path
            fi
          elif [ "$c" == "local" ]; then
            if [ -z "$flair_r" ]; then
              Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
              --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath $tool_path > $main_path/log/output/t1t2_output_${p}_${s}.log 2> $main_path/log/error/t1t2_error_${p}_${s}.log
            elif [ -z "$t2_r" ]; then
              Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
              --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath $tool_path > $main_path/log/output/t1t2_output_${p}_${s}.log 2> $main_path/log/error/t1t2_error_${p}_${s}.log
            fi
          elif [ "$c" == "singularity" ]; then
            module load singularity
            if [ -z "$flair_r" ]; then
            bsub -J "t1t2" -oo $main_path/log/output/t1t2_output_${p}_${s}.log -eo $main_path/log/error/t1t2_error_${p}_${s}.log singularity run --cleanenv \
               -B $main_path \
               -B $tool_path \
               -B /scratch $sin_path \
               Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
              --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath $tool_path
            elif [ -z "$t2_r" ]; then
            bsub -J "t1t2" -oo $main_path/log/output/t1t2_output_${p}_${s}.log -eo $main_path/log/error/t1t2_error_${p}_${s}.log singularity run --cleanenv \
               -B $main_path \
               -B $tool_path \
               -B /scratch $sin_path \
               Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
              --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath $tool_path
            fi
          elif [ "$c" == "docker" ]; then
            if [-z "$flair_r"]; then
              docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/t1t2/code/R/t1t2.R --mainpath /home/main \
              --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath /home/tool > /home/main/log/output/t1t2_output_${p}_${s}.log 2> /home/main/log/error/t1t2_error_${p}_${s}.log
            elif [ -z "$t2_r" ]; then
              docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/t1t2/code/R/t1t2.R --mainpath /home/main \
              --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
              --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
              --step $step --toolpath /home/tool > /home/main/log/output/t1t2_output_${p}_${s}.log 2> /home/main/log/error/t1t2_error_${p}_${s}.log
            fi
          fi
        done
    done
  elif [ "$mode" == "individual" ]; then
    if [ -z "$p" ]; then
      echo "Error: Participant id not provided for individual processing."
      show_help
      exit 1
    fi

    if [ -z "$ses" ]; then
      echo "Error: Session id not provided for individual processing."
      show_help
      exit 1
    fi

    t1_r=`find $main_path/data/$p/$ses/anat -name $t1 -type f | xargs -I {} basename {}`
    flair_r=`find $main_path/data/$p/$ses/anat -name $flair -type f | xargs -I {} basename {}`
    t2_r=`find $main_path/data/$p/$ses/anat -name $t2 -type f | xargs -I {} basename {}`

    if [ "$c" == "cluster" ]; then
      if [ -z "$flair_r" ]; then
        bsub -oo $main_path/log/output/t1t2_output_${p}_${ses}.log -eo $main_path/log/error/t1t2_error_${p}_${ses}.log \
        Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath $tool_path
      elif [ -z "$t2_r" ]; then
        bsub -oo $main_path/log/output/t1t2_output_${p}_${ses}.log -eo $main_path/log/error/t1t2_error_${p}_${ses}.log \
        Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath $tool_path
      fi
    elif [ "$c" == "local" ]; then
      if [ -z "$flair_r" ]; then
        Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath $tool_path > $main_path/log/output/t1t2_output_${p}_${ses}.log 2> $main_path/log/error/t1t2_error_${p}_${ses}.log
      elif [ -z "$t2_r" ]; then
        Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath $tool_path > $main_path/log/output/t1t2_output_${p}_${ses}.log 2> $main_path/log/error/t1t2_error_${p}_${ses}.log
      fi
    elif [ "$c" == "singularity" ]; then
      module load singularity
      if [ -z "$flair_r" ]; then
      bsub -J "t1t2" -oo $main_path/log/output/t1t2_output_${p}_${ses}.log -eo $main_path/log/error/t1t2_error_${p}_${ses}.log singularity run --cleanenv \
         -B $main_path \
         -B $tool_path \
         -B /scratch $sin_path \
         Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath $tool_path
      elif [ -z "$t2_r" ]; then
      bsub -J "t1t2" -oo $main_path/log/output/t1t2_output_${p}_${ses}.log -eo $main_path/log/error/t1t2_error_${p}_${ses}.log singularity run --cleanenv \
         -B $main_path \
         -B $tool_path \
         -B /scratch $sin_path \
         Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath $tool_path
      fi
    elif [ "$c" == "docker" ]; then
      if [ -z "$flair_r" ]; then
        docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/t1t2/code/R/t1t2.R --mainpath /home/main \
        --participant $p --session $s --t1 $t1_r --t2 $t2_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath /home/tool > /home/main/log/output/t1t2_output_${p}_${ses}.log 2> /home/main/log/error/t1t2_error_${p}_${ses}.log
      elif [ -z "$t2_r" ]; then
        docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/t1t2/code/R/t1t2.R --mainpath /home/main \
        --participant $p --session $s --t1 $t1_r --flair $flair_r --n4 $n4 --skullstripping $skullstripping \
        --registration $registration --whitestripe $whitestripe --lesion $lesion --t2type $t2type --masktype $masktype\
        --step $step --toolpath /home/tool > /home/main/log/output/t1t2_output_${p}_${ses}.log 2> /home/main/log/error/t1t2_error_${p}_${ses}.log
      fi
    fi
  fi
fi
  

if [ "$step" == "consolidation" ]; then
  if [ "$c" == "cluster" ]; then
        bsub -oo $main_path/log/output/t1t2_output_consolidation.log -eo $main_path/log/error/t1t2_error_consolidation.log \
        Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --t2type $t2type --masktype $masktype --step $step --toolpath $tool_path
    elif [ "$c" == "local" ]; then
      Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --t2type $t2type --masktype $masktype --step $step --toolpath $tool_path > $main_path/log/output/t1t2_output_consolidation.log 2> $main_path/log/error/t1t2_error_consolidation.log
    elif [ "$c" == "singularity" ]; then
      module load singularity
      bsub -J "t1t2" -oo $main_path/log/output/t1t2_output_consolidation.log -eo $main_path/log/error/t1t2_error_consolidation.log singularity run --cleanenv \
         -B $main_path \
         -B $tool_path \
         -B /scratch $sin_path \
         Rscript $tool_path/pipelines/t1t2/code/R/t1t2.R --mainpath $main_path \
        --t2type $t2type --masktype $masktype --step $step --toolpath $tool_path
    elif [ "$c" == "docker" ]; then
      docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/t1t2/code/R/t1t2.R --mainpath /home/main \
      --t2type $t2type --masktype $masktype --step $step --toolpath /home/tool > /home/main/log/output/t1t2_output_consolidation.log 2> /home/main/log/error/t1t2_error_consolidation.log
    fi
fi
  



