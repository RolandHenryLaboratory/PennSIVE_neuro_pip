suppressMessages(library(argparser))
suppressMessages(library(neurobase))
suppressMessages(library(tidyverse))
suppressMessages(library(oro.nifti))
suppressMessages(library(oro.dicom))
suppressMessages(library(ANTsR))
suppressMessages(library(extrantsr))
suppressMessages(library(parallel))

p <- arg_parser("Radiomic Feature Extraction Preparation.", hide.opts = FALSE)
p <- add_argument(p, "--mainpath", short = '-m', help = "Specify the main path where segmentations can be found.")
p <- add_argument(p, "--participant", short = '-p', help = "Specify the subject id.")
p <- add_argument(p, "--session", short = '-s', help = "Specify the session id.")
p <- add_argument(p, "--step", help = "Specify the step of feature pipeline. extraction or consolidation.", default = "extraction")
argv <- parse_args(p)

if(argv$step == "extraction"){
    main_path = argv$mainpath
    p = argv$participant
    ses = argv$session
    lesion.out.dir = paste0(main_path, "/data/", p, "/", ses, "/feature_extraction/rois")
    dir.create(lesion.out.dir,showWarnings = FALSE, recursive = TRUE)
    input.out.dir = paste0(main_path, "/data/", p, "/", ses, "/feature_extraction/FE_input_file")
    dir.create(input.out.dir,showWarnings = FALSE)
    les = readnii(paste0(main_path, "/data/", p, "/", ses, "/registration/EPI_space/les_reg_epi.nii.gz"))
    feature.out.dir = paste0(main_path, "/data/", p, "/", ses, "/feature_extraction/Features")
    dir.create(feature.out.dir,showWarnings = FALSE)
    
    # Feature Extraction Input File Preparation
    image = list.files(path = paste0(main_path, "/data"), recursive = TRUE, full.names = TRUE)
    image = image[which(grepl(p, image))]
    image = image[which(grepl(ses, image))]
    image = image[which(grepl("epi_n4_brain|flair_reg_epi|t1_reg_epi", image))]
    labels = ants2oro(labelClusters(oro2ants(les>0),minClusterSize=27))
    # Generate ROIs
    for (j in 1:max(labels)){
        lesion_mask = (labels == j)
        writenii(lesion_mask, paste0(lesion.out.dir, "/lesion_", j))
    }
    mask = list.files(lesion.out.dir, recursive = TRUE, full.names = TRUE)
    input_df = expand_grid(image, mask)
    input_df$subject = p
    input_df$session = ses
    input_df$roi = sapply(input_df$mask, function(x) gsub(".nii.gz", "", basename(x)), USE.NAMES = FALSE)
    input_df$modality = sapply(input_df$image, function(x) gsub(".nii.gz", "", basename(x)), USE.NAMES = FALSE)
    input_df = input_df %>% mutate(modality = case_when(modality == "epi_n4_brain" ~ "EPI",
                                                        modality == "flair_reg_epi" ~ "FLAIR",
                                                        modality == "t1_reg_epi" ~ "T1"))
    colnames(input_df) = c("Image", "Mask", "subject", "session", "roi", "modality")
    write_csv(input_df, paste0(input.out.dir, "/py_input.csv"))
}else if(argv$step == "consolidation"){
    main_path = argv$mainpath
    py_path = list.files(paste0(main_path, "/data"), pattern = "pyradiomics_features.csv", recursive = TRUE, full.names = TRUE) 
    py_con = lapply(py_path, function(x){
      py_df = read_csv(x)
      py_df = py_df[-1]
      py_df = py_df[which(!grepl("*corrected*", colnames(py_df)))]
      py_df$subject = as.factor(py_df$subject)
      py_df$session = as.factor(py_df$session)
      py_df$roi = as.factor(py_df$roi)
      py_df$modality = as.factor(py_df$modality)
      features = py_df[colnames(py_df)[!colnames(py_df) %in% c("subject", "session", "roi", "modality")]]
      features = features[, sapply(features, is.numeric)]
      #features = features[, sapply(features, function(x)length(unique(x)) > 1)]
      py_df = cbind(py_df[c("subject", "session", "roi", "modality")], features)
    }) %>% bind_rows()
    if(!file.exists(paste0(main_path, "/stats"))){
      dir.create(paste0(main_path, "/stats"))
    }
    write_csv(py_con, paste0(main_path, "/stats/pyradiomics_features.csv"))
} 

