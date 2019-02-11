#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is template script for a simple fixed processing pipeline


# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

This is template script for a simple fixed processing pipeline.

example:
      $(basename $0) <input image> <output basename> --setting=10 --option=true

usage: $(basename $0)
      obligatory arguments
        <input image> : the input image to process
      optional arguments
        [<output basename>] : the base name of the output (default: <input>)
        [--setting=<some setting parameter>] (default: 10)
        [--option=<some option flag>] (default: yes)

EOF
}


# ------------------------------ #
# definitions and settings
# ------------------------------ #
# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# set defaults
arg=""
setting=10
option=true

# parse the input arguments
for a in "$@" ; do
  case $a in
    -s=*|--setting=*)   setting="${a#*=}"; shift ;;
    -o=*|--option=*)    option="${a#*=}"; shift ;;
    *)                  arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
img=$(echo $argobl | awk '{print $1}')
base=$(echo $argobl | awk '{print $2}')

# check if obligatory arguments have been set
if [[ -z $img ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the input image."
  usage; exit 1
fi
[[ -z $base ]] && base="$img"

# remove img and base from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$img") || true
arg=$(echo $arg | tr " " "\n" | grep -v "$base") || true

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $arg
  usage; exit 1
fi


# ------------------------------ #
# the meat of the code is below
# ------------------------------ #

# step A
echo "  processing step A with setting at $setting"
# do some initial thing

# step B
if [[ $option == true ]] ; then
  echo "  processing step B with the magic option"
  # do something else
else
  echo "  processing step B without the magic option"
  # do something else
fi

# step C
echo "  processing step C"
# do one final thing

echo "  done"
