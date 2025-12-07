#!/bin/sh

#######################################
## atom smasher's vsleep: verbose sleep
## https://github.com/atom-smasher/vsleep
## v1.0     12 dec 2022
## v2.0-sh  07 dec 2025
## Distributed under the GNU General Public License
## http://www.gnu.org/copyleft/gpl.html

## help funtion
show_help () {
    echo 'usage:'
    echo '  vsleep [OPTIONS] DELAY|TARGET'
    echo '    DELAY = sleep this many seconds (integer)'
    echo '    TARGET = sleep until this time (formats supported by DATE STRING)'
    echo '    -j JITTER = randomly add up to JITTER seconds to the DELAY or TARGET time'
    echo '    -J JITTER = randomly add or subtract up to JITTER seconds to or from the DELAY or TARGET time'
    echo '        * JITTER must be specified as an integer > 0'
    echo '    -d ; show JITTER times'
    echo '    -b n ; ring the system bell, n times'
    echo '    -f n ; flash the screen, n times (visual bell)'
    echo '    -E ; disable countdown timer (on by default)' # derived from: pv option --eta
    echo '    -I ; disable ETA time (on by default)'        # derived from: pv option --fineta
    echo '    -q ; quiet'                                   # derived from: pv option --quiet
    exit ${1}
}

stty_orig=$(stty -g)

trap "stty ${stty_orig}" EXIT
trap "echo ; exit" INT KILL TERM

## jitter function
calc_random_jitter () {
    range_max=${1}
    range_min=${2:-0}
    echo $(( $(shuf -i 0-$(( ${range_max} + ${range_min})) -n 1) - ${range_min} ))
}

test_jitter_integer () {
    case "${1}" in
	*[!0-9]*)
	    echo "${0##*/}: error: '${*}' JITTER must be specified as an integer > 0"
	    show_help 3
	    ;;
    esac
}

## unset these variables; they'll be set later, if needed
unset jitter_add jitter_plus_minus quiet target_date jitter_show visual_bell system_bell timer_seperator time_completion

## set these variables; they'll be unset later, if needed
show_eta='y'
show_eta_fine='y'

## getopts loop to parse options
while getopts "hj:J:EIqdb:f:" options
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
	    jitter_plus_minus=$(calc_random_jitter ${OPTARG} ${OPTARG})
	    ;;
	E)
	    ## disable countdown timer
	    unset show_eta
	    ;;
	I)
	    ## disable ETA
	    unset show_eta_fine
	    ;;
	q)
	    ## quiet
	    quiet='y'
	    ;;
	d)
	    ## debug; display JITTER times
	    jitter_show=y
	    ;;
	b)
	    ## system bell
	    system_bell=${OPTARG}
	    ;;
	f)
	    ## visual bell
	    visual_bell=${OPTARG}
	    ;;
	h)
	    ## help
	    show_help 0
	    ;;
	*)
	    ## error
	    show_help 2
	    ;;
    esac
done
shift $(( $OPTIND - 1 ))

[ ! "${show_eta}" ] && [ ! "${show_eta_fine}" ] && quiet='y'

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
	delay=$(( ${target_date} - $( date +%s ) - 1 ))
	## wait ; this waits until the next clock second, before starting the countdown
	## not ideal, but it tends to give much more precise execution time
	## the math here is kind of 2-1, rather than 1-0, to avoid problems with leading zero being misinterpreted
	sleep $( printf "0.%0.9d" $(( 2000000000 - 1$(date +%-N) )) ) 2> /dev/null || delay=$(( ${delay} + 1 ))
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
[ "${jitter_plus_minus}" ] && delay=$(( ${delay} + ${jitter_plus_minus} ))

## fail gracefully if the specified target is in the past
[ 1 -gt ${delay} ] && {
    echo "${0##*/}: error: \"${delay}\" (${*}${jitter_add:+ + }${jitter_add}${jitter_plus_minus:+ + }${jitter_plus_minus}) is in the past"
    ## this is an error condition
    ## the exit status 1 makes it easy to distinguish from other errors, eg: [ "${?}" -lt 1 ]
    exit 1
}

## show JITTER times
[ "${jitter_show}" ] && {
    echo "JITTER (j + J):    ${jitter_add:-0} + ${jitter_plus_minus:-0} = "$(( ${jitter_add:-0} + ${jitter_plus_minus:-0} ))
}

## borrowing from pv: "When the  estimated  time  is more than 6 hours in the future, the date is shown as well."
time_completion=$(( $(date +%s ) + ${delay} ))
[ "${show_eta_fine}" ] && [ "${delay}" -gt 21600 ] && time_completion_long=$(date -d@${time_completion} '+ETA %Y-%m-%d %T')
[ "${show_eta_fine}" ] && time_completion_short=$(date -d@${time_completion} '+ETA %T')

## formatting delimiter
[ "${show_eta}" ] && [ "${show_eta_fine}" ] && timer_seperator=' :: '

## display a "::" seperator, if needed
unset line_seperator
[ "${show_eta}" ] && [ "${show_eta_fine}" ] && line_seperator=" :: "

clear_line="$(tput el)"

## the countdown loop
stty -echo
while :
do
    ## this is an exercse in being extra-stingy with forks within the loop
    ## every 60 seconds, recalibrate the time remaining with `date`
    ## the other 59/60 seconds (59/60 loop iterations, technically) just subtract one second from the counter
    [ "$(( ${time_remaining:=0} % 60 ))" -eq 0 ] && {
	time_remaining=$(( ${time_completion} - $(date +%s) ))
    } || {
	time_remaining=$(( ${time_remaining} - 1 ))
    }
    ## test if the timer_countdown needs to be calculated before forking `date`
    [ ! "${quiet}" ] && [ "${show_eta}" ] && {
	counter=$( date -ud@${time_remaining} '+%H:%M:%S' )
	## format the countdown timer to remove leading zeros
	timer_countdown=$(( ${time_remaining} / 3600 / 24 ))":${counter}"
	timer_countdown="${timer_countdown#0:}"  ## trim 0 days
        timer_countdown="${timer_countdown#00:}" ## trim 00 hours
        timer_countdown="${timer_countdown#00:}" ## trim 00 minutes
    }
    [ "${show_eta_fine}" ] && [ "${time_remaining}" -gt 21600 ] && {
	## ETA includes date when it's 6+ hours away
	time_eta=${time_completion_long}
    } || {
	time_eta=${time_completion_short}
    }
    ## print the line, unless "quiet"
    [ "${quiet}" ] || {
	echo -n "${clear_line}\t${timer_countdown}${line_seperator}${time_eta}\r"
    }
    ## at first glance, a `sleep 1` in a timer loop may seem like it's inviting a timing error, but
    ## it's really just updating the display and checking when it's done. it's not controlling the timing.
    sleep 1
    ## exit the loop cleanly when done
    [ ${time_remaining} -lt 2 ] && {
	## final update of the status line
	[ "${quiet}" ] || echo "${clear_line}\t${timer_countdown:+0}${line_seperator}${time_eta}"
	## done with the countdown
	break
    }
done
stty echo

## flash the screen, using the visual bell
## beep using system bell
visual_bell=${visual_bell:=0}
system_bell=${system_bell:=0}
while [ ${visual_bell} -gt 0 ] || [ ${system_bell} -gt 0 ]
do
    ## system bell, with appropriate delay
    [ ${system_bell} -gt 0 ] && {
	tput bel && sleep 0.1
    } || {
	sleep 0.1
    }
    ## visual bell, with appropriate delay
    [ ${visual_bell} -gt 0 ] && {
	tput flash
    } || {
	sleep 0.1
    }
    ## countdown bells to zero
    visual_bell=$(( ${visual_bell} - 1 ))
    system_bell=$(( ${system_bell} - 1 ))
done
