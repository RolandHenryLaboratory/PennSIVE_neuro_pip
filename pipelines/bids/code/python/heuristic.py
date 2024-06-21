import os
##################### Create keys for each acquisition type ####################

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

# Structural scans
t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-00{item:01d}_T1w')

t2_flair = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-00{item:01d}_FLAIR')	

t2_star = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-00{item:01d}_T2star')

# Functional scans
func_rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-00{item:01d}_bold')
func_rest_matrix96 =  create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-00{item:01d}_bold')
func_rest_matrix96_sbref =  create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-00{item:01d}_sbref')

# Fmap scans
fmap_mag =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_phasediff')

# DWI scans
dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_run-00{item:01d}_dwi')

############################ Define heuristic rules ############################

def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where
    allowed template fields - follow python string module:
    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """
    
    # Info dictionary to map series_id's to correct create_key key
    info = {
        t1w: [], 
	t2_flair: [],
	t2_star: [],
    func_rest: [],
    func_rest_matrix96: [],
    func_rest_matrix96_sbref: [],
    fmap_mag: [],
    fmap_phase: [],
    dwi: []
        }

    def get_latest_series(key, s):
        info[key].append(s.series_id)

    for s in seqinfo:

        if "3D_T1_MPRAGE" in s.protocol_name:
            get_latest_series(t1w, s)

        elif "3D_T2_FLAIR" in s.protocol_name:
            get_latest_series(t2_flair, s)
	    
        elif "WIP 3D_T2STAR_segEPI" in s.protocol_name and "sWIP" not in s.protocol_name:
            get_latest_series(t2_star, s)

    return info
