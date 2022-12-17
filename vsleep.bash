#!/bin/bash

#######################################
## atom smasher's vsleep: verbose sleep
## https://github.com/atom-smasher/vsleep
## v1.0  12 dec 2022
## v1.0j-bash 17 dec 2022
## Distributed under the GNU General Public License
## http://www.gnu.org/copyleft/gpl.html

## quick sanity check, to see if "pv" is installed
#[ -x "$(which pv)" ] || {
command -v pv > /dev/null || type pv > /dev/null || which pv > /dev/null || {
	## portability! first try "command -v"; if needed, try "type"; if needed, try "which"
	## this test succeeds on the first match, avoiding a fork to which
	echo "${0} requires 'pv', but pv was not found in PATH"
	echo 'See: http://www.ivarch.com/programs/pv.shtml'
	exit 100
}

## help funtion
show_help () {
    echo 'usage:'
    echo '  vsleep [OPTIONS] DELAY|TARGET'
    echo '    DELAY = sleep this many seconds (integer)'
    echo '    TARGET = sleep until this time (formats supported by DATE STRING)'
    echo '    -j JITTER = randomly add up to JITTER seconds to the DELAY or TARGET time'
    echo '    -J JITTER = randomly add or subtract up to JITTER seconds to or from the DELAY or TARGET time'
    echo '      * JITTER must be specified as an integer'
    echo '    -p = show progress bar (off by default)      (pv option --progress)'
    echo '    -E = disable countdown timer (on by default) (pv option --eta)'
    echo '    -I = disable ETA time (on by default)        (pv option --fineta)'
    echo '    -q = no output from pv                       (pv option --quiet)'
    exit ${1}
}

## jitter function
calc_random_jitter () {
    shuf -i 1-${1} -n 1
}

test_jitter_integer () {
    case "${1}" in
	*[!0-9]*)
	    echo "${0##*/}: error: '${*}' JITTER must be specified as an integer"
	    show_help 3
	    ;;
    esac
}

## unset these variables; they'll be set later, if needed
unset jitter_add jitter_plus_minus progress_bar pv_quiet target_date

## set these variables; they'll be unset later, if needed
pv_eta='--eta'
pv_eta_fine='--fineta'

## getopts loop to parse options
while getopts "hj:J:pEIq" options
do
    case ${options} in
	j)
	    ## specify a random delay, in addition to specified delay/target
	    test_jitter_integer ${OPTARG}
	    jitter_add=$(calc_random_jitter ${OPTARG})
	    ;;
	J)
	    ## specify a random delay, plus or minus specified delay/target
	    test_jitter_integer ${OPTARG}
   	    jitter_plus_minus=$(tr -dc '+-' < /dev/urandom | head -c 1 ; calc_random_jitter ${OPTARG})
	    ;;
	p)
	    ## enable pv's progress bar
	    progress_bar='-p'
	    ;;
	E)
	    ## disable pv's countdown timer
	    unset pv_eta
	    ;;
	I)
	    ## disable pv's ETA
	    unset pv_eta_fine
	    ;;
	q)
	    pv_quiet='--quiet'
	    ;;
	h)
	    show_help 0
	    ;;
	*)
	    show_help 1
	    ;;
    esac
done
shift $(( $OPTIND - 1 ))

## if pv's --eta and --fineta are both turned off, it defaults to showing progress
## turn that off, unless it's explicitly turned on
[ ! "${pv_eta}" ] && [ ! "${pv_eta_fine}" ] && [ ! "${progress_bar}" ] && pv_quiet='--quiet'

## if "DELAY|TARGET" contains non-numeric characters, process it as a TARGET
## this case construct tests whether the DELAY|TARGET argument should be treated as a DELAY or TARGET
## without forking a grep, and simultaneously handling/processing input
case "${*}" in
    '')
	## test for empty DELAY|TARGET
	echo "${0##*/}: error: DELAY|TARGET must be specified"
	show_help 4
	;;
    *[!0-9]*)
	## test for non-numeric input, including spaces
	## santity check, if TARGET is valid
	## here, fork 'date' to interpret the TARGET, and store that in a variable so it can be re-used without another fork
	target_date=$( date -d "${*}" +%s 2> /dev/null ) || {
	    ## test if that 'date' fails
	    echo "${0##*/}: error: '${*}' TARGET is not valid"
	    show_help 2
	}
	## calculate a "wait until time"
	delay=$(( ${target_date} - ${EPOCHSECONDS} - 1 ))
	## wait ; this waits until the next clock second, before starting the countdown
	## not ideal, but it tends to give much more precise execution time
	## this also seems to be a necessary evil, to get pv to display the correct ETA
	sleep $( printf "0.%0.6d" $(( 1000000 - ${EPOCHREALTIME##*.} )) ) 2> /dev/null || delay=$(( ${delay} + 1 ))
	## on systems that can't handle 'sleep' for non-integer values, just ignore that part
	;;
    *)
	## after the tests above, input must be an integer
	## here, $delay just equals the seconds, as specified as input
	delay=${1}
	;;
esac

## add jitter, if specified
[ "${jitter_add}" ] && delay=$(( ${delay} + ${jitter_add} ))

## plus/minus jitter, if specified
[ "${jitter_plus_minus}" ] && delay=$(( ${delay} ${jitter_plus_minus} ))

## fail gracefully if the specified target is in the past
[ 1 -gt ${delay} ] && {
    echo "${0##*/}: error: '${*}' is in the past"
    exit 2
}

## at the heart of this script is a yes/pv trick that I found here, and significantly expanded on -
## https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes
yes | pv ${progress_bar} ${pv_eta} ${pv_eta_fine} ${pv_quiet} --rate-limit 10 --stop-at-size --size $(( ${delay} * 10 )) > /dev/null
