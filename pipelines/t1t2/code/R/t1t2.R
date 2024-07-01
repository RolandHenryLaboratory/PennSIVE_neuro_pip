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
suppressMessages(library(freesurfer))
suppressMessages(library(readxl))

p <- arg_parser("Running T1/T2 Pipeline", hide.opts = FALSE)
p <- add_argument(p, "--mainpath", short = '-m', help = "Specify the main path where MRI images can be found.")
p <- add_argument(p, "--participant", short = '-p', help = "Specify the subject id.")
p <- add_argument(p, "--session", short = '-s', help = "Specify the session id.")
p <- add_argument(p, "--t1", help = "Specify the T1 sequence name")
p <- add_argument(p, "--t2", help = "Specify the T2 sequence name")
p <- add_argument(p, "--flair", help = "Specify the FLAIR sequence name")
p <- add_argument(p, "--n4", help = "Specify whether to run bias correction step.", default = FALSE)
p <- add_argument(p, "--skullstripping", short = '-s', help = "Specify whether to run skull stripping step.", default = FALSE)
p <- add_argument(p, "--registration", short = '-r', help = "Specify whether to run registration step.", default = FALSE)
p <- add_argument(p, "--whitestripe", short = '-w', help = "Specify whether to run whitestripe step.", default = FALSE)
p <- add_argument(p, "--lesion", short = '-l', help = "Specify whether to extract lesion volumes.", default = TRUE)
p <- add_argument(p, "--t2type", help = "Specify the T2 sequence to use to generate T1/T2 ratio. eg: t2, flair, ws_t2, ws_flair", default = "flair")
p <- add_argument(p, "--masktype", help = "Specify the type of segmentation to use to generate ROI T1/T2 ratio. eg: fast, jlf, freesurfer", default = "freesurfer")
p <- add_argument(p, "--step", help = "Specify the step of t1t2 pipeline. estimation or consolidation.", default = "estimation")
p <- add_argument(p, "--toolpath", help = "Specify the path to the pipelines.")
argv <- parse_args(p)

# Read in Files
main_path = argv$mainpath
if (argv$step == "estimation"){
    p = argv$participant
    ses = argv$session
    message('Checking inputs...')
    if(is.na(argv$t1)) stop("Missing T1 sequence!")else{
      t1 = readnii(paste0(main_path, "/data/", p, "/", ses, "/anat/", argv$t1))
    }
    if(argv$t2type == "flair" | argv$t2type == "ws_flair"){
      if(is.na(argv$flair)) stop("Missing FLAIR sequence!")else{
        flair = readnii(paste0(main_path, "/data/", p, "/", ses, "/anat/", argv$flair))
      }
    }else if(argv$t2type == "t2" | argv$t2type == "ws_t2"){
      if(is.na(argv$t2)) stop("Missing T2 sequence!")else{
        t2 = readnii(paste0(main_path, "/data/", p, "/", ses, "/anat/", argv$t2))
      }
    }

    # Bias Correction
    if(argv$n4){
      bias.out.dir = paste0(main_path, "/data/", p, "/", ses, "/bias_correction")
      dir.create(bias.out.dir,showWarnings = FALSE)
      if(!is.na(argv$flair)){
        flair_biascorrect = bias_correct(file = flair,
                                        correction = "N4",
                                        verbose = TRUE)
        writenii(flair_biascorrect,paste0(bias.out.dir,"/FLAIR_n4.nii.gz"))
      }
      t1_biascorrect = bias_correct(file = t1,
                                   correction = "N4",
                                   verbose = TRUE)
      writenii(t1_biascorrect,paste0(bias.out.dir,"/T1_n4.nii.gz"))
      if(!is.na(argv$t2)){
        t2_biascorrect = bias_correct(file = t2,
                                   correction = "N4",
                                   verbose = TRUE)
        writenii(t2_biascorrect,paste0(bias.out.dir,"/T2_n4.nii.gz"))
        }
    }else{
      bias.out.dir = paste0(main_path, "/data/", p, "/", ses, "/bias_correction")
      t1_biascorrect = readnii(paste0(main_path, "/data/", p, "/", ses, "/bias_correction/T1_n4.nii.gz"))
      if(!is.na(argv$flair)){
        flair_biascorrect = readnii(paste0(main_path, "/data/", p, "/", ses, "/bias_correction/FLAIR_n4.nii.gz"))
      }
      if(!is.na(argv$t2)){
        t2_biascorrect = readnii(paste0(main_path, "/data/", p, "/", ses, "/bias_correction/T2_n4.nii.gz")) 
      }
    }

    # Skull Stripping
    brain.out.dir = paste0(main_path, "/data/", p, "/", ses, "/t1_brain")
    if(!argv$skullstripping){
      brain_paths = list.files(paste0(main_path, "/data/", p, "/", ses, "/t1_brain"), recursive = TRUE, full.names = TRUE)
      brain_path = brain_paths[which(grepl("*brain.nii.gz$", brain_paths))]
      brain_mask_path = brain_paths[which(grepl("*brainmask.nii.gz$", brain_paths))]
      brain_mask = readnii(brain_mask_path) 
      if(!file.exists(paste0(bias.out.dir,"/T1_brain_n4.nii.gz"))){
        t1_fslbet_robust = readnii(brain_path)
        t1_fslbet_robust = bias_correct(file = t1_fslbet_robust,
                                   correction = "N4",
                                   verbose = TRUE)
        writenii(t1_fslbet_robust,paste0(bias.out.dir,"/T1_brain_n4.nii.gz"))
      }else{
        t1_fslbet_robust = readnii(paste0(bias.out.dir,"/T1_brain_n4.nii.gz"))
      }
    }

    if (argv$skullstripping){
      dir.create(brain.out.dir,showWarnings = FALSE)
      t1_fslbet_robust = fslbet_robust(t1_biascorrect,reorient = FALSE,correct = FALSE)
      brain_mask = t1_fslbet_robust > 0 
      writenii(t1_fslbet_robust,paste0(brain.out.dir,"T1_brain.nii.gz"))
      writenii(t1_fslbet_robust,paste0(bias.out.dir,"/T1_brain_n4.nii.gz"))
      writenii(brain_mask,paste0(brain.out.dir,"T1_brainmask.nii.gz"))
    }

    # Registration to FLAIR/T2 Space
    if(!is.na(argv$flair)){
      reg.out.dir = paste0(main_path, "/data/", p, "/", ses, "/registration/FLAIR_space")
    }else if(!is.na(argv$t2)){
      reg.out.dir = paste0(main_path, "/data/", p, "/", ses, "/registration/T2_space")
    }
    if (argv$registration){
      dir.create(reg.out.dir,showWarnings = FALSE, recursive = TRUE)
      ## Register T1 to FLAIR space 
      if(!is.na(argv$flair)){
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
      }else if(!is.na(argv$t2)){
        t1_to_flair = registration(filename = t1_biascorrect,
                                 template.file = t2_biascorrect,
                                 typeofTransform = "Rigid", remove.warp = FALSE,
                                 outprefix=paste0(reg.out.dir,"/t1_reg_to_t2")) 

        t1_reg = ants2oro(antsApplyTransforms(fixed = oro2ants(t2_biascorrect), moving = oro2ants(t1_fslbet_robust),
                                            transformlist = t1_to_flair$fwdtransforms, interpolator = "welchWindowedSinc"))
        brainmask_reg = ants2oro(antsApplyTransforms(fixed = oro2ants(t2_biascorrect), moving = oro2ants(brain_mask),
                                                   transformlist = t1_to_flair$fwdtransforms, interpolator = "nearestNeighbor"))
        writenii(t1_reg, paste0(reg.out.dir,"/t1_n4_brain_reg_t2"))
        writenii(brainmask_reg, paste0(reg.out.dir,"/brainmask_reg_t2"))
        flair_n4_brain = t2_biascorrect
        flair_n4_brain[brainmask_reg==0] = 0
        writenii(flair_n4_brain, paste0(reg.out.dir,"/t2_n4_brain"))
      }
    }else{
      if(!is.na(argv$flair)){
        t1_reg = readnii(paste0(reg.out.dir, "/t1_n4_brain_reg_flair.nii.gz"))
        flair_n4_brain = readnii(paste0(reg.out.dir, "/flair_n4_brain.nii.gz"))
        brainmask_reg = readnii(paste0(reg.out.dir, "/brainmask_reg_flair"))
      }else if(!is.na(argv$t2)){
        t1_reg = readnii(paste0(reg.out.dir, "/t1_n4_brain_reg_t2.nii.gz"))
        flair_n4_brain = readnii(paste0(reg.out.dir, "/t2_n4_brain.nii.gz"))
        brainmask_reg = readnii(paste0(reg.out.dir, "/brainmask_reg_t2"))
      }
    }

    # WhiteStripe normalize data
    if(!is.na(argv$flair)){
      white.out.dir = paste0(main_path, "/data/", p, "/", ses, "/whitestripe/FLAIR_space")
    }else if(!is.na(argv$t2)){
      white.out.dir = paste0(main_path, "/data/", p, "/", ses, "/whitestripe/T2_space")
    }
    if(argv$whitestripe){
      dir.create(white.out.dir,showWarnings = FALSE, recursive = TRUE)
      ind1 = whitestripe(t1_reg, "T1")
      t1_n4_reg_brain_ws = whitestripe_norm(t1_reg, ind1$whitestripe.ind)
      ind2 = whitestripe(flair_n4_brain, "T2")
      flair_n4_brain_ws = whitestripe_norm(flair_n4_brain, ind2$whitestripe.ind)
      if(!is.na(argv$flair)){
        writenii(t1_n4_reg_brain_ws, paste0(white.out.dir,"/t1_n4_brain_reg_flair_ws"))
        writenii(flair_n4_brain_ws, paste0(white.out.dir,"/flair_n4_brain_ws"))
      }else if(!is.na(argv$t2)){
        writenii(t1_n4_reg_brain_ws, paste0(white.out.dir,"/t1_n4_brain_reg_t2_ws"))
        writenii(flair_n4_brain_ws, paste0(white.out.dir,"/t2_n4_brain_ws"))
      }
      }else{
        if(!is.na(argv$flair)){
          t1_n4_reg_brain_ws = readnii(paste0(white.out.dir, "/t1_n4_brain_reg_flair_ws"))
          flair_n4_brain_ws = readnii(paste0(white.out.dir, "/flair_n4_brain_ws"))
        }else if(!is.na(argv$t2)){
          t1_n4_reg_brain_ws = readnii(paste0(white.out.dir, "/t2_n4_brain_reg_t2_ws"))
          flair_n4_brain_ws = readnii(paste0(white.out.dir, "/t2_n4_brain_ws"))
        }
      }

    # Generate T1/T2
    t1t2.dir = paste0(main_path, "/data/", p, "/", ses, "/t1t2")
    dir.create(t1t2.dir)
    if(argv$t2type == "flair" | argv$t2type == "t2"){
        t1t2 = t1_reg/flair_n4_brain
    }else if(argv$t2type == "ws_flair" | argv$t2type == "ws_t2"){
        t1t2 = t1_n4_reg_brain_ws/flair_n4_brain_ws
    }
    t1t2[is.na(t1t2)] = 0
    writenii(t1t2, paste0(t1t2.dir,"/t1t2_", argv$t2type))

    if(argv$masktype == "fast"){
      # Apple FAST method to get 1) CSF, 2) GM, 3) WM segmentations
      t1_fast = fast(t1_reg, bias_correct = F, opts = "-t 1 -n 3")
      #writenii(t1_fast, paste0(t1t2.dir,"/t1_fast"))
      #writenii(t1_fast == 2, paste0(t1t2.dir,"/GM_fast"))
      #writenii(t1_fast == 3, paste0(t1t2.dir,"/WM_fast"))
      GM = t1_fast == 2
      WM = t1_fast == 3
      writenii(t1t2 * GM, paste0(t1t2.dir,"/t1t2_GM_fast_", argv$t2type))
      writenii(t1t2 * WM, paste0(t1t2.dir,"/t1t2_WM_fast_", argv$t2type))
      GM_mean = mean(t1t2[which(GM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      GM_median = median(t1t2[which(GM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      WM_mean = mean(t1t2[which(WM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      WM_median = median(t1t2[which(WM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      if(argv$lesion){
        mim.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/mimosa")
        mimosa_mask = readnii(paste0(mim.out.dir,"/mimosa_mask"))
        writenii(t1t2 * mimosa_mask, paste0(t1t2.dir,"/t1t2_lesion_", argv$t2type))
        lesion_mean = mean(t1t2[which(mimosa_mask > 0 & t1t2 != Inf & t1t2 != -Inf)])
        lesion_median = median(t1t2[which(mimosa_mask > 0 & t1t2 != Inf & t1t2 != -Inf)])
        t1t2_result = data.frame(cbind(subject_id = p, GM_mean, GM_median, WM_mean, WM_median, lesion_mean, lesion_median))
      }else{t1t2_result = data.frame(cbind(subject_id = p, GM_mean, GM_median, WM_mean, WM_median))}
      write_csv(t1t2_result, paste0(t1t2.dir,"/t1t2_fast_", argv$t2type, ".csv"))
    }else if(argv$masktype == "freesurfer"){
      # Get ROI masks from FreeSurfer
      rois = list.files(main_path, "^aseg.mgz", recursive = TRUE, full.names = TRUE)
      brains = list.files(path = main_path, pattern = "^brain.mgz", recursive = TRUE, full.names = TRUE)
      roi = rois[which(grepl(p, rois))]
      brain = brains[which(grepl(p, brains))]
      img = readmgz(roi)
      brain = readmgz(brain)
      L = fslr::rpi_orient(img)
      L_brain = fslr::rpi_orient(brain)
      reoriented_img = L[["img"]]
      reoriented_brain = L_brain[["img"]]
      ## register freesurfer space to flair space
      free_to_flair = registration(filename = reoriented_brain,
                                 template.file = flair_n4_brain,
                                 typeofTransform = "Rigid", remove.warp = FALSE,
                                 outprefix=paste0(reg.out.dir,"/free_reg")) 
      #writenii(free_to_flair$outfile, paste0(t1t2.dir, "/brain.freesurfer"))
      reoriented_img_reg = ants2oro(antsApplyTransforms(fixed = oro2ants(flair_n4_brain), moving = oro2ants(reoriented_img),
                                                   transformlist = free_to_flair$fwdtransforms, interpolator = "nearestNeighbor"))
      Cerebral.White.Matter = (reoriented_img_reg == 2 | reoriented_img_reg == 41)
      #writenii(Cerebral.White.Matter, paste0(t1t2.dir, "/Cerebral.White.Matter.freesurfer"))
      Cerebral.Grey.Matter = (reoriented_img_reg == 3 | reoriented_img_reg == 42)
      #writenii(Cerebral.Grey.Matter, paste0(t1t2.dir, "/Cerebral.Grey.Matter.freesurfer"))
      Cerebellum.White.Matter = (reoriented_img_reg == 7 | reoriented_img_reg == 46)
      #writenii(Cerebellum.White.Matter, paste0(t1t2.dir, "/Cerebellum.White.Matter.freesurfer"))
      Cerebellum.Grey.Matter = (reoriented_img_reg == 8 | reoriented_img_reg == 47)
      #writenii(Cerebellum.Grey.Matter, paste0(t1t2.dir, "/Cerebellum.Grey.Matter.freesurfer"))
      Choroid.Plexus = (reoriented_img_reg == 31 | reoriented_img_reg == 63)
      #writenii(Choroid.Plexus, paste0(t1t2.dir, "/Choroid.Plexus.freesurfer"))
      Thalamus = (reoriented_img_reg == 9 | reoriented_img_reg == 10 | reoriented_img_reg == 48 | reoriented_img_reg == 49)
      #writenii(Thalamus, paste0(t1t2.dir, "/Thalamus.freesurfer"))
      writenii(t1t2 * Cerebral.White.Matter, paste0(t1t2.dir,"/t1t2_Cerebral.White.Matter_freesurfer_", argv$t2type))
      writenii(t1t2 * Cerebral.Grey.Matter, paste0(t1t2.dir,"/t1t2_Cerebral.Grey.Matter_freesurfer_", argv$t2type))
      writenii(t1t2 * Cerebellum.White.Matter, paste0(t1t2.dir,"/t1t2_Cerebellum.White.Matter_freesurfer_", argv$t2type))
      writenii(t1t2 * Cerebellum.Grey.Matter, paste0(t1t2.dir,"/t1t2_Cerebellum.Grey.Matter_freesurfer_", argv$t2type))
      writenii(t1t2 * Choroid.Plexus, paste0(t1t2.dir,"/t1t2_Choroid.Plexus_freesurfer_", argv$t2type))
      writenii(t1t2 * Thalamus, paste0(t1t2.dir,"/t1t2_Thalamus_freesurfer_", argv$t2type))
      Cerebral.White.Matter_mean = mean(t1t2[which(Cerebral.White.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebral.White.Matter_median = median(t1t2[which(Cerebral.White.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebral.Grey.Matter_mean = mean(t1t2[which(Cerebral.Grey.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebral.Grey.Matter_median = median(t1t2[which(Cerebral.Grey.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebellum.White.Matter_mean = mean(t1t2[which(Cerebellum.White.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebellum.White.Matter_median = median(t1t2[which(Cerebellum.White.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebellum.Grey.Matter_mean = mean(t1t2[which(Cerebellum.Grey.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Cerebellum.Grey.Matter_median = median(t1t2[which(Cerebellum.Grey.Matter > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Choroid.Plexus_mean = mean(t1t2[which(Choroid.Plexus > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Choroid.Plexus_median = median(t1t2[which(Choroid.Plexus > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Thalamus_mean = mean(t1t2[which(Thalamus > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Thalamus_median = median(t1t2[which(Thalamus > 0 & t1t2 != Inf & t1t2 != -Inf)])
      if(argv$lesion){
        mim.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/mimosa")
        mimosa_mask = readnii(paste0(mim.out.dir,"/mimosa_mask"))
        writenii(t1t2 * mimosa_mask, paste0(t1t2.dir,"/t1t2_lesion_", argv$t2type))
        lesion_mean = mean(t1t2[which(mimosa_mask > 0 & t1t2 != Inf & t1t2 != -Inf)])
        lesion_median = median(t1t2[which(mimosa_mask > 0 & t1t2 != Inf & t1t2 != -Inf)])
        t1t2_result = data.frame(cbind(subject_id = p, Cerebral.White.Matter_mean, Cerebral.White.Matter_median, Cerebral.Grey.Matter_mean, Cerebral.Grey.Matter_median,
      Cerebellum.White.Matter_mean, Cerebellum.White.Matter_median, Cerebellum.Grey.Matter_mean, Cerebellum.Grey.Matter_median, Choroid.Plexus_mean, Choroid.Plexus_median, Thalamus_mean, Thalamus_median, lesion_mean, lesion_median))
      }else{t1t2_result = data.frame(cbind(subject_id = p, Cerebral.White.Matter_mean, Cerebral.White.Matter_median, Cerebral.Grey.Matter_mean, Cerebral.Grey.Matter_median,
      Cerebellum.White.Matter_mean, Cerebellum.White.Matter_median, Cerebellum.Grey.Matter_mean, Cerebellum.Grey.Matter_median, Choroid.Plexus_mean, Choroid.Plexus_median, Thalamus_mean, Thalamus_median))}
      write_csv(t1t2_result, paste0(t1t2.dir,"/t1t2_freesurfer_", argv$t2type, ".csv"))
    }else if(argv$masktype == "jlf"){
      ## register freesurfer space to flair space
      jif_seg = list.files(paste0(main_path, "/data/", p,  "/", ses, "/JLF"), pattern = "fused_WMGM_seg.nii.gz", recursive = TRUE, full.names = TRUE)
      reoriented_img = readnii(jif_seg)
      jlf_to_flair = registration(filename = t1_fslbet_robust,
                                 template.file = flair_n4_brain,
                                 typeofTransform = "Rigid", remove.warp = FALSE,
                                 outprefix=paste0(reg.out.dir,"/jlf_reg")) 
      reoriented_img_reg = ants2oro(antsApplyTransforms(fixed = oro2ants(flair_n4_brain), moving = oro2ants(reoriented_img),
                                                   transformlist = jlf_to_flair$fwdtransforms, interpolator = "nearestNeighbor"))
      roi_map = read_xlsx(paste0(argv$toolpath, "/pipelines/JLF/license/MUSE_ROI_Dict.xlsx"))
      roi_map = roi_map[roi_map$ROI_INDEX %in% 1:207,]
      roi_map$ROI_INDEX = as.factor(roi_map$ROI_INDEX)
      WM_index = roi_map %>% filter(TISSUE_SEG == "WM") %>% pull(ROI_INDEX)
      GM_index = roi_map %>% filter(TISSUE_SEG == "GM") %>% pull(ROI_INDEX)
      WM = (reoriented_img_reg %in% WM_index)
      #writenii(Cerebral.White.Matter, paste0(t1t2.dir, "/Cerebral.White.Matter.freesurfer"))
      GM = (reoriented_img_reg %in% GM_index)
      Thalamus_index = roi_map %>% filter(grepl("*Thalamus*", ROI_NAME)) %>% pull(ROI_INDEX)
      Thalamus = (reoriented_img_reg %in% Thalamus_index)
      #writenii(Thalamus, paste0(t1t2.dir, "/Thalamus.freesurfer"))
      writenii(t1t2 * WM, paste0(t1t2.dir,"/t1t2_WM_JLF_", argv$t2type))
      writenii(t1t2 * GM, paste0(t1t2.dir,"/t1t2_GM_JLF_", argv$t2type))
      writenii(t1t2 * Thalamus, paste0(t1t2.dir,"/t1t2_Thalamus_JLF_", argv$t2type))
      WM_mean = mean(t1t2[which(WM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      WM_median = median(t1t2[which(WM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      GM_mean = mean(t1t2[which(GM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      GM_median = median(t1t2[which(GM > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Thalamus_mean = mean(t1t2[which(Thalamus > 0 & t1t2 != Inf & t1t2 != -Inf)])
      Thalamus_median = median(t1t2[which(Thalamus > 0 & t1t2 != Inf & t1t2 != -Inf)])
      t1t2_result = data.frame(cbind(subject_id = p, WM_mean, WM_median, GM_mean, GM_median, Thalamus_mean, Thalamus_median))
      if(argv$lesion){
        mim.out.dir = paste0(main_path, "/data/", p,  "/", ses, "/mimosa")
        mimosa_mask = readnii(paste0(mim.out.dir,"/mimosa_mask"))
        writenii(t1t2 * mimosa_mask, paste0(t1t2.dir,"/t1t2_lesion_", argv$t2type))
        lesion_mean = mean(t1t2[which(mimosa_mask > 0 & t1t2 != Inf & t1t2 != -Inf)])
        lesion_median = median(t1t2[which(mimosa_mask > 0 & t1t2 != Inf & t1t2 != -Inf)])
        t1t2_result = data.frame(cbind(subject_id = p, WM_mean, WM_median, GM_mean, GM_median, Thalamus_mean, Thalamus_median, lesion_mean, lesion_median))
      }
      write_csv(t1t2_result, paste0(t1t2.dir,"/t1t2_JLF_", argv$t2type, ".csv"))
    }
}else if(argv$step == "consolidation"){
  if(argv$masktype == "jlf"){
    t1t2_files = list.files(paste0(main_path, "/data"), pattern = paste0("t1t2_JLF_", argv$t2type, ".csv"), recursive = TRUE, full.names = TRUE) 
  }else if(argv$masktype == "freesurfer"){
    t1t2_files = list.files(paste0(main_path, "/data"), pattern = paste0("t1t2_freesurfer_", argv$t2type, ".csv"), recursive = TRUE, full.names = TRUE) 
  }else if(argv$masktype == "fast"){
    t1t2_files = list.files(paste0(main_path, "/data"), pattern = paste0("t1t2_fast_", argv$t2type, ".csv"), recursive = TRUE, full.names = TRUE) 
  }
  t1t2_con = lapply(t1t2_files, function(x) return(read_csv(x))) %>% bind_rows()
  if(!file.exists(paste0(main_path, "/stats"))){
    dir.create(paste0(main_path, "/stats"))
  }
  write_csv(t1t2_con, paste0(main_path, "/stats/t1t2_", argv$t2type, ".csv"))
}