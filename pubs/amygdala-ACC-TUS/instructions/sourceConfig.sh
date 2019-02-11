#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# specify the study and dataset origin
flgStudy="amygdala-ACC-TUS" # offlineTUS, amygdala-ACC-TUS
flgCity="Oxford" # Oxford, Paris

# specify the dataset version (denoted with a suffix), based on the study
suffixClean="EroWMCSF"

# specify to work on the group- or a run-specific dataset
suffixAnaLevelList="group"

# specify the datatype
flgDataType="data"

# specify to cap the Fisher's z-stats
flgCapStat=1

# specify whether this is a validation analysis
flgValidate=0

# specify the fingerprint summary statistic
flgSummaryStat="MEAN"

# specify data based on flag settings (above)
suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
suffixConn=".clean${suffixClean}"

# adjust the suffix based on the flags
[[ $flgValidate -eq 1 ]] && suffixValidate=".validation" || suffixValidate=""
[[ $flgValidate -eq 1 ]] && suffixConn+=$suffixValidate
[[ $flgCapStat -eq 0 ]] && suffixConn+=".noCap"

# specify the analysis level: SUBJRUN, SESSRUN, RUN, SESS, SUBJ, GROUP, or any combination (RUN_SUBJ_GROUP)
flgLevel="GROUP"

# specify which runs to consider for the RUN level analysis
runList="run1 run2 run3"

# specify the surface version
surf="F99_10k"
