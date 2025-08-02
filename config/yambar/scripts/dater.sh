#!/bin/sh

# Force locale to English
export LC_TIME="C"

while true; do
  # Get the day of the month (removing leading zero)
  number=$(date +'%d' | sed 's/^0//')

  # Determine the appropriate suffix for the day
  case $number in
    11|12|13) extension="th";;  # special case: 11th, 12th, 13th
    *1) extension="st";;
    *2) extension="nd";;
    *3) extension="rd";;
    *) extension="th";;
  esac

  # Format the date in English
  date=$(date +"%A $number$extension %B %Y -")

  echo "date|string|$date"
  echo ""

  # Calculate seconds since midnight
  hour=$(date +'%H')
  minute=$(date +'%M')
  second=$(expr "$hour" \* 3600 + "$minute" \* 60)

  sleep "$second"
done
