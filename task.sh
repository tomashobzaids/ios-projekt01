#!/bin/bash

editor='vi'
command=''
group=''
m=false
is_file=false
is_directory=false

# MOLE_RC variable not set -> error and end
if [[ $MOLE_RC == '' ]]; then
  echo "MOLE_RC variable not set."
  exit 1;
fi

# if file under MOLE_RC doesn't exist, create it with it's path
if [ ! -f "$MOLE_RC" ]; then
    mkdir -p "$(dirname "$MOLE_RC")" && touch "$MOLE_RC"
fi

usage()
{
    echo 'USAGE'
    # echo "mole <command> [-h] [-g GROUP] -[m] [FILTERS] [FILE/DIRECTORY]"
    # echo

    # printf "Usage: "
    # echo "mole -h"
    # echo "       mole [-g GROUP] FILE"
    # echo "       mole [-m] [FILTERS] [DIRECTORY]"
    # echo "       mole list [FILTERS] [DIRECTORY]"
    # echo "       mole secret-log [-b DATE] [-a DATE] [DIRECTORY1 [DIRECTORY2 [...]]]"
    # echo
    # printf "Options: "
    # echo "g       File opening will be added to [GROUP]"
    # echo "         m       Opens a file in directory that has been opened the most."
    # echo "         list    Lists files in directory that have been edited using this program."
}

# no arguments were provided
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# -h argument resolves to just displaying usage
if [ "$1" == "-h" ]; then
    usage
    exit 0
fi

# list option option was provided (must always be the first)
if [ "$1" == "list" ]; then
    command=$1
    shift
fi

# secret-log option was provided (must always be the first)
if [ "$1" == "secret-log" ]; then
    command=$1
    shift
fi

# parse other arguments with -<opt. letter> <value>? format
while getopts ":g:m" opt; do
  case $opt in
    g)
      # -g was provided
      group=$OPTARG
      ;;
    m)
      # -m was provided
      m=true
      ;;
    \?)
      # invalid option handle
      echo "Invalid option: -$OPTARG" >&2
      echo
      usage
      exit 1
      ;;
    :)
      # option without and argument (value) handle
      echo "error: Option -$OPTARG requires an argument." >&2
      echo
      usage
      exit 1
      ;;
  esac
done

# remove arguments from argument array
shift $(($OPTIND - 1))

# no unparsed arguments were left -> no file/dir was provided
if [[ ${@: -1} == "" ]]; then
  echo "error: An input file/directory must be provided."
  echo
  usage
  exit 1
fi

# check whether input was a file or a directory
if [[ -f ${@: -1} ]]; then
  # -m is not allowed with FILE parameter
  if $m; then
    echo "Illegal option '-m' for opening FILE."
    echo
    usage
    exit 1
  fi

  # input is file
  is_file=true
elif [[ -d ${@: -1} ]]; then
  # input is directory
  is_directory=true;
else
  # input file/dir is non-existant
  echo "'${@: -1}' is not a file nor a directory."
  echo
  usage
  exit 1
fi


echo "command      - '$command'"
echo "group        - '$group'"
echo "m            - '$m'"
echo "is_file      - '$is_file'"
echo "is_directory - '$is_directory'"