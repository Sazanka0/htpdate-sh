# \[Experimental\]A more portable timesync over http(s)
**This is an experimental software. May contain bugs or security risks**

By default,NTP connection is not authenticated and not encrypted.
Htpdate Aims to solve this plobrem using HTTP(S).
This is variant of Htpdate  that focused on reducing dependencies and increase portability.

## Requirement
* Curl
* POSIX Shell
* local command
* Date that support \[.ss\] format
* Xargs that support -P option.plannning support to GNU Pararells

Most Linux comes with Busybox or(and) Coreutils installed by default, so you don't need to install anything

## Usage
	htpdate -u <URL> [-dh] [-ps <PROXY_URL> |-t [1-3]]

	You can choose 3 type of methods to specify URL.
	-u URL1 -u URL2...
	-u URL1,URL2...
	-u "URL1 URL2..."

	options:
	 -b BSD Style format (yymmddHHMM.ss) mode
	 -d debug mode. dont sync time
	 -g use gdate instad of OS-default date
	 -p enable proxy
	 -s enable socks5 proxy
	 -t <VAR> use tls 1.X or newer
	 -h show help

## Based on
[htpdate](www.vervest.org/htp)
[Tails fork](https://gitlab.tails.boum.org/tails/htp)
[madaidan's secure-time-sync](https://gitlab.com/madaidan/secure-time-sync)

## License
[GPLv3](https://www.gnu.org/copyleft/gpl.html)