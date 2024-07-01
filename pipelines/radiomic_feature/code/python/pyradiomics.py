from __future__ import print_function
import six
import os  # needed navigate the system to get the input data
import radiomics
from radiomics import featureextractor  # This module is used for interaction with pyradiomics
import pandas as pd
import numpy as np
#from multiprocessing import cpu_count, Pool
#import dask.dataframe as dd
#from dask.multiprocessing import get
import sys
#/home/zhengren/Desktop/Project/R01_resubmission_files_for_Taki/data/MSDC_078/Archive/feature_extraction/FE_input_file/py_input.csv
params = {
   'normalize': False, 
   'correctMask': True,
   'binWidth': 5
}
extractor = featureextractor.RadiomicsFeatureExtractor(**params)
pre_input_df = pd.read_csv(sys.argv[1])

def pyradiomic_function(x):
    result = extractor.execute(x["Image"], x["Mask"])
    extraction_result = {}
    for key, value in six.iteritems(result):
        extraction_result[key]= [value]
    extraction_result_df = pd.DataFrame(extraction_result)
    extraction_result_df["subject"] = x["subject"]
    extraction_result_df["session"] = x["session"]
    extraction_result_df["roi"] = x["roi"].replace("lesion_", "") 
    extraction_result_df["modality"]=x["modality"]
    return extraction_result_df

#ddata_pre = dd.from_pandas(pre_input_df, npartitions=10)
pre_input_df["feacture_extraction"] = pre_input_df.apply((lambda x: pyradiomic_function(x)), axis=1)
#pre_input_df["feacture_extraction"] = ddata_pre.map_partitions(lambda pre_input_df: pre_input_df.apply((lambda x: pyradiomic_function(x)), axis=1), meta = pd.DataFrame).compute()
pre_py_features = pd.DataFrame()
for df1 in pre_input_df["feacture_extraction"]:
    pre_py_features = pd.concat([pre_py_features, df1])

pre_py_features.to_csv(sys.argv[2])




