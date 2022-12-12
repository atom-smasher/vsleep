# vsleep
## verbose cli sleep command, with extra features

Like normal unix/linux/BSD sleep, sleep for 5 minutes:
`vsleep 300`
      
Also acepts a time to sleep until:
`vsleep 21:00`

Target time accepts any format that's understood by date's DATE STRING. Integer-only values are interpreted as seconds of delay, and any other characters are interpreted as DATE STRING formatted target-times.

Time-zones can be explicitly specified:
`TZ=GMT vsleep 08:00`

Sleep until 9pm, but **randomly add** 0-300 seconds of extra delay:
`vsleep -j 300 21:00`

Sleep until 9pm, but **randomly add or subtract** 0-300 seconds of delay:
`vsleep -J 300 21:00`

Verbosity options can be seen via the help menu:
`vsleep -h`

