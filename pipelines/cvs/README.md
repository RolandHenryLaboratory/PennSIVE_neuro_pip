# Central Vein Sign (CVS) Pipeline

The CVS pipeline integrates an automated technique for the detection of the central vein sign in white matter lesions, developed by [Dr. Dworkin](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6177309/). It provides processed T1-weighted, T2-FLAIR, and T2*-EPI images, as well as subject-level CVS probabilities.

## Diagram
![CVS Workflow](/pipelines/cvs/figure/cvs_pipeline.png)

## Data Structure
This pipeline requires all neuroimages to be organized in the BIDS format. An example is provided below:

![Data Structure](/pipelines/cvs/figure/data_structure.png)

## Pipeline Options
We offer two modes for the pipeline: individual and batch. If users want to run the pipeline for different participants one at a time, the participant's ID and session ID should be specified. Users can also run the pipeline in batch mode. The participant's ID and session ID can be skipped. Additionally, we provide four types of scenarios for running the pipeline: `local` (running the pipeline locally), `cluster` (running the pipeline on High Performance Computing Cluster), `singularity` (running the pipeline on High Performance Computing Cluster using the Singularity container), and `docker` (running the pipeline locally using the docker container). Detailed examples are provided below (all in individual mode):

-   `local` 
```bash
bash ./PennSIVE_neuro_pip/pipelines/cvs/code/bash/cvs.sh -m ./project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" -e "*_T2star.nii.gz" -s TRUE --mode individual -c "local" --toolpath ./PennSIVE_neuro_pip
```

-   `cluster`
```bash
bash ./PennSIVE_neuro_pip/pipelines/cvs/code/bash/cvs.sh -m ./project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" -e "*_T2star.nii.gz" -s TRUE --mode individual -c "cluster" --toolpath ./PennSIVE_neuro_pip
```

-   `singularity` 
```bash
singularity pull -F $sin_path docker://pennsive/neuror
```
```bash
bash ./PennSIVE_neuro_pip/pipelines/cvs/code/bash/cvs.sh -m ./project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" -e "*_T2star.nii.gz" -s TRUE --mode individual -c "singularity" --toolpath ./PennSIVE_neuro_pip --sinpath $sin_path
```


-   `docker`

```bash
docker pull pennsive/neuror
```

```bash
bash ./PennSIVE_neuro_pip/pipelines/cvs/code/bash/cvs.sh -m ./project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" -e "*_T2star.nii.gz" -s TRUE --mode individual -c "docker" --toolpath ./PennSIVE_neuro_pip 
```

After this stage, we also offer a second stage: consolidation, which consolidates all participants' CVS estimates into a single CSV file.

```bash
bash ./PennSIVE_neuro_pip/pipelines/cvs/code/bash/cvs.sh -m ./project --step consolidation -c "cluster" --toolpath ./PennSIVE_neuro_pip 
```

## Output Data Structure
![Output](/pipelines/cvs/figure/output.png)