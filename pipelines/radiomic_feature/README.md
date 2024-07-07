# Lesion Radiomic Feature Extraction Pipeline

The lesion radiomic feature extraction pipeline utilizes [PyRadiomics](https://pyradiomics.readthedocs.io/en/latest/) to extract lesion features from T1-weighted, T2-FLAIR, and T2star-Phase images.

## Diagram
![Pyradiomics Workflow](/pipelines/radiomic_feature/figure/pyradiomics_pipeline.png)

## Data Structure
This pipeline requires all neuroimages to be organized in the BIDS format. An example is provided below:

![Data Structure](/pipelines/radiomic_feature/figure/data_structure.png)

## Pipeline Options
We offer two modes for the pipeline: individual and batch. If users want to run the pipeline for different participants one at a time, the participant's ID and session ID should be specified. Users can also run the pipeline in batch mode. The participant's ID and session ID can be skipped. Additionally, we provide four types of scenarios for running the pipeline: `local` (running the pipeline locally), `cluster` (running the pipeline on High Performance Computing Cluster), `singularity` (running the pipeline on High Performance Computing Cluster using the Singularity container), and `docker` (running the pipeline locally using the docker container). 

The pipeline contains three stages: 1) Preprocessing: processes MRI images to prepare for radiomic feature extraction, 2) Feature Extraction: extract radiomic features using PyRadiomics package, and 3) Consolidation: consolidates all participants' lesion radiomic feature data.

Detailed examples are provided below (all in individual mode):

### Preprocessing

(If you don't have a brain mask derived from the skull-stripping pipeline, please set `-s TRUE`.)

-   `local` 
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" -e "*_T2star.nii.gz" --mode individual -c "local" --toolpath /path/to/PennSIVE_neuro_pip
```

-   `cluster`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" -e "*_T2star.nii.gz" --mode individual -c "cluster" --toolpath /path/to/PennSIVE_neuro_pip
```

-   `singularity` 
```bash
singularity pull -F $sin_path docker://pennsive/neuror
```
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" --phase "*phase_T2star_UNWRAPPED.nii.gz" --mode individual -c "singularity" --toolpath /path/to/PennSIVE_neuro_pip --sinpath $sin_path
```


-   `docker` (under development)

```bash
docker pull pennsive/neuror
```

```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 -t "*_T1w.nii.gz" -f "*_FLAIR.nii.gz" --phase "*phase_T2star_UNWRAPPED.nii.gz" --mode individual -c "docker" --toolpath /path/to/PennSIVE_neuro_pip 
```

**Note**: If you are using the `takim` cluster within the PennSIVE group, you do not need to specify `sinpath`, which has been given a default path.

### Feature Extraction

-   `local` 
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "local" --toolpath /path/to/PennSIVE_neuro_pip --step extraction
```

-   `cluster`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "cluster" --toolpath /path/to/PennSIVE_neuro_pip --step extraction
```

-   `singularity` 
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "singularity" --toolpath /path/to/PennSIVE_neuro_pip --sinpath $sin_path --step extraction
```


-   `docker`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project -p sub-001 --ses ses-01 --mode individual -c "docker" --toolpath /path/to/PennSIVE_neuro_pip --step extraction
```

### Consolidation

-   `local`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project --toolpath /path/to/PennSIVE_neuro_pip --step consolidation -c "local"
```

-   `cluster`
```bash
bash /path/to/PennSIVE_neuro_pip/pipelines/radiomic_feature/code/bash/pyradiomics.sh -m /path/to/project --toolpath /path/to/PennSIVE_neuro_pip --step consolidation -c "cluster"
```

## Output Data Structure
![Output](/pipelines/radiomic_feature/figure/output.png)

