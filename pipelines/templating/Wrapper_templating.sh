#!/bin/bash
umask u+rw,g+rw # give group read/write permissions to all new files

## GENERAL SETTINGS
main=/your_path/ # to data directory
main_root=/your_path/ #to output directory if different 
morf_dir=/path_to_mmorf/ #input path to where you have downloaded mmorf
script_dir=$main/scripts/Template #or change to your won script dir

## TO CHOOSE TASK TO PERFORM FROM THE LIST BELOW
tasks="finish_mask"
## finish_mask apply_mask bias_corr norm_int init_targ aff_reg create_temp_0 nonlin_reg unbias_warp create_temp
iter=""
## set iteration for tasks: nonlinereg unbiaswarp create_temp, ("1a" "1b" "2a" "2b" "3a" "3b" "4a" "4b" "5a" "5b")
## if not set will check if files have been created at previous iteration to determine which iteration to do

## if want to run all iteration at once ucomment the following (set for running iteration from 1a->5b)
# tasks+=" nonlin_reg unbias_warp create_temp" #1a
# tasks+=" nonlin_reg unbias_warp create_temp" #1b
# tasks+=" nonlin_reg unbias_warp create_temp" #2a
# tasks+=" nonlin_reg unbias_warp create_temp" #2b
# tasks+=" nonlin_reg unbias_warp create_temp" #3a
# tasks+=" nonlin_reg unbias_warp create_temp" #3b
# tasks+=" nonlin_reg unbias_warp create_temp" #4a
# tasks+=" nonlin_reg unbias_warp create_temp" #4b
# tasks+=" nonlin_reg unbias_warp create_temp" #5a
# tasks+=" nonlin_reg unbias_warp create_temp" #5b


sh $script_dir/templating.sh -r $main_root -t "${tasks}" -m $morf_dir -i "${iter}"



