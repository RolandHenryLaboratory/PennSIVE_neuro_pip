#!/bin/bash
# Define a function to display the help message
show_help() {
  echo "Usage: JLF.sh [option]"
  echo "Options:"
  echo "  -h, --help    Show help message"
  echo "  -m, --mainpath    Look for files in the mainpath"
  echo "  -p, --participant    Specify the participant id"
  echo "  --ses    Specify the session id"
  echo "  -t, --t1    Specify the skullstripped T1 sequence name"
  echo "  -n, --num    Specify the number of templates used. Default is 9"
  echo "  --type    Specify the type of templates to use: WMGM, thal. Default is WMGM."
  echo "  --lesion    Specify whether to extract lesion volumes. Default is TRUE"
  echo "  --step   Specify the step of JLF pipeline. registration, antsjointfusion or extraction. Default is antsjointfusion"
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
t1_pattern=""
num=15
type="WMGM"
step=antsjointfusion
mode=batch
c=cluster
sin_path="/project/singularity_images/neuror_latest.sif"
tool_path=""
lesion=TRUE
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
    --lesion)
      shift
      lesion=$1
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


if [ "$step" == "registration" ]; then
  if [ -z "$t1_pattern" ]; then
    echo "Error: T1 not specified."
    show_help
    exit 1
  fi

  if [ "$mode" == "batch" ]; then
    patients=`ls $main_path/data`
    for p in $patients;
    do
      ses=`ls $main_path/data/$p`
      for s in $ses;
      do
        t1_r=`find $main_path/data/$p/$s/t1_brain -name $t1_pattern -type f | xargs -I {} basename {}`
        if [ "$c" == "cluster" ]; then
          bsub -oo $main_path/log/output/jlf_output_${p}_${s}.log -eo $main_path/log/error/jlf_error_${p}_${s}.log \
          Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path \
          --participant $p --session $s --t1 $t1_r --type $type --num $num \
          --template $tool_path/pipelines/JLF/template --step $step --lesion $lesion
        elif [ "$c" == "local" ]; then
          Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path \
          --participant $p --session $s --t1 $t1_r --type $type --num $num \
          --template $tool_path/pipelines/JLF/template --step $step --lesion $lesion > $main_path/log/output/jlf_output_${p}_${s}.log 2> $main_path/log/error/jlf_error_${p}_${s}.log
        elif [ "$c" == "singularity" ]; then
          module load singularity
          bsub -J "JLF" -oo $main_path/log/output/jlf_output_${p}_${s}.log -eo $main_path/log/error/jlf_error_${p}_${s}.log singularity run --cleanenv \
             -B $main_path \
             -B $tool_path \
             -B /scratch $sin_path \
             Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path \
             --participant $p --session $s --t1 $t1_r --type $type --num $num \
             --template $tool_path/pipelines/JLF/template --step $step --lesion $lesion
        elif [ "$c" == "docker" ]; then
          docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/JLF/code/R/JLF_pre.R --mainpath /home/main \
          --participant $p --session $s --t1 $t1_r --type $type --num $num \
          --template /home/tool/pipelines/JLF/template --step $step --lesion $lesion > /home/main/log/output/jlf_output_${p}_${s}.log 2> /home/main/log/error/jlf_error_${p}_${s}.log
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
    t1_r=`find $main_path/data/$p/$ses/t1_brain -name $t1_pattern -type f | xargs -I {} basename {}`
    if [ "$c" == "cluster" ]; then
      bsub -oo $main_path/log/output/jlf_output_${p}_${ses}.log -eo $main_path/log/error/jlf_error_${p}_${ses}.log \
      Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path \
      --participant $p --session $ses --t1 $t1_r --type $type --num $num \
      --template $tool_path/pipelines/JLF/template --step $step --lesion $lesion
    elif [ "$c" == "local" ]; then
      Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path \
      --participant $p --session $ses --t1 $t1_r --type $type --num $num \
      --template $tool_path/pipelines/JLF/template --step $step --lesion $lesion > $main_path/log/output/jlf_output_${p}_${ses}.log 2> $main_path/log/error/jlf_error_${p}_${ses}.log
    elif [ "$c" == "singularity" ]; then
      module load singularity
      bsub -J "JLF" -oo $main_path/log/output/jlf_output_${p}_${ses}.log -eo $main_path/log/error/jlf_error_${p}_${ses}.log singularity run --cleanenv \
         -B $main_path \
         -B $tool_path \
         -B /scratch $sin_path \
         Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path \
         --participant $p --session $ses --t1 $t1_r --type $type --num $num \
         --template $tool_path/pipelines/JLF/template --step $step --lesion $lesion
    elif [ "$c" == "docker" ]; then
      docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path Rscript /home/tool/pipelines/JLF/code/R/JLF_pre.R --mainpath /home/main \
      --participant $p --session $ses --t1 $t1_r --type $type --num $num \
      --template /home/tool/pipelines/JLF/template --step $step --lesion $lesion > /home/main/log/output/jlf_output_${p}_${ses}.log 2> /home/main/log/error/jlf_error_${p}_${ses}.log
    fi
  fi
elif [ "$step" == "antsjointfusion" ]; then
  if [ -z "$t1_pattern" ]; then
    echo "Error: T1 not specified."
    show_help
    exit 1
  fi

  if [ "$mode" == "batch" ]; then
    patients=`ls $main_path/data`
    for p in $patients;
    do
      ses=`ls $main_path/data/$p`
      for s in $ses;
      do
        if [ "$c" == "cluster" ]; then
          module load ANTs2/2.2.0-111
          bsub -oo $main_path/log/output/jlf_output_${p}_${s}.log -eo $main_path/log/error/jlf_error_${p}_${s}.log \
          bash $tool_path/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath $main_path \
          --participant $p --ses $s --t1 $t1_pattern --type $type --num $num 
        elif [ "$c" == "local" ]; then
          bash $tool_path/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath $main_path \
          --participant $p --ses $s --t1 $t1_pattern --type $type --num $num > $main_path/log/output/jlf_output_${p}_${s}.log 2> $main_path/log/error/jlf_error_${p}_${s}.log
        elif [ "$c" == "singularity" ]; then
          module load singularity
          bsub -J "JLF" -oo $main_path/log/output/jlf_output_${p}_${s}.log -eo $main_path/log/error/jlf_error_${p}_${s}.log singularity run --cleanenv \
             -B $main_path \
             -B $tool_path \
             -B /scratch $sin_path \
             bash $tool_path/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath $main_path \
          --participant $p --ses $s --t1 $t1_pattern --type $type --num $num 
        elif [ "$c" == "docker" ]; then
          docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path bash /home/tool/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath /home/main \
          --participant $p --ses $s --t1 $t1_pattern --type $type --num $num > /home/main/log/output/jlf_output_${p}_${s}.log 2> /home/main/log/error/jlf_error_${p}_${s}.log
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
    if [ "$c" == "cluster" ]; then
      module load ANTs2/2.2.0-111
      bsub -oo $main_path/log/output/jlf_output_${p}_${ses}.log -eo $main_path/log/error/jlf_error_${p}_${ses}.log \
      bash $tool_path/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath $main_path \
      --participant $p --ses $ses --t1 $t1_pattern --type $type --num $num 
    elif [ "$c" == "local" ]; then
      bash $tool_path/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath $main_path \
      --participant $p --ses $ses --t1 $t1_pattern --type $type --num $num > $main_path/log/output/jlf_output_${p}_${ses}.log 2> $main_path/log/error/jlf_error_${p}_${ses}.log
    elif [ "$c" == "singularity" ]; then
      module load singularity
      bsub -J "JLF" -oo $main_path/log/output/jlf_output_${p}_${ses}.log -eo $main_path/log/error/jlf_error_${p}_${ses}.log singularity run --cleanenv \
         -B $main_path \
         -B $tool_path \
         -B /scratch $sin_path \
         bash $tool_path/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath $main_path \
      --participant $p --ses $ses --t1 $t1_pattern --type $type --num $num 
    elif [ "$c" == "docker" ]; then
      docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path bash /home/tool/pipelines/JLF/code/bash/antsjointfusion.sh --mainpath /home/main \
      --participant $p --ses $ses --t1 $t1_pattern --type $type --num $num > /home/main/log/output/jlf_output_${p}_${ses}.log 2> /home/main/log/error/jlf_error_${p}_${ses}.log
    fi
  fi

elif [ "$step" == "extraction" ]; then
  if [ "$c" == "cluster" ]; then
    bsub -oo $main_path/log/output/jlf_output_extraction.log -eo $main_path/log/error/jlf_error_extraction.log \
    Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path --type $type --step $step --lesion $lesion --toolpath $tool_path 
  elif [ "$c" == "local" ]; then
    Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path --type $type --step $step --lesion $lesion --toolpath $tool_path > $main_path/log/output/jlf_output_extraction.log 2> $main_path/log/error/jlf_error_extraction.log
  elif [ "$c" == "singularity" ]; then
    module load singularity
    bsub -J "JLF" -oo $main_path/log/output/jlf_output_extraction.log -eo $main_path/log/error/jlf_error_extraction.log singularity run --cleanenv \
       -B $main_path \
       -B $tool_path \
       -B /scratch $sin_path \
       Rscript $tool_path/pipelines/JLF/code/R/JLF_pre.R --mainpath $main_path --type $type --step $step --lesion $lesion --toolpath $tool_path
  elif [ "$c" == "docker" ]; then
    docker run --rm -it -v $main_path:/home/main -v $tool_path:/home/tool $docker_path bsub Rscript /home/tool/pipelines/JLF/code/R/JLF_pre.R --mainpath /home/main --type $type --step $step --lesion $lesion --toolpath /home/tool > /home/main/log/output/jlf_output_extraction.log 2> /home/main/log/error/jlf_error_extraction.log
  fi
fi
