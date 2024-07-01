suppressMessages(library(argparser))
suppressMessages(library(tidyverse))
suppressMessages(library(parallel))
suppressMessages(library(stringr))
suppressMessages(library(extrantsr))
suppressMessages(library(neurobase))
#suppressMessages(library(oro.nifti))
#suppressMessages(library(fslr))
suppressMessages(library(ANTsR))
suppressMessages(library(shiny))
suppressMessages(library(bslib))
suppressMessages(library(shinydashboard))
suppressMessages(library(scales))
suppressMessages(library(DT))

## Read in arguments
p <- arg_parser("Run WM Lesion Segmentation QC App", hide.opts = FALSE)
p <- add_argument(p, "--stage", short = '-s', help = "specify the stage of this pipeline. prep: prepare results for evaluation; qc: run interactive QC App.", default = "prep")
p <- add_argument(p, "--path", help = "specify the main path to saved images, which include Flair, mimosa, and mimosa probability.")
p <- add_argument(p, "--flair", short = '-f', help = "specify the name pattern for the flair sequence image.")
p <- add_argument(p, "--mimosa", short = '-m', help = "specify the name pattern for the mimosa (lesion) binary mask image.")
p <- add_argument(p, "--participant", help = "specify the participant id.")
p <- add_argument(p, "--cores", short = '-c', help = "number of cores used for paralleling computing, please provide a numeric value.", default = 1)
p <- add_argument(p, "--out", short = '-o', help = "specify the path to save outputs")
p <- add_argument(p, "--app", short = '-a', help = "specify the path to the qc app")
argv <- parse_args(p)

# Preprocess inputs

source(paste0(argv$app, "/code/R/image_tool.R"))
source(paste0(argv$app, "/code/R/qc_prep.R"))

if(argv$stage == "prep"){
  message('Checking inputs...')
  if(is.na(argv$path)) stop("Please provide a path to the saved images") else {
    main_path = argv$path
  }

  if(is.na(argv$participant)) stop("Please provide the participant ID") else {
    p = argv$participant
  }
  
  if(is.na(argv$flair)) stop("Please specify the name pattern for the flair sequence image") else {
    flair_name = argv$flair
  }
  
  if(is.na(argv$mimosa)) stop("Please specify the name pattern for the binary lesion mask image") else {
    mimosa_name = argv$mimosa
  }
  
  if(is.na(argv$out)) stop("Please specify the path to save outputs") else {
    out.dir = argv$out
  }
  
  #index_range = eval(parse(text = paste0("c(", gsub("-", ":", argv$range), ")")))
  n = as.numeric(argv$cores)
  
  qc_list = stage1_qc(main_path = main_path, flair_name = flair_name, mimosa_name = mimosa_name, subject = p, cores = n)
  message('Saving outputs...')
  saveRDS(qc_list, paste0(out.dir, "/", p, ".rds"))
}else{
  message('Checking inputs...')
  if(is.na(argv$path)) stop("Please provide a path to the saved outputs for interactive evaluation") else {
    main_path = argv$path
  }
  message('Starting the app...')
  qc_shiny(main_path)
}


