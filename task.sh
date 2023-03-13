#!/bin/sh

###########################
### global declarations ###
###########################

editor='vi'
command=''
group=''
m=false
is_file=false
is_directory=false
path=''
a=''
b=''

usage() {
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

###########################
### handling .mole file ###
###########################

# create /.mole folder if it doesn't exist
if [ ! -d "$HOME/.mole/" ]; then
  mkdir -p "$HOME/.mole/"
fi

############################
### parsing MOLE_RC file ###
############################

# checks the MOLE_RC file
changeRCfile() {
  # MOLE_RC variable not set -> error and end
  if [ -z "$MOLE_RC" ]; then
    echo "MOLE_RC variable not set."
    exit 1
  fi

  # if file under MOLE_RC doesn't exist, create it with it's path
  if [ ! -f "$MOLE_RC" ]; then
    mkdir -p "$(dirname "$MOLE_RC")" && touch "$MOLE_RC"
    # the file was created empty, so no need to parse now
    return
  fi
}
changeRCfile

###############################
### parsing editor variable ###
###############################

if [ -n "$EDITOR" ]; then
  editor=$EDITOR
elif [ -n "$VISUAL" ]; then
  editor=$VISUAL
fi

#########################
### parsing arguments ###
#########################

# -h argument resolves to just displaying usage
if [ "$1" == "-h" ]; then
  usage
  exit 0
fi

# list option option was provided (must always be the first)
if [ "$1" = "list" ]; then
  command=$1
  shift
fi

# secret-log option was provided (must always be the first)
if [ "$1" = "secret-log" ]; then
  command=$1
  shift
fi

# parse other arguments with -<opt. letter> <value>? format
while getopts ":g:ma:b:" opt; do
  case $opt in
  g)
    # -g was provided
    group="$OPTARG"
    ;;
  m)
    # -m was provided
    m=true
    ;;
  a)
    a="$OPTARG"
    ;;
  b)
    b="$OPTARG"
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
shift $((OPTIND - 1))

# only argument left should be the file/directory
if [ $# -gt 1 ]; then
  echo "Too many arguments!"
  echo
  usage
  exit 1
fi

# check for empty input -> current directory
input="$*"
if [ -z "$input" ]; then
  input='./'
fi

# check whether input was a file or a directory
if [ -f "$input" ]; then
  # -m is not allowed with FILE parameter
  if $m; then
    echo "Illegal option '-m' for opening FILE."
    echo
    usage
    exit 1
  fi

  # input is file
  is_file=true
  path="$input"
elif [ -d "$input" ]; then
  # input is directory
  is_directory=true
  path="$input"
else
  # non-existant input
  if [ "${input#${input%?}}" = '/' ]; then
    # input dir is non-existant
    echo "'$input' is not a directory."
    exit 1
  else
    # input file is not existing yet
    is_file=true
    path="$input"
  fi
fi

###############
### listing ###
###############

if [ "$command" = "list" ]; then
  # default arguments
  args='$1 ~ path'

  # for option -a
  if [ -n "$a" ]; then
    args=$args' && $2 > after'
  fi

  # for option -b
  if [ -n "$b" ]; then
    args=$args' && $2 < before'
  fi

  # for option -g
  if [ -n "$group" ]; then
    args=$args' && $4 == group'
  fi

  # add print command to arguments for awk
  args=$args' {print $1}'

  # find all unique paths to files based on set conditions
  files="$(awk -v path="$path" -v after="$a" -v before="$b" -v group="$group" -F ';' "$args" "$MOLE_RC" | sort | uniq)"

  # find the longest filepath
  indent=0
  for line in $files; do
    len=${#line}
    if [ "$len" -gt "$indent" ]; then
      indent="$len"
    fi
  done

  # write out every filepath with it's groups
  echo "$files" | while IFS= read -r line; do
    local_indent=$((indent - ${#line} + 1))
    groups="$(awk -v path="$line" -F ';' '$1 ~ path && $4 {print $4}' "$MOLE_RC" | uniq | sort | tr '\n' ', ')"
    printf "%s:%${local_indent}s%s\n" "$line" "" "${groups%?}"
  done
  exit
fi

################################
### handling directory input ###
################################

if $is_directory; then
  # default arguments
  args='$1 ~ path'

  # for option -a
  if [ -n "$a" ]; then
    args=$args' && $2 > after'
  fi

  # for option -b
  if [ -n "$b" ]; then
    args=$args' && $2 < before'
  fi

  # for option -g
  if [ -n "$group" ]; then
    args=$args' && $4 == group'
  fi

  # add print command to arguments for awk
  args=$args' {print $1}'

  line=''
  if $m; then
    # find the mostly occuring line based on set confition
    line="$(awk -v path="$path" -v after="$a" -v before="$b" -v group="$group" -F ';' "$args" "$MOLE_RC" | awk '{ count[$0]++ } END { for(line in count) print line, count[line] }' | sort -k2nr | head -1 | awk '{print $1}')"
  else
    # find the last line in file based on set conditions
    line="$(awk -v path="$path" -v after="$a" -v before="$b" -v group="$group" -F ';' "$args" "$MOLE_RC" | tail -n -1 | awk -F ';' '{print $1}')"
  fi

  # if no line was found show error message and exit with error
  if [ -z "$line" ]; then
    echo "No file has ever been opened in '$(realpath "$path")' with set parameters."
    exit 1
  fi

  # overwrite the path to the now opening file
  path="$line"
  is_directory=false
  is_file=true
fi

######################
### opening editor ###
######################

# $editor "$path"
mkdir -p "$(dirname "$path")" && touch "$path"

############################
### saving the open data ###
############################

realpath="$(realpath "$path")"
echo "otviram: $realpath"

if $is_file; then
  echo "$realpath;$(date "+%Y-%m-%d;%H-%M-%S");$group" >>"$MOLE_RC"
fi
