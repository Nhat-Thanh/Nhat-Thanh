#!/bin/bash

TRUE=1
FALSE=0
SRC_DIR=""
HDR_DIR=""
SRC_EXT="c"
HDR_EXT="h"
OVERRIDE=$FALSE
VERBOSE=$FALSE
FORCE=$FALSE

function is_hdr() {
	# $1 a string, file name
	IS_HDR=$FALSE
	[[ $(grep -oe '\.[hH][pP]\{2\}\?$' <<< "$1") ]] && IS_HDR=$TRUE
	echo $IS_HDR
}

function is_src() {
	# $1 a string, file name
	IS_SRC=$FALSE
	[[ $(grep -oe '\.[cC][pPxX]\{2\}\?$' <<< "$1") ]] && IS_SRC=$TRUE
	echo $IS_SRC
}

function empty() {
	# $1 a string, file name
	EMPTY=$FALSE
	[[ -f "$1" && $(cat "$1") == "" ]] && EMPTY=$TRUE
	echo $EMPTY
}

function rmext() {
	# $1: a string, file name
	sed -e 's/\.[a-zA-Z0-9]*$//g' <<< "$1"
	
}

function find_header() {
	# $1: a string, a source file
	NAME_WITHOUT_EXT=$(rmext "$1")
	ls | grep -oe "$NAME_WITHOUT_EXT\.[hH][pP]\{2\}\?"
}

function is_hdr_existed() {
	# $1: a string, source file
	IS_EXISTED=$FALSE
	[[ $(find_header "$1") ]] && IS_EXISTED=$TRUE
	echo $IS_EXISTED
}

function print_usage() {
	printf "mkhdr [OPTIONS] [FILE]\n"
	printf "OPTIONS:\n"
	printf "%-25s%s\n" "--hdr-dir=DIR" "header directory, move all header files to DIR"
	printf "%-25s%s\n" "--src-dir=DIR" "source directory, move all source files to DIR"
	printf "%-25s%s\n" "--hdr-ext=EXT" "header extension, apply for non-existed input file names"
	printf "%-25s%s\n" "--src-ext=EXT" "source extension, apply for non-existed input file names"
	printf "%-25s%s\n" "--override"    "override files althought they are existed"
	printf "%-25s%s\n" "-h --help"     "print this usage\n"
	printf "%-25s%s\n" "-v --verbose"  "print log while running\n"
	printf "%-25s%s\n" "-f --force"    "force to create header file although having the same as non-file stuffs\n"
	printf "\nFILE:\n"
	printf "Header - add header guard\n"
	printf "Source - add #include statement if header existed\n"
	printf "Name without extension - create header, source files and do 2 above tasks\n"
}

function make_global_var_from_arg() {
	# $1: an argv, PATTERN --arg-name=value
	sed -e 's/=.*//g' -e 's/-/_/g' -e 's/[a-z]/\U&/g' <<< "${1#*--}"
}

function make_header_guard() {
	# $1: a string, header file
	sed -e 's/\./_/g' -e 's/^.*$/_\U&_/g' <<< "$1"
}

function print_verbose_log() {
	# $1: a string, log
	[[ $VERBOSE == $TRUE ]] && echo $1
}

function mv2dir() {
	# $1: a string, source path
	# $2: a string, destination path
	[[ "$2" != "" ]] && mkdir -p "$2" && mv -vf "$1" "$2"
}

function write_hdr_guard() {
	# $1: a string, header file
	[[ $(is_hdr "$1") == $FALSE ]] && print_verbose_log "$1 is not a header file" && return

	[[ $OVERRIDE == $FALSE && -f "$1" && $(empty "$1") == $FALSE ]] && return

	print_verbose_log "Write header guard to $1"
	HDR_GUARD=$(make_header_guard "$1")
	printf "#ifndef %s\n" $HDR_GUARD > "$1"
	printf "#define %s\n\n\n\n" $HDR_GUARD >> "$1"
	echo "#endif" >> "$1"
}

function write_include_statement() {
	# $1: a string, source file
	[[ $(is_src "$1") == $FALSE ]] && print_verbose_log "$1 is not a source file" && return

	[[ $(is_hdr_existed "$1") == $FALSE ]] && print_verbose_log "header file of $1 is not exist" && return

	[[ $OVERRIDE == $FALSE && -f "$1" && $(empty "$1") == $FALSE ]] && return

	print_verbose_log "Write #include statement to $1"
	echo "#include \"$(find_header "$1")\"" > "$1"
}

function parse_args() {
	# $@ everything
	if [[ $# == 0 ]]; then
		echo "This script needs some arguments"
		echo "Use -h or --help for the usage"
		exit 0
	fi

	for arg in "$@"; do
		case "$arg" in
			--hdr-dir=* | \
			--src-dir=* | \
			--hdr-ext=* | \
			--src-ext=*)
				declare -g $(make_global_var_from_arg "$arg")="${arg#*=}"
				;;
			--override)
				OVERRIDE=$TRUE
				;;
			-v | --verbose)
				VERBOSE=$TRUE
				;;
			-f | --force)
				FORCE=$TRUE
				;;
			-h | --help)
				print_usage
				exit 0
				;;
			*)
			;;
		esac
	done
}

function main() {
	parse_args "$@"
	for arg in "$@"; do
		case "$arg" in
			--hdr-dir=*  | \
			--src-dir=*  | \
			--hdr-ext=*  | \
			--src-ext=*  | \
			--override   | \
			-h | --help  | \
			-f | --force | \
			-v | --verbose)
				continue
				;;
			*)
				FILE=$arg
				;;
		esac
		if [[ $(is_hdr "$FILE") == $TRUE ]]; then
			write_hdr_guard "$FILE"
			mv2dir "$FILE" "$HDR_DIR"

		elif [[ $(is_src "$FILE") == $TRUE ]]; then
			write_include_statement "$FILE"
			[[ $(is_hdr_existed "$FILE") == $TRUE ]] && mv2dir "$FILE" "$SRC_DIR"

		elif [[ -e "$FILE" && $FORCE == $TRUE ]] || [[ ! -e "$FILE" ]]; then
			write_hdr_guard "$FILE.$HDR_EXT"
			write_include_statement "$FILE.$SRC_EXT"

			mv2dir "$FILE.$HDR_EXT" "$HDR_DIR"
			mv2dir "$FILE.$SRC_EXT" "$SRC_DIR"

		else
			echo "$FILE is exist"
		fi
	done
}

main "$@"
