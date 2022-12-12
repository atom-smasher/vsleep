# vsleep
## verbose sleep command, with extra features

Like normal unix/linux/BSD sleep, sleep for 5 minutes:
```
vsleep 300
```
---

Also acepts a time to sleep until. Sleep until 9pm:
```
vsleep 21:00
```

Target time accepts any format that's understood by date's DATE STRING. Integer-only values are interpreted as seconds of delay, and any other characters (including spaces) cause this argument to be interpreted as DATE STRING formatted target-times.

Sleep until 9pm tomorrow:
```
vsleep 21:00 tomorrow
```

Sleep until 9pm, 2 days from now:
```
vsleep 21:00 2 days
```

Sleep until 9pm Friday:
```
vsleep 21:00 Friday
```

Sleep for 3 days:
```
vsleep 3 days
```

Sleep until 7pm, 1 July, 2023:
```
vsleep 1 July 2023 19:00
```

---

Time-zones can be explicitly specified. Sleep until 8am GMT:
```
TZ=GMT vsleep 08:00
```
---


Sleep until 9pm, but **randomly add** 0-300 seconds of extra delay:
```
vsleep -j 300 21:00
```

Sleep until 9pm, but **randomly add or subtract** 0-300 seconds of delay:
```
vsleep -J 300 21:00
```
---

Verbosity options can be seen via the help menu:
`vsleep -h`

