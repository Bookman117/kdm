#!/bin/bash
#Purpose: Get latest kdm release.
#Create-Date: 2022-06-28

#Variables >>>
NC="\033[0m" #Color reset
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
bin_detection=0

#Program >>>
ls ~/bin &> /dev/null
[ $? == 0 ] && bin_detection=1
[ "${bin_detection}" == "0" ] && mkdir ~/bin

ls ~/bin/kdm* &> /dev/null
[ $? == 0 ] && rm -r ~/bin/kdm*
wget 'https://github.com/Bookman-W/kdm/releases/download/v1/kdm' -O ~/bin/kdm &> /dev/null
[ $? == 0 ] && echo -e " [${GREEN}●${NC}] download complete: kdm" || echo -e " [${RED}●${NC}] download not complete: kdm"
wget 'https://github.com/Bookman-W/kdm/releases/download/v1/kdm_function' -O ~/bin/kdm_function &> /dev/null
[ $? == 0 ] && echo -e " [${GREEN}●${NC}] download complete: kdm_function" || echo -e " [${RED}●${NC}] download not complete: kdm_function"

[ "${bin_detection}" == "1" ] && chmod +x ~/bin/kdm*