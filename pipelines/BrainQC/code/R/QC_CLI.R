#Sys.setenv(CURL_CA_BUNDLE = "/etc/ssl/certs/ca-bundle.trust.crt")
#library(devtools)
#withr::with_libpaths(new = "/home/zhengren/Desktop/cluster_set_up/r_packages", install_github("Zheng206/BrainQC"))

.libPaths(c("/misc/appl/R-4.1/lib64/R/library","/home/zhengren/Desktop/cluster_set_up/r_packages")) # put at beginning of R script so it knows where to look if not in default path
suppressMessages(library(argparser))
library(BrainQC)

## Read in arguments
p <- arg_parser("Run Brain WM Lesion/ROI Segmentation QC App", hide.opts = FALSE)
p <- add_argument(p, "--stage", help = "specify the stage of this pipeline. prep: prepare results for evaluation; qc: run interactive QC App; post: run post QC interactive session.", default = "prep")
p <- add_argument(p, "--path", help = "specify the main path to saved images, which include Flair, mimosa, and mimosa probability.")
p <- add_argument(p, "--img", short = '-i', help = "specify the name pattern for the brain image.")
p <- add_argument(p, "--seg", help = "specify the name pattern for the segmentation mask image.")
p <- add_argument(p, "--participant", help = "specify the participant id.")
p <- add_argument(p, "--type", help = "specify the type of qc procedure:lesion, cvs, freesurfer, JLF, PRL", default = "lesion")
p <- add_argument(p, "--defaultseg", help = "Select a default ROI to be evaluated first (when choosing freesurfer or JLF as the type of QC procedure).", default = "NULL")
p <- add_argument(p, "--cores", short = '-c', help = "number of cores used for paralleling computing, please provide a numeric value.", default = 1)
p <- add_argument(p, "--out", short = '-o', help = "specify the path to save outputs")
argv <- parse_args(p)

# Preprocess inputs

if(argv$stage == "prep"){
  message('Checking inputs...')
  if(is.na(argv$path)) stop("Please provide a path to the saved images") else {
    main_path = argv$path
  }

  if(is.na(argv$participant)) stop("Please provide the participant ID") else {
    p = argv$participant
  }
  
  if(is.na(argv$img)) stop("Please specify the name pattern for the brain image") else {
    img_name = argv$img
  }
  
  if(is.na(argv$seg)) stop("Please specify the name pattern for the segmentation image") else {
    seg_name = argv$seg
  }
  
  if(is.na(argv$out)) stop("Please specify the path to save outputs") else {
    out.dir = argv$out
  }
  
  n = as.numeric(argv$cores)
  
  if(argv$defaultseg == "NULL"){
    default_seg = NULL
  }else{default_seg = argv$defaultseg}

  qc_list = stage1_qc(main_path = main_path, img_name = img_name, seg_name = seg_name, subject = p, cores = n, qc_type = argv$type, default_seg = default_seg)
  message('Saving outputs...')
  saveRDS(qc_list, paste0(out.dir, "/", p, ".rds"))
}else if(argv$stage == "qc"){
  message('Checking inputs...')
  if(is.na(argv$path)) stop("Please provide a path to the saved outputs for interactive evaluation") else {
    main_path = argv$path
  }
  message('Starting the app...')
  qc_shiny(main_path = main_path, qc_type = argv$type)
}else if(argv$stage == "post"){
  message('Checking inputs...')
  if(is.na(argv$path)) stop("Please provide a path to the saved outputs for post QC interactive session") else {
    main_path = argv$path
  }
  message('Starting the app...')
  post_qc(main_path = main_path)
}


