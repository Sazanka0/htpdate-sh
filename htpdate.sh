#!/bin/sh
# Htpdate.sh
# Copyright (C) 2005 Eddy Vervest
# Copyright (C) 2010-2011 Tails developers <tails@boum.org>
# Copyright (C) 2019 madaidan
# Copyright (C) 2021 Sazanka0
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# https://www.gnu.org/copyleft/gpl.html
VERSION="0.9_s"

CURLOPT=" -sI -m 10 --proto =https"
MAX_POOL=5
MIN_POOL=1
MAX_DIFF=0
MIN_DIFF=1

set -e

usage(){
	cat <<-EOF
	usage: htpdate -u <URL> [-dh] [-ps PROXY_URL |-t [1-3]]

	a more portable and secure timesync over https

	VERSION:${VERSION}

	You can choose 3 type of methods to specify URL.
	-u URL1 -n URL2...
	-u URL1,URL2...
	-u "URL1 URL2..."

	options:
	 -b BSD Style format (yymmddHHMM.ss) mode
	 -d debug mode. dont sync time
	 -g use gdate instad of OS-default date
	 -p enable proxy
	 -s enable socks5 proxy
	 -t <VAR> use tls 1.X or newer
	 -h show this help
	EOF
	exit 1
}

check_connection(){
	if [ "$MIN_POOL" -gt "$#" ]; then
		printf "The number of POOL must be more than ${MIN_POOL}.\n"
		exit 2;
	elif [ "$MAX_POOL" -lt "$#" ]; then
		printf "The number of POOL must be less than ${MAX_POOL}.\n"
		exit 2;
	else
		printf "$@\n" | while read line
			do
				set -- $line
# check curl connection and init proxy
				if ! curl ${CURLOPT} -o /dev/null "$@" ; then
					printf "Could not connect to $@ \n"
					exit 5
				fi
			done
	fi
}

get_webtime(){
	printf "$@" | xargs -P $# -I {} sh -c "curl ${CURLOPT} {} 2>&1 | grep -i -m 1 'Date' | sed -e 's/[dD]ate: //'"
}

parse_webtime(){
#Input: Sat 23 Jan 2021 12:34:56
#Output:2021 1 23 12 34 56
	local _h
	local _m
	local _s
	local _tmp
	local _invalid
	printf "$@\n" | while read line
	do
		set -- $line
		case $3 in
			Jan) _M="01";; Feb) _M="02";; Mar) _M="03";; Apr) _M="04";; May) _M="05";; Jun) _M="06";;
			Jul) _M="07";; Aug) _M="08";; Sep) _M="09";; Oct) _M="10";; Nov) _M="11";; Dec) _M="12";;
			[1-9] | 1[0-2] ) _M=$3;;
				*) printf "Invalid argument. \n"; _invalid=1;;
		esac
		if [ "$_invalid" = 1 ] ;then
			exit 3;
		fi
		_h=${5%%:*}
		_tmp=${5%:*}
		_m=${_tmp#*:}
		_s=${5##*:}
		printf "$4 $_M $2 $_h $_m $_s\n"
	done
}

to_unixtime(){
#Input: 2021 01 23 12 34 56
#Output:1611405296
	local _utime
	printf "$@\n" | while read line
	do
		set -- $line
		set -- "$1" "${2#0}" "${3#0}" "${4#0}" "${5#0}" "${6#0}"
		[ "$2" -lt 3 ] && set -- $(( $1-1 )) $(( $2+12 )) "$3" "$4" "$5" "$6"
		_utime=$(((365*$1+($1/4)-($1/100)+($1/400)+(306*($2+1)/10)-428+$3-719163)*86400+($4*3600)+($5*60)+$6))
		printf "$_utime \n"
	done
}

format_time_array(){
	local _ptime
	_ptime=$(parse_webtime "$@")
	to_unixtime "$_ptime" | awk '{print $0 ,NR;}' | sort

}

select_line(){
	format_time_array "$@" | awk '{
		line[NR] = $2
	}
	END{
	print line[int((NR/2)+1)]
	}'
}

select_time(){
	local _line
	_line="$1"
	shift
	printf "$@"| awk -v "line=${_line}" '{
		if(line==NR){
			print $0
		}
	}'
}

get_systime(){
	LC_TIME=C date -u +"%Y %d %h %H %M %S"
}

setdate(){
#Input: 2021 01 23 12 34 56
	if [ -n "$bsd_mode" ];then
		date "$1""$2""$3""$4""$5"".$6"
	else
		date "$2""$3""$4""$5""$1"".$6"
	fi
}

check_unixtime_diff(){
	if [ -z "$1" ];then
		printf "Time 1 is empty. \n"
		exit 3
	elif [ -z "$2" ];then
		printf "Time 2 is empty. \n"
		exit 3
	fi
	TIME_DIFF=$(($1 > $2 ? $1 - $2 : $2 - $1))
	if [ "$MIN_DIFF" -gt  "$TIME_DIFF" ];then
		printf "Diff is too small.(${TIME_DIFF})\n"
		exit 4
	elif [ "$MAX_DIFF" -ne 0 ] && [ "$MAX_DIFF" -lt  "$TIME_DIFF" ];then
		printf "Diff is too large.(${TIME_DIFF})\n"
		exit 4
	fi
}

if [ "$(id -u)" -ne 0 ];then
	printf "This program needs to be run as root.\n"
	exit 2
fi

while getopts "cdgp:s:t:u:h" opt; do
	case $opt in
		b)	bsd_mode=true;;
		d)	debug=true;;
		g)	gdate_mode=true;;
		p)	ARG_PROXY="$OPTARG";;
		s)	socks5="true"; ARG_PROXY="$OPTARG";;
		t)	TLSARG="$OPTARG";;
		u)	ARG_URL="$ARG_URL $OPTARG";;
		h)	usage;;
		*) 	usage;;
	esac
done

if [ -n "$gdate_mode" ];then
	date(){ gdate "$@"; }
fi

#add "https://" to prevent escape curl options and downgrade attack
#needs more research
URL_ARRAY=$(printf "${ARG_URL}" |awk '{
	# IFS=" "
	gsub(","," ")
	gsub("http://","https://")
	for(i=1;i<=NF;i++){
		if($i ~ /^https:\/\//){
			print $i;
		}else{
			print "https://"$i;
		}
	}
}')

# Resolve the host name "locally" rather than via the SOCKS proxy,
# in order to get a "curl: (6) Could not resolve host" error upon
# name resolution, instead of the unhelpful "curl: (7) Can't
# complete SOCKS5 connection".
if [ -n "$ARG_PROXY" ];then
	URL_PROXY=$(printf "${ARG_PROXY}" |awk -v "socks5=${socks5}" '{
		if($0 !~ /^https?:\/\/|^socks(4a?|5h?):\/\//){
			if(socks5=="true"){
				print "socks5://"$0;
			}else{
				print "http://"$0;
			}
		}else{
			print $0;
		}
	}')
	CURLOPT="${CURLOPT} --proxy ${URL_PROXY}"
fi

if [ -n "$TLSARG" ]; then
	case $TLSARG in
	[1-9])	CURLOPT="${CURLOPT} --tlsv1.${TLSARG}";;
	*)		printf "Invalid TLS Option. \n";
			exit 3;;
	esac
else
	CURLOPT="${CURLOPT} --tlsv1"
fi

check_connection "${URL_ARRAY}"
WEBTIME=$(get_webtime "${URL_ARRAY}")
SELECTED_LINE=$(select_line "${WEBTIME}")
NEWTIME=$(select_time ${SELECTED_LINE} "${WEBTIME}")
NEWTIME_PARSED=$(parse_webtime "${NEWTIME}")
NEWTIME_UNIX=$(to_unixtime "${NEWTIME_PARSED}")
SYSTIME=$(get_systime)
SYSTIME_UNIX=$(to_unixtime "${SYSTIME}")
check_unixtime_diff "${NEWTIME_UNIX}" "${SYSTIME_UNIX}"

if [ -n "$debug" ];then
	printf "$CURLOPT \n"
	printf "URL:\n$URL_ARRAY \n"
	printf "SELECTED_LINE:${SELECTED_LINE} \n"
	printf "NEWTIME:${NEWTIME} \n"
	printf "WEBTIME:\n${WEBTIME} \n"
	printf "SYSTIME:\n${SYSTIME} \n"
	printf "NEW_UNIX: ${NEWTIME_UNIX} \n"
	printf "SYS_UNIX: ${SYSTIME_UNIX} \n"
	printf "Diff:	  ${TIME_DIFF} \n"
	exit 99
fi

setdate ${NEWTIME_PARSED}
