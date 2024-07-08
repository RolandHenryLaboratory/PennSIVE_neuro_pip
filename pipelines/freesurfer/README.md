# Freesurfer Brain Segmentation Pipeline

The Freesurfer pipeline integrates [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/fswiki) software to provide a full processing stream for structural MRI data. It takes a T1-weighted image as the only input and generates brain ROI segmentation masks as well as brain-related statistics.


## Data Structure
This pipeline requires all neuroimages to be organized in the BIDS format. An example is provided below:

![Data Structure](/pipelines/freesurfer/figure/data_structure.png)

## Pipeline Options
We offer two modes for the pipeline: individual and batch. If users want to run the pipeline for different participants one at a time, the participant's ID and session ID should be specified. Users can also run the pipeline in batch mode. The participant's ID and session ID can be skipped. Additionally, we provide four types of scenarios for running the pipeline: `local` (running the pipeline locally), `cluster` (running the pipeline on High Performance Computing Cluster), `singularity` (running the pipeline on High Performance Computing Cluster using the Singularity container), and `docker` (running the pipeline locally using the docker container). 

The pipeline contains three stages: 1) Segmentation: runs the FreeSurfer `recon-all` command to obtain ROI segmentation masks and brain statistics, 2) Estimation: converts the brain statistics into CSV format, and 3) Consolidation: consolidates all participants' data.

Detailed examples are provided below (all in individual mode):

### Segmentation

-   `local` 
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 -n "*_T1w.nii.gz" --mode individual -c "local" --toolpath /path/to/PennSIVE_neuro_pip
```

-   `cluster`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 -n "*_T1w.nii.gz" --mode individual -c "cluster" --toolpath /path/to/PennSIVE_neuro_pip
```

-   `singularity` 
```bash
singularity pull -F $sin_path docker://pennsive/neuror
```
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 -n "*_T1w.nii.gz" --mode individual -c "singularity" --toolpath /path/to/PennSIVE_neuro_pip --sinpath $sin_path
```


-   `docker`

```bash
docker pull pennsive/neuror
```

```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 -n "*_T1w.nii.gz" --mode individual -c "docker" --toolpath /path/to/PennSIVE_neuro_pip 
```

**Note**: If you are using the `takim` cluster within the PennSIVE group, you do not need to specify `sinpath`, which has been given a default path.

### Estimation

-   `local` 
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "local" --toolpath /path/to/PennSIVE_neuro_pip --step estimation
```

-   `cluster`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "cluster" --toolpath /path/to/PennSIVE_neuro_pip --step estimation
```

-   `singularity` 
```bash
singularity pull -F $sin_path docker://pennsive/neuror
```
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "singularity" --toolpath /path/to/PennSIVE_neuro_pip --sinpath $sin_path --step estimation
```

-   `docker`

```bash
docker pull pennsive/neuror
```

```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "docker" --toolpath /path/to/PennSIVE_neuro_pip --step estimation
```

### Consolidation

-   `local`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project --toolpath /path/to/PennSIVE_neuro_pip --step consolidation -c "local"
```

-   `cluster`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/freesurfer/code/bash/freesurfer.sh -m /path/to/project --toolpath /path/to/PennSIVE_neuro_pip --step consolidation -c "cluster"
```


