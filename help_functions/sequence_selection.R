library(neurobase)
library(oro.dicom)
library(tidyverse)
.libPaths(c("/misc/appl/R-4.1/lib64/R/library","/home/zhengren/Desktop/cluster_set_up/r_packages", "/appl/dcm2niix-1.0.20230411/bin/dcm2niix"))


## Select Imaging Sequence
main_path = "/home/zhengren/Desktop/Project/R01_resubmission_files_for_Taki"
tran_path = paste0(main_path, "/transformed_data")
system(paste0("mkdir ", tran_path))
subject = list.files(tran_path)

seq_info_gen = function(main_path, p){
    ses = list.files(paste0(main_path, "/", p))
    info_df = expand_grid(p, ses)
    summary_df = lapply(1:nrow(info_df), function(i) {
        files = list.files(paste0(main_path, "/", info_df[i, "p"], "/", info_df[i, "ses"]))
        s_files = files[which(grepl("^s", files))]
        acq_info = lapply(s_files, function(x) {
            path_name = list.files(paste0(main_path, "/", info_df[i, "p"], "/", info_df[i, "ses"], "/", x), full.names = TRUE)[1]
            dcm_file = readDICOM(path = path_name)$hdr[[1]] 
            name = dcm_file %>%
                    filter(name == "ProtocolName") %>%
                    pull(value)
            date = dcm_file %>%
                    filter(name == "StudyDate") %>%
                    pull(value)
                    return(list("name" = name, "date" = date))})
        acq_name = sapply(1:length(acq_info), function(i) acq_info[[i]]$name, USE.NAMES = FALSE)
        acq_date = sapply(1:length(acq_info), function(i) acq_info[[i]]$date, USE.NAMES = FALSE)
        subject = rep(info_df[[i, "p"]], length(s_files))
        ses = rep(info_df[[i, "ses"]], length(s_files))
        sub_df = data.frame(cbind(subject, ses, s_files, acq_name, acq_date))
        colnames(sub_df) = c("subject", "ses", "seq", "seq_name", "acq_date")
        rownames(sub_df) = NULL
        return(sub_df)
    }) %>% bind_rows()

    summary_df = summary_df %>% filter(grepl("T1_MPRAGE", seq_name) | grepl("T2_FLAIR", seq_name) | grepl("T2STAR_segEPI$", seq_name))
    return(summary_df)
}

summary_df = lapply(subject, function(x) seq_info_gen(tran_path, x)) %>% bind_rows()
#write_csv(summary_df, "/home/zhengren/Desktop/Project/R01_resubmission_files_for_Taki/info.csv")

# Convert dicom to nifti
Sys.setenv(PATH = paste("/appl/dcm2niix-1.0.20230411/bin/dcm2niix:", Sys.getenv("PATH"), sep=""))
bids_path = paste0(main_path, "/data")
system(paste0("mkdir ", bids_path))
dcm_to_nii = function(i, summary_df, main_path){
    dcm_path = paste0(main_path, "/transformed_data/", summary_df[[i, "subject"]], "/", summary_df[[i, "ses"]], "/", summary_df[[i, "seq"]], "/")
    nii_path = paste0(bids_path, "/", summary_df[[i, "subject"]], "/", summary_df[[i, "ses"]], "/anat")
    system(paste0("mkdir -p ", nii_path))
    system(paste0("dcm2niix -p n -o ", nii_path, " -z y ", dcm_path))
}

lapply(1:nrow(summary_df), function(i) dcm_to_nii(i, summary_df, main_path))





list.files(main_path, pattern = "^s*", recursive = TRUE, full.names = TRUE)
list.files(main_path, pattern = "^s*", recursive = TRUE, full.names = TRUE)
# Remove unnecessary nesting in directory structure
find_dup_cmd <- "find /project/UVMdata/MSCog-upload-2023-10-06/data/dicoms_unzip -maxdepth 2 -name '20*'"
dup_dirs <- system(find_dup_cmd, intern = TRUE)
if (length(dup_dirs) > 1){
    for (d in dup_dirs){
    seqs_to_move <- list.files(path = d, pattern = '^s[0-9]+', full.names = TRUE)
    new_loc <- str_remove(d, pattern = "/[0-9]{8}-[0-9]{4}$")
    for (s in seqs_to_move){
    mv_cmd <- paste("mv", s, new_loc)
    system(mv_cmd)
    }
    rm_cmd <- paste("rm -rf", d)
    system(rm_cmd)
}
}


order_by_file_priority <- function(files){
    num_files <- length(files)
    ordered_files <- rep(NA, num_files)
    avail_files <- files
    for (n in num_files:1){
        orig_zip_pat <- "[Mm][Ss][Cc][Oo][Gg]_[0-9]+\\.zip"
        recon_pat <- "recon\\.zip$"
        if (any(str_detect(avail_files,pattern = orig_zip_pat))){
            ordered_files[n] <- avail_files[which(str_detect(avail_files,
            pattern = orig_zip_pat))]
            indx_remove <- which(str_detect(avail_files,pattern = orig_zip_pat))
            avail_files <- avail_files[-indx_remove]
        } else if (any(str_detect(avail_files, pattern = recon_pat))) {
            ordered_files[n] <- avail_files[which(str_detect(avail_files,
            pattern = recon_pat))]
            indx_remove <- which(str_detect(avail_files, pattern = recon_pat))
            avail_files <- avail_files[- indx_remove]
        } else {
            single_seq_indx <- str_detect(avail_files,pattern = paste(recon_pat, orig_zip_pat, sep = "|"),
            negate = TRUE)
            ordered_files[n] <- avail_files[single_seq_indx]
            avail_files <- avail_files[- single_seq_indx]
        }
    }
    return(ordered_files)
    }

dicom_dirs <- list.files(
    path = "/project/UVMdata/MSCog-upload-2023-10-06/data/dicoms_unzip"
    )
subjs <- unique(
    str_replace_all(dicom_dirs,
    pattern = "^[Mm][Ss][Cc][Oo][Gg]_([0-9]+).*",
    replace = "\\1")
    )
for (s in subjs){
    found_mprage <- FALSE
    found_flair <- FALSE
    found_epi <- FALSE
    dest_dir = paste0("/project/UVMdata/MSCog-upload-2023-10-06/data/pre_bids_anat/",s)
    if (!dir.exists(dest_dir)) {
        make_dir_command <- paste("mkdir -p",dest_dir)
        system(make_dir_command)
    }
    subj_dicom_files <- list.files(
        path = "/project/UVMdata/MSCog-upload-2023-10-06/data/dicoms_unzip/",
        pattern = s
    )
    if (length(subj_dicom_files) > 1) {
        subj_dicoms_ordered <- order_by_file_priority(subj_dicom_files)
    } else {
        subj_dicoms_ordered <- subj_dicom_files
    }
    for (d in subj_dicoms_ordered){
        seqs <- list.files(path = paste0("/project/UVMdata/MSCog-upload-2023-10-06/data/dicoms_unzip/",d), full.names = TRUE,pattern = '^s[0-9]+')
        for (seq in seqs){
            if (found_mprage == TRUE && found_flair == TRUE && found_epi == TRUE){
                break
            }
            acq_name <- readDICOM(path = paste0(seq, "/i00001.dcm"))$hdr[[1]] %>%
                filter(name == "ProtocolName") %>%
                pull(value)
            if (acq_name == "WIP 3D_T1_MPRAGE" && found_mprage == FALSE) {
                cp_mprage_cmd <- paste("cp -r", seq, dest_dir)
                system(cp_mprage_cmd)
                found_mprage <- TRUE
            } else if (acq_name == "WIP 3D_T2_FLAIR" && found_flair == FALSE) {
                cp_flair_cmd <- paste("cp -r", seq, dest_dir)
                system(cp_flair_cmd)
                found_flair <- TRUE
            } else if(acq_name == "WIP 3D_T2STAR_segEPI" && found_epi == FALSE) {
		        cp_epi_cmd <- paste("cp -r", seq, dest_dir)
                system(cp_epi_cmd)
                found_epi <- TRUE
            }
        }
    }
}
