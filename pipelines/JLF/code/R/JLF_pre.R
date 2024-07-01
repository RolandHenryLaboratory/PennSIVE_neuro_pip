suppressMessages(library(argparser))
suppressMessages(library(ANTsR))
suppressMessages(library(extrantsr))
suppressMessages(library(neurobase))
suppressMessages(library(oro.nifti))
suppressMessages(library(oro.dicom))
suppressMessages(library(parallel))
suppressMessages(library(readxl))
suppressMessages(library(tidyverse))

p <- arg_parser("Registrating atlas and label to target images preparing for JLF ", hide.opts = FALSE)
p <- add_argument(p, "--mainpath", short = '-m', help = "Specify the main path where MRI images can be found.")
p <- add_argument(p, "--participant", short = '-p', help = "Specify the subject id.")
p <- add_argument(p, "--session", short = '-s', help = "Specify the session.")
p <- add_argument(p, "--t1", help = "Specify the T1 sequence name")
p <- add_argument(p, "--type", help = "Specify which type of templates to use: WMGM, thal", default = "WMGM")
p <- add_argument(p, "--num", short = '-n', help = "Specify the number of templates used.", default = 15)
p <- add_argument(p, "--template", help = "Specify the path to the template.", default = "/project/MRI_Templates")
p <- add_argument(p, "--step", help = "Specify the step of JLF pipeline. registration or extraction.", default = "registration")
p <- add_argument(p, "--lesion", short = '-l', help = "Specify whether to extract lesion volumes.", default = TRUE)
p <- add_argument(p, "--toolpath", help = "Specify the path to the pipelines.")
argv <- parse_args(p)

main_path = argv$mainpath
p = argv$participant
s = argv$session
t1_pattern = argv$t1
type = argv$type
num = argv$num
temp = argv$template
if(argv$step == "registration"){
    outdir = paste0(main_path, "/data/", p, "/", s, "/JLF")
    JLF.dir = file.path(outdir, sprintf("JLF_%s", type))
    out_atlas_dir = file.path(JLF.dir, "atlas_to_t1")
    out_seg_dir = file.path(JLF.dir, "seg_to_t1")
    dir.create(out_atlas_dir, recursive = TRUE)
    dir.create(out_seg_dir, recursive = TRUE)

    files = list.files(paste0(main_path, "/data/", p, "/", s), recursive = TRUE, full.names = TRUE)
    t1 = files[which(grepl(t1_pattern, files))]

    if (type == 'WMGM'){
        in_atlas = paste0(temp, "/MUSE_Templates/WithCere/Template%s.nii.gz")
        in_seg = paste0(temp, "/MUSE_Templates/WithCere/Template%s_label.nii.gz")
    } else if (type == 'thal'){
        in_atlas = paste0(temp, "/OASIS-atlases/OASIS-TRT-20-%s/rai_t1weighted_brain.nii.gz")
        in_seg = paste0(temp, "/OASIS-atlases/OASIS-TRT-20-%s/rai_thalamus_atlas_20-%s.nii.gz")
    }

    reg_atlas_and_seg = function(j){
        t1.nii = neurobase::readnii(t1)
        atlas = sprintf(in_atlas, j)
        n = stringr::str_count(in_seg, "%s")
        seg = do.call("sprintf", c(list(in_seg), as.list(rep(j, stringr::str_count(in_seg, "%s")))))

        message(sprintf("Registering atlas to %s", t1))
        atlas_to_image = registration(filename = atlas,
                                        template.file = t1.nii,
                                        typeofTransform = "SyN", remove.warp = FALSE)

        message(sprintf("Applying transforms"))
        atlas_reg = antsApplyTransforms(fixed = oro2ants(t1.nii), moving = oro2ants(readnii(atlas)),
                                       transformlist = atlas_to_image$fwdtransforms, interpolator = "nearestNeighbor")
        seg_reg = antsApplyTransforms(fixed = oro2ants(t1.nii), moving = oro2ants(readnii(seg)),
                                       transformlist = atlas_to_image$fwdtransforms, interpolator = "nearestNeighbor")

        antsImageWrite(atlas_reg, file.path(out_atlas_dir, sprintf("jlf_template_reg%s.nii.gz", j)))
        antsImageWrite(seg_reg, file.path(out_seg_dir, sprintf("jlf_%s_reg%s.nii.gz", type, j)))
    }

    for(j in 1:num){
        # Run registration only if files are not found
        if(!file.exists(file.path(out_atlas_dir, sprintf("jlf_template_reg%s.nii.gz", j))) ||
           !file.exists(file.path(out_seg_dir,sprintf("jlf_%s_reg%s.nii.gz", type, j)))){
               reg_atlas_and_seg(j)
           } 
    }
}else if(argv$step == "extraction"){
    lesion = argv$lesion
    roi_map = read_xlsx(paste0(argv$toolpath, "/pipelines/JLF/index/MUSE_ROI_Dict.xlsx"))
    roi_map = roi_map[roi_map$ROI_INDEX %in% 1:207,]
    roi_map$ROI_INDEX = as.factor(roi_map$ROI_INDEX)
    get_volume = function(p, s, type, lesion){
    seg_file = list.files(paste0(main_path, "/data/", p, "/", s, "/JLF"), paste0("fused_", type, "*"), recursive = TRUE, full.names = TRUE)
    seg = readnii(seg_file)
    vol_table = table(seg)[-1] * voxres(seg, units = "mm")
    vol_df = data.frame(vol_table)
    colnames(vol_df) = c("index", "volume_mm3")
    vol_df$volume_mm3 = as.numeric(vol_df$volume_mm3)
    vol_df = vol_df %>% left_join(roi_map %>% dplyr::select(ROI_INDEX, TISSUE_SEG, ROI_NAME), by = c("index" = "ROI_INDEX")) %>% na.omit()
    roi_df = vol_df %>% dplyr::select(ROI_NAME, volume_mm3) %>% pivot_wider(names_from = "ROI_NAME", values_from = "volume_mm3")
    tissue_summary = vol_df %>% group_by(TISSUE_SEG) %>% summarize(volume_mm3 = sum(volume_mm3)) %>% filter(TISSUE_SEG != "NONE") %>% pivot_wider(names_from = "TISSUE_SEG", values_from = "volume_mm3")
    colnames(tissue_summary) = paste0("Tissue_", colnames(tissue_summary))
    roi_volume = cbind(roi_df, tissue_summary) %>% mutate(subject_id = p, session = s)
    roi_volume = roi_volume[c("subject_id", "session", colnames(roi_volume)[1:(length(colnames(roi_volume))-2)])]
    if(lesion){
      mimosa_file = list.files(paste0(main_path, "/data/", p, "/", s), "mimosa_mask.nii.gz", recursive = TRUE, full.names = TRUE)
      mimosa_mask = readnii(mimosa_file)
      lesion_volume = table(mimosa_mask)[-1] * voxres(mimosa_mask, units = "mm")
      roi_volume = cbind(roi_volume, lesion_volume)
    }
    return(roi_volume)
  }
  result_files =list.files(paste0(main_path, "/data"), paste0("fused_", type, "*"), recursive = TRUE, full.names = TRUE)
  patient = sapply(result_files, function(x) str_split(x, "/")[[1]][length(str_split(x, "/")[[1]])-5], USE.NAMES = FALSE)
  session = sapply(result_files, function(x) str_split(x, "/")[[1]][length(str_split(x, "/")[[1]])-4], USE.NAMES = FALSE)
  result_df = lapply(1:length(patient), function(x) get_volume(p = patient[x], s = session[x], type = type, lesion = lesion)) %>% bind_rows()
  names = colnames(result_df)
  general_names = names[which(grepl("Tissue_*", names))]
  mimosa_name = "lesion_volume"
  roi_names = setdiff(names, general_names)
  roi_names = setdiff(roi_names , mimosa_name)
  result_df = result_df[c(roi_names, general_names, mimosa_name)]
  
  if(!file.exists(paste0(main_path, "/stats"))){
      dir.create(paste0(main_path, "/stats"))
    }
    
  write_csv(result_df, paste0(main_path, "/stats/JLF_", type, ".csv"))
}