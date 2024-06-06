suppressMessages(library(argparser))
suppressMessages(library(ANTsR))
suppressMessages(library(extrantsr))
suppressMessages(library(neurobase))
suppressMessages(library(tidyverse))
suppressMessages(library(oro.nifti))
suppressMessages(library(oro.dicom))
suppressMessages(library(fslr))
suppressMessages(library(freesurfer))
suppressMessages(library(readxl))

p <- arg_parser("Freesurfer Estimation Extraction.", hide.opts = FALSE)
p <- add_argument(p, "--mainpath", short = '-m', help = "Specify the main path where MRI images can be found.")
p <- add_argument(p, "--participant", short = '-p', help = "Specify the name of the participant if run individually.")
p <- add_argument(p, "--session", short = '-s', help = "Specify the session name of the participant if run individually.")
p <- add_argument(p, "--parc", help = "Specify the parcellation to compute on: aparc, aparc.a2009s. Default is aparc.", default = "aparc")

argv <- parse_args(p)
main_path = argv$mainpath
p = argv$participant
s = argv$session
parc = argv$parc

outdir = paste0(main_path, "/data/", p, "/", s, "/freesurfer/stats_csv")
dir.create(outdir)


# Parcellation Stats Table
## Cortical Thickness
thick_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "thickness", parc = parc)
thick_lh_df = read_fs_table(thick_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(thick_lh_df, paste0(outdir, "/lh_cortical_thickness.csv"))
thick_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "thickness", parc = parc)
thick_rh_df = read_fs_table(thick_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(thick_rh_df, paste0(outdir, "/rh_cortical_thickness.csv"))
## Area
area_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "area", parc = parc)
area_lh_df = read_fs_table(area_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(area_lh_df, paste0(outdir, "/lh_cortical_area.csv"))
area_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "area", parc = parc)
area_rh_df = read_fs_table(area_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(area_rh_df, paste0(outdir, "/rh_cortical_area.csv"))
## Cortical Volume
volume_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "volume", parc = parc)
volume_lh_df = read_fs_table(volume_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(volume_lh_df, paste0(outdir, "/lh_cortical_volume.csv"))
volume_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "volume", parc = parc)
volume_rh_df = read_fs_table(volume_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(volume_rh_df, paste0(outdir, "/rh_cortical_volume.csv"))
## thicknessstd
thicknessstd_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "thicknessstd", parc = parc)
thicknessstd_lh_df = read_fs_table(thicknessstd_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(thicknessstd_lh_df, paste0(outdir, "/lh_cortical_thicknessstd.csv"))
thicknessstd_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "thicknessstd", parc=parc)
thicknessstd_rh_df = read_fs_table(thicknessstd_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(thicknessstd_rh_df, paste0(outdir, "/rh_cortical_thicknessstd.csv"))

## meancurv
meancurv_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "meancurv", parc = parc)
meancurv_lh_df = read_fs_table(meancurv_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(meancurv_lh_df, paste0(outdir, "/lh_cortical_meancurv.csv"))
meancurv_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "meancurv", parc = parc)
meancurv_rh_df = read_fs_table(meancurv_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(meancurv_rh_df, paste0(outdir, "/rh_cortical_meancurv.csv"))

## gauscurv
gauscurv_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "gauscurv", parc = parc)
gauscurv_lh_df = read_fs_table(gauscurv_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(gauscurv_lh_df, paste0(outdir, "/lh_cortical_gauscurv.csv"))
gauscurv_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "gauscurv", parc = parc)
gauscurv_rh_df = read_fs_table(gauscurv_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(gauscurv_rh_df, paste0(outdir, "/rh_cortical_gauscurv.csv"))

## foldind
foldind_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "foldind", parc = parc)
foldind_lh_df = read_fs_table(foldind_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(foldind_lh_df, paste0(outdir, "/lh_cortical_foldind.csv"))
foldind_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "foldind", parc = parc)
foldind_rh_df = read_fs_table(foldind_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(foldind_rh_df, paste0(outdir, "/rh_cortical_foldind.csv"))

## curvind
curvind_outfile_lh = aparcstats2table(subjects = "freesurfer",
                    hemi = "lh",
                    meas = "curvind", parc = parc)
curvind_lh_df = read_fs_table(curvind_outfile_lh) %>% mutate(subject = p, session = s)
write_csv(curvind_lh_df, paste0(outdir, "/lh_cortical_curvind.csv"))
curvind_outfile_rh = aparcstats2table(subjects = "freesurfer",
                    hemi = "rh",
                    meas = "curvind", parc = parc)
curvind_rh_df = read_fs_table(curvind_outfile_rh) %>% mutate(subject = p, session = s)
write_csv(curvind_rh_df, paste0(outdir, "/rh_cortical_curvind.csv"))

# ASEG
seg_outfile = asegstats2table(subjects = "freesurfer", meas = "mean")
df_seg = read_fs_table(seg_outfile) %>% mutate(subject = p, session = s)
write_csv(df_seg, paste0(outdir, "/aseg.csv"))


