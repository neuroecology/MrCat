
# warp F99 coordinates to MNI space
echo "warping F99 coordinates to MNI"
MNIref=$MRCATDIR/data/macaque/MNI/MNI
F99ref=$MRCATDIR/data/macaque/F99/F99
warp=$MRCATDIR/data/macaque/transform/MNI_to_F99_warp # yes, this is the inverse warp
# coordinates
echo 24.8 -12.7 8.2 | std2imgcoord -std $F99ref -img $MNIref -warp $warp -mm -
