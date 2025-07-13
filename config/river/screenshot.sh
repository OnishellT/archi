#!/usr/bin/env bash 

set -euo pipefail

while getopts ":apsrh" option; do
   case $option in

		a)	# Copy all outputs to swappy and edit
			grim - | swappy -f - 
			;;
		p)	# Copy all outputs to ~/Pictures/
			grim $(xdg-user-dir PICTURES)"/sc_$(date +'%Y%m%d%H%M%S').png"
			;; 
       	s)	# Copy region to swappy and edit
       		grim -g "$(slurp)" - | swappy -f -
       		;; 
        r)	# Copy region to ~/Pictures/
       	    slurp | grim -g - sc_$(date +'%Y%m%d%H%M%S').png	
       		;; 
        h)  echo ""
            echo "$0"
            echo "Usage: "
            echo ""
            echo "-a) Copy all outputs to swappy and edit"
            echo "-p) Copy all outputs to ~/Pictures/" 
            echo "-s) Copy region to swappy and edit"
            echo "-r) Copy region to ~/Pictures/" 
            echo ""
            exit;;
        \?)	echo ""
            echo "Invalid Option"
            $0 -h 
 			exit;; 
	esac 

done

exit 0

