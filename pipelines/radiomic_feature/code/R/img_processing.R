suppressMessages(library(argparser))
suppressMessages(library(neurobase))
suppressMessages(library(tidyverse))
suppressMessages(library(oro.nifti))
suppressMessages(library(oro.dicom))
suppressMessages(library(WhiteStripe))
suppressMessages(library(fslr))
suppressMessages(library(ANTsR))
suppressMessages(library(extrantsr))
suppressMessages(library(mimosa))
suppressMessages(library(parallel))
suppressMessages(library(purrr))
suppressMessages(library(pbmcapply))
suppressMessages(library(pbapply))


p <- arg_parser("Running imaging processing step for radiomic feature extraction", hide.opts = FALSE)
p <- add_argument(p, "--mainpath", short = '-m', help = "Specify the main path where MRI images can be found.")
p <- add_argument(p, "--participant", short = '-p', help = "Specify the subject id.")
p <- add_argument(p, "--session", short = '-s', help = "Specify the session id.")
p <- add_argument(p, "--t1", help = "Specify the T1 sequence name.")
p <- add_argument(p, "--t2", help = "Specify the T2 sequence name.")
p <- add_argument(p, "--flair", help = "Specify the FLAIR sequence name.")
p <- add_argument(p, "--epi", help = "Specify the EPI sequence name.")
p <- add_argument(p, "--n4", help = "Specify whether to run bias correction step.", default = TRUE)
p <- add_argument(p, "--skullstripping", short = '-s', help = "Specify whether to run skull stripping step.", default = FALSE)
p <- add_argument(p, "--registration", short = '-r', help = "Specify whether to run registration step.", default = TRUE)
p <- add_argument(p, "--whitestripe", short = '-w', help = "Specify whether to run whitestripe step.", default = TRUE)
p <- add_argument(p, "--mimosa", help = "Specify whether to run mimosa segmentation step.", default = TRUE)
p <- add_argument(p, "--threshold", help = "Specify the threshold used to generate mimosa mask.", default = 0.2)
p <- add_argument(p, "--csf", help = "Specify whether to extract CSF mask.", default = TRUE)
p <- add_argument(p, "--lesioncenter", help = "Provide the path to the lesioncenter package.")
p <- add_argument(p, "--mpath", help = "Specify the path to the trained mimosa model.")
p <- add_argument(p, "--helpfunc", help = "Specify the path to the help functions.")
argv <- parse_args(p)

# Read in Files
main_path = argv$mainpath

# Load lesion center package
my_path = paste0(argv$lesioncenter, "/")
source_files = list.files(my_path)
purrr::map(paste0(my_path, source_files), source)
p = argv$participant
ses = argv$session
message('Checking inputs...')
if(is.na(argv$t1)) stop("Missing T1 sequence!")else{
  t1 = readnii(paste0(main_path, "/data/", p,  "/", ses, "/anat/", argv$t1))
}
if(is.na(argv$flair)) stop("Missing FLAIR sequence!")else{
  flair = readnii(paste0(main_path, "/data/", p,  "/", ses, "/anat/", argv$flair))
}
if(is.na(argv$epi)) stop("Missing EPI sequence!")else{
  epi = read_rpi(paste0(main_path, "/data/", p,  "/", ses, "/anat/", argv$epi))
}
if(!is.na(argv$t2)){
  t2 = readnii(paste0(main_path, "/data/", p,  "/", ses, "/anat/", argv$t2))
}

# Bias Correction
bias.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/bias_correction")
if(argv$n4){
  dir.create(bias.out.dir,showWarnings = FALSE)
  flair_biascorrect = bias_correct(file = flair,
                                  correction = "N4",
                                  verbose = TRUE)
  writenii(flair_biascorrect,paste0(bias.out.dir,"/FLAIR_n4.nii.gz"))
  t1_biascorrect = bias_correct(file = t1,
                               correction = "N4",
                               verbose = TRUE)
  writenii(t1_biascorrect,paste0(bias.out.dir,"/T1_n4.nii.gz"))
  epi_biascorrect = bias_correct(file = epi,
                               correction = "N4",
                               verbose = TRUE)
  writenii(epi_biascorrect,paste0(bias.out.dir,"/EPI_n4.nii.gz"))
  if(!is.na(argv$t2)){
    t2_biascorrect = bias_correct(file = t2,
                               correction = "N4",
                               verbose = TRUE)
    writenii(t2_biascorrect,paste0(bias.out.dir,"/T2_n4.nii.gz"))
    }
}else{
  t1_biascorrect = readnii(paste0(main_path, "/data/", p,  "/", ses, "/bias_correction/T1_n4.nii.gz"))
  flair_biascorrect = readnii(paste0(main_path, "/data/", p,  "/", ses, "/bias_correction/FLAIR_n4.nii.gz"))
  if(!is.na(argv$t2)){
    t2_biascorrect = readnii(paste0(main_path, "/data/", p,  "/", ses, "/bias_correction/T2_n4.nii.gz")) 
  }
  existing_files = list.files(paste0(main_path, "/data/", p,  "/", ses, "/bias_correction"))
  epi_file = existing_files[which(grepl("EPI_n4*", existing_files))]
  if(length(epi_file) == 0){
    epi_biascorrect = bias_correct(file = epi,
                               correction = "N4",
                               verbose = TRUE)
  writenii(epi_biascorrect,paste0(bias.out.dir,"/EPI_n4.nii.gz"))
  }else{
    epi_biascorrect = read_rpi(paste0(main_path, "/data/", p,  "/", ses, "/bias_correction/EPI_n4.nii.gz"))
  }
}

# Skull Stripping
brain.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/t1_brain")
if(!argv$skullstripping){
  brain_paths = list.files(brain.out.dir, recursive = TRUE, full.names = TRUE)
  brain_mask_path = brain_paths[which(grepl("*brainmask.nii.gz$", brain_paths))]
  brain_mask = readnii(brain_mask_path)
  t1_fslbet_robust = t1_biascorrect * brain_mask
  writenii(t1_fslbet_robust, paste0(bias.out.dir,"/T1_brain_n4.nii.gz"))
  }
if (argv$skullstripping){
  dir.create(brain.out.dir,showWarnings = FALSE)
  t1_fslbet_robust = fslbet_robust(t1_biascorrect,reorient = FALSE,correct = FALSE)
  brain_mask = t1_fslbet_robust > 0 
  writenii(t1_fslbet_robust,paste0(brain.out.dir,"/T1_brain.nii.gz"))
  writenii(t1_fslbet_robust,paste0(bias.out.dir,"/T1_brain_n4.nii.gz"))
  writenii(brain_mask,paste0(brain.out.dir,"/T1_brainmask.nii.gz"))
}

# Registration to FLAIR Space
reg.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/registration/FLAIR_space")
if (argv$registration){
  dir.create(reg.out.dir,showWarnings = FALSE, recursive = TRUE)
  ## Register T1 to FLAIR space 
  t1_to_flair = registration(filename = t1_biascorrect,
                           template.file = flair_biascorrect,
                           typeofTransform = "Rigid", remove.warp = FALSE,
                           outprefix=paste0(reg.out.dir,"/t1_reg_to_flair")) 
  t1_reg = ants2oro(antsApplyTransforms(fixed = oro2ants(flair_biascorrect), moving = oro2ants(t1_fslbet_robust),
                                      transformlist = t1_to_flair$fwdtransforms, interpolator = "welchWindowedSinc"))
  brainmask_reg = ants2oro(antsApplyTransforms(fixed = oro2ants(flair_biascorrect), moving = oro2ants(brain_mask),
                                             transformlist = t1_to_flair$fwdtransforms, interpolator = "nearestNeighbor"))
  writenii(t1_reg, paste0(reg.out.dir,"/t1_n4_brain_reg_flair"))
  writenii(brainmask_reg, paste0(reg.out.dir,"/brainmask_reg_flair"))
  flair_n4_brain = flair_biascorrect
  flair_n4_brain[brainmask_reg==0] = 0
  writenii(flair_n4_brain, paste0(reg.out.dir,"/flair_n4_brain"))
  ## Register T2 to FLAIR space 
  if(!is.na(argv$t2)){
    t2_to_flair = registration(filename = t2_biascorrect,
                             template.file = flair_biascorrect,
                             typeofTransform = "Rigid", remove.warp = FALSE,
                             outprefix=paste0(reg.out.dir,"/t2_reg_to_flair"))
    t2_n4_brain = t2_to_flair$outfile
    t2_n4_brain[brainmask_reg==0] = 0
    writenii(t2_n4_brain, paste0(reg.out.dir,"/t2_n4_brain_reg_flair"))
    }
}else{
  t1_reg = readnii(paste0(reg.out.dir, "/t1_n4_brain_reg_flair.nii.gz"))
  flair_n4_brain = readnii(paste0(reg.out.dir, "/flair_n4_brain.nii.gz"))
  brainmask_reg = readnii(paste0(reg.out.dir, "/brainmask_reg_flair"))
  if(!is.na(argv$t2)){
    t2_reg = readnii(paste0(reg.out.dir, "/t2_n4_brain_reg_flair.nii.gz"))
  }
}

# WhiteStripe normalize data
white.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/whitestripe/FLAIR_space")
if(argv$whitestripe){
  dir.create(white.out.dir,showWarnings = FALSE, recursive = TRUE)
  ind1 = whitestripe(t1_reg, "T1")
  t1_n4_reg_brain_ws = whitestripe_norm(t1_reg, ind1$whitestripe.ind)
  writenii(t1_n4_reg_brain_ws, paste0(white.out.dir,"/t1_n4_brain_reg_flair_ws"))
  if(!is.na(argv$t2)){
    ind2 = whitestripe(t2_n4_brain, "T2")
    t2_n4_reg_brain_ws = whitestripe_norm(t2_n4_brain, ind2$whitestripe.ind)
    writenii(t2_n4_reg_brain_ws, paste0(white.out.dir,"/t2_n4_brain_reg_flair_ws"))
  }
  ind3 = whitestripe(flair_n4_brain, "T2")
  flair_n4_brain_ws = whitestripe_norm(flair_n4_brain, ind3$whitestripe.ind)
  writenii(flair_n4_brain_ws, paste0(white.out.dir,"/flair_n4_brain_ws"))
  }else{
    t1_n4_reg_brain_ws = readnii(paste0(white.out.dir, "/t1_n4_brain_reg_flair_ws"))
    if(!is.na(argv$t2)){
      t2_n4_reg_brain_ws = readnii(paste0(white.out.dir, "/t2_n4_brain_reg_flair_ws"))
    }
    flair_n4_brain_ws = readnii(paste0(white.out.dir, "/flair_n4_brain_ws"))
  }

# Mimosa
mim.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/mimosa")
if(argv$mimosa){
  dir.create(mim.out.dir,showWarnings = FALSE)
  mimosa = mimosa_data(brain_mask=brainmask_reg, FLAIR=flair_n4_brain_ws, T1=t1_n4_reg_brain_ws, gold_standard=NULL, normalize="no", cores = 1, verbose = TRUE)
  mimosa_df = mimosa$mimosa_dataframe
  cand_voxels = mimosa$top_voxels
  tissue_mask = mimosa$tissue_mask
  load(argv$mpath) 
  predictions_WS = predict(mimosa_model, mimosa_df, type="response")
  predictions_nifti_WS = niftiarr(cand_voxels, 0)
  predictions_nifti_WS[cand_voxels==1] = predictions_WS
  probmap = fslsmooth(predictions_nifti_WS, sigma = 1.25, mask=tissue_mask, retimg=TRUE, smooth_mask=TRUE) 
  writenii(probmap, paste0(mim.out.dir,"/mimosa_prob"))
  writenii(probmap > as.numeric(argv$threshold), paste0(mim.out.dir,"/mimosa_mask"))
}else{
  probmap = readnii(paste0(mim.out.dir,"/mimosa_prob"))
}

# Extract CSF
csf.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/CSF")
if(argv$csf){
  dir.create(csf.out.dir,showWarnings = FALSE)
  csf=fast(t1_reg,opts='--nobias')
  csf[csf!=1]= 0
  csf=ants2oro(labelClusters(oro2ants(csf),minClusterSize=300))
  csf[csf>0]= 1
  csf=(csf!=1)
  csf=fslerode(csf, kopts = paste("-kernel boxv",2), verbose = TRUE)
  csf=(csf==0)
  writenii(csf, paste0(csf.out.dir,"/csf"))
}else{
  csf = readnii(paste0(csf.out.dir,"/csf"))
}

# Split Confluent Lesions
les = lesioncenters(probmap, probmap>argv$threshold, parallel=FALSE, cores=1, c3d=F)$lesioncenters
lables=ants2oro(labelClusters(oro2ants(les>0),minClusterSize=27))
for(j in 1:max(lables)){
  if(sum(csf[lables==j])>0){
    lables[lables==j] = 0
    }
  }
les = lables > 0

# Register to EPI Space
reg.epi.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/registration/EPI_space")
dir.create(reg.epi.out.dir, showWarnings = FALSE)
flair_to_epi = registration(filename = flair_biascorrect,
                              template.file = epi_biascorrect,
                              typeofTransform = "Rigid", remove.warp = FALSE) ### rigid
brainmask_reg_epi = ants2oro(antsApplyTransforms(fixed = oro2ants(epi_biascorrect), moving = oro2ants(brainmask_reg),
                                                transformlist = flair_to_epi$fwdtransforms, interpolator = "nearestNeighbor"))
writenii(brainmask_reg_epi, paste0(reg.epi.out.dir,'/brainmask_reg_epi'))
epi_n4_brain = epi_biascorrect * brainmask_reg_epi
writenii(epi_n4_brain, paste0(reg.epi.out.dir,'/epi_n4_brain'))
t1_reg_epi = ants2oro(antsApplyTransforms(fixed = oro2ants(epi_n4_brain), moving = oro2ants(t1_reg),
            transformlist = flair_to_epi$fwdtransforms, interpolator = "welchWindowedSinc"))
flair_reg_epi = ants2oro(antsApplyTransforms(fixed = oro2ants(epi_n4_brain), moving = oro2ants(flair_n4_brain),
            transformlist = flair_to_epi$fwdtransforms, interpolator = "welchWindowedSinc"))
mimosa_reg_epi = ants2oro(antsApplyTransforms(fixed = oro2ants(epi_n4_brain), moving = oro2ants(probmap),
            transformlist = flair_to_epi$fwdtransforms, interpolator = "welchWindowedSinc"))
mimosa_mask_reg_epi = ants2oro(antsApplyTransforms(fixed = oro2ants(epi_n4_brain), moving = oro2ants(probmap > argv$threshold),
            transformlist = flair_to_epi$fwdtransforms, interpolator = "nearestNeighbor"))
les_reg_epi = ants2oro(antsApplyTransforms(fixed = oro2ants(epi_n4_brain), moving = oro2ants(les),
            transformlist = flair_to_epi$fwdtransforms, interpolator = "nearestNeighbor"))
writenii(t1_reg_epi, paste0(reg.epi.out.dir, "/t1_reg_epi"))
writenii(flair_reg_epi, paste0(reg.epi.out.dir, "/flair_reg_epi"))
writenii(mimosa_reg_epi, paste0(reg.epi.out.dir, "/mimosa_reg_epi"))
writenii(mimosa_mask_reg_epi, paste0(reg.epi.out.dir, "/mimosa_mask_reg_epi"))
writenii(les_reg_epi, paste0(reg.epi.out.dir, "/les_reg_epi"))
