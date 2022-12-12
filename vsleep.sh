#!/bin/sh

#######################################
## atom smasher's vsleep: verbose sleep
## v1.0d 12 dec 2022
## Distributed under the GNU General Public License
## http://www.gnu.org/copyleft/gpl.html

## quick sanity check, to see if "pv" is installed
[ -x "$(which pv)" ] || {
    echo "${0} requires 'pv', but pv was not found in PATH"
    echo 'See: http://www.ivarch.com/programs/pv.shtml'
    exit 100
}

## help funtion
show_help () {
    echo 'usage:'
    echo '  vsleep [OPTIONS] DELAY|TARGET'
    echo '    DELAY = sleep this many seconds'
    echo '    TARGET = sleep until this time (formats supported by DATE STRING)'
    echo '    -j JITTER = randomly add up to this many seconds to the DELAY or TARGET time'
    echo '    -J JITTER = randomly add or subtract up to this many seconds to or from the DELAY or TARGET time'
    echo '    -p = show progress bar (off by default)      (pv option --progress)'
    echo '    -E = disable countdown timer (on by default) (pv option --eta)'
    echo '    -I = disable ETA time (on by default)        (pv option --fineta)'
    echo '    -q = no output from pv                       (pv option --quiet)'
}

## jitter function
calc_random_jitter () {
    shuf -i 1-${1} -n 1
}

## unset these variables; they'll be set later, if needed
unset jitter_add jitter_plus_minus progress_bar pv_quiet time_fmt

## set these variables; they'll be unset later, if needed
pv_eta='--eta'
pv_eta_fine='--fineta'

## getopts loop to parse options
while getopts "hj:J:pEIq" options
do
    case ${options} in
	j)
	    ## specify a random delay, in addition to specified delay/target
	    jitter_add=$(calc_random_jitter ${OPTARG})
	    ;;
	J)
	    ## specify a random delay, plus or minus specified delay/target
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
	    show_help
	    exit
	    ;;
	?)
	    show_help
	    exit 1
	    ;;
    esac
done
shift $(( $OPTIND - 1 ))

## if pv's --eta and --fineta are both turned off, it defaults to showing progress
## turn that off, unless it's explicitly turned on
[ ! "${pv_eta}" ] && [ ! "${pv_eta_fine}" ] && [ ! "${progress_bar}" ] && pv_quiet='--quiet'

## calculate a "wait until time", if needed
## if "DELAY|TARGET" contains non-numeric characters, process it as a TARGET

## this case construct tests whether the delay|target argument should be treated as a delay or target
## without forking a grep
case "${*}"
in
    *[^0-9]*)
	time_fmt=target
    ;;
esac

[ ${time_fmt} ] && {
    delay=$(( $( date -d "${*}" +%s  ) - $( date +%s ) - 1 ))
    ## wait ; this rounds to the next second, before starting the countdown
    ## not perfect, but it tends to give much more precise execution time
    sleep 0.$(( 1000000000 - $(date +%-N) ))
} || {
    ## or else, delay equals seconds as specified as an argument
    ## if "DELAY|TARGET" contains only numeric characters, process it as a DELAY
    delay=${1}
}

## fail gracefully if the specified target is in the past
[ 1 -gt ${delay} ] && {
    echo "${0}: error: '${*}' is in the past"
    exit 2
}

## add jitter, if specified
[ "${jitter_add}" ] && delay=$(( ${delay} + ${jitter_add} ))

## plus/minus jitter, if specified
[ "${jitter_plus_minus}" ] && delay=$(( ${delay} ${jitter_plus_minus} ))

## at the heart of this script is a yes/pv trick that I found here, and significantly expanded on -
## https://unix.stackexchange.com/questions/600868/verbose-sleep-command-that-displays-pending-time-seconds-minutes
yes | pv ${progress_bar} ${pv_eta} ${pv_eta_fine} ${pv_quiet} --rate-limit 10 --stop-at-size --size $(( ${delay} * 10 )) > /dev/null

