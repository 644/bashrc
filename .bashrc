#!/usr/bin/env bash

# Test if interactive shell
[[ $- != *i* ]] && return

# SET GLOBAL VARIABLES AND SET SETTINGS
shopt -s cdspell
shopt -s autocd
shopt -s dirspell
shopt -s dotglob
shopt -s direxpand
shopt -s globstar
shopt -s nocaseglob
shopt -s nocasematch
shopt -s histappend
shopt -s checkwinsize
shopt -s no_empty_cmd_completion
shopt -s histappend

declare -x PS1="\[\033[38;5;161m\][\[$(tput sgr0)\]\[\033[38;5;10m\]\u\[$(tput sgr0)\]\[\033[38;5;249m\]@\[$(tput sgr0)\]\[\033[38;5;250m\]\h\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;141m\]\w\[$(tput sgr0)\]\[\033[38;5;161m\]]\$(nonzero_return)\[\e[m\] \[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;9m\]\\$\[$(tput sgr0)\] \[$(tput sgr0)\]"
declare -x VISUAL=kate EDITOR=kate BROWSER=firefox
declare -x TIMEFORMAT=$'\nreal\t%R\nuser\t%U\nsys\t%S\ncpu\t%P\n'
declare -x PS2='->    '
declare -x HISTSIZE=-1
declare -x PROMPT_DIRTRIM=2

declare -x LESS_TERMCAP_mb=$'\e[1;32m'
declare -x LESS_TERMCAP_md=$'\e[1;32m'
declare -x LESS_TERMCAP_me=$'\e[0m'
declare -x LESS_TERMCAP_se=$'\e[0m'
declare -x LESS_TERMCAP_so=$'\e[01;33m'
declare -x LESS_TERMCAP_ue=$'\e[0m'
declare -x LESS_TERMCAP_us=$'\e[1;4;31m'

eval "$(dircolors -b)"

[[ ":${PATH}:" != *":${HOME}/bin:"* ]] && declare -x PATH="${PATH}:${HOME}/bin"

# FUNCTIONS
# Print return value of last command if unsuccessful
nonzero_return() {
	((RETVAL = $?, RETVAL)) && printf ' (%d)' "${RETVAL}"
}

# Spoof webm duration
spooflen() {
	declare -r filen=${1?No input given}
	declare vidlen
	[[ -f ${filen} ]] || { printf '"%q" - not a file.\n' "${filen}" >&2; return 1; }
	vidlen=$(ffprobe -i "${filen}" -show_entries format=duration -v quiet -of csv="p=0")
	vidlen=${vidlen%%.*}
	# 1ms
# 	LC_ALL=C sed 's/\x44\x89\x88[\x00-\xFF]\{4\}/\x44\x89\x88\x3F\xF0\x00\x00/g' "${filen}" > "${filen%.*}_(Len_${vidlen}s).webm"
	# 2 min
# 	LC_ALL=C sed 's/\x44\x89\x88[\x00-\xFF]\{4\}/\x44\x89\x88\x40\xFD\x4C\x00/g' "${filen}" > "${filen%.*}_(Len_${vidlen}s).webm"
	# 5 min
	LC_ALL=C sed 's/\x44\x89\x88[\x00-\xFF]\{4\}/\x44\x89\x88\x41\x12\x4F\x80/g' "${filen}" > "${filen%.*}_(Len_${vidlen}s).webm"
}

# Split video into parts of n seconds per segment
splitvid() {
	declare -r filen=${1?No input given}
	declare -ri vidlen=${2:-600}
	[[ -f ${filen} ]] || { printf '"%q" - not a file.\n' "${filen}" >&2; return 1; }
	mkdir -p split-vids/
	ffmpeg -i "${filen}" -sn -acodec copy -f segment -segment_time "${vidlen}" -vcodec copy -reset_timestamps 1 -map 0 -segment_start_number 1 split-vids/"${filen%.*}_Part%d.${filen##*.}"
}

# Find files
ff() {
	declare -r sterm=${1?No search term given}
	declare -ri depth=${2:-1}
	declare -r dir=${3:-.}
	[[ -d ${dir} ]] || { printf '"%q" not a directory.\n' "${dir}" >&2; return 1; }
	printf 'find %s -maxdepth %s -type f -iname %s\n' "${dir}" "${depth}" "${sterm}" >&2
	find "${dir}" -maxdepth "${depth}" -type f -iname "${sterm}"
}

# Find direcories
fd() {
	declare -r sterm=${1?No search term given}
	declare -ri depth=${2:-1}
	declare -r dir=${3:-.}
	[[ -d ${dir} ]] || { printf '"%q" not a directory.\n' "${dir}" >&2; return 1; }
	printf 'find %s -maxdepth %s -type f -iname %s\n' "${dir}" "${depth}" "${sterm}" >&2
	find "${dir}" -maxdepth "${depth}" -type d -iname "${sterm}"
}

# Search non-installed packages with yay
fpn() {
	declare -r search=${1?No search term given}
	yay --color=always -Ss -- "${search}" |\
		awk '/\(Installed\)/{skip=2}; (skip && skip--) {next} {print}'
}

# Search installed packages with yay
fpi() {
	declare -r search=${1?No search term given}
	yay --color=always -Ss -- "${search}" |\
		awk '/\(Installed\)/{printl=2}; (printl && printl--) {print} {next}'
}

# Open manpages in firefox and stop man deleting the tmp file before firefox can open it
m() {
	declare -r page=${1?No manpage given}
	BROWSER='firefox --new-tab %s; sleep 1' man -H -- "${page}"
}

# Search for program options in their manpages
boy() {
	declare opt mandata
	(($# < 2)) && { printf 'boy manpage -opt\n' >&2; return 1; }
	mandata=$(man -- "${1}")
	for opt in "${@:2}"; do
		sed -n -- "s/.\\x08//g;/^\\s*${opt}/,/^$/p" <<< "${mandata}" 2>/dev/null
	done
}

# Open programs in their own session
bgprog() {
	declare -r prog=${1?No program given}; shift
	declare -ar opts=("${@}")
	[[ -x $(command -v -- "${prog}") ]] || { printf '"%q" not found/executable\n' "${prog}" >&2; return 1; }
	setsid -f -- "${prog}" "${opts[@]}" &>/dev/null
}

# Find help for any command
h() {
	declare -r prog=${1?No program given}
	[[ -x $(command -v -- "${prog}") ]] || { printf '"%q" not found/executable\n' "${prog}" >&2; return 1; }
	"${prog}" -h &>/dev/null && "${prog}" -h && return
	"${prog}" --help &>/dev/null && "${prog}" --help && return
	help "${prog}" &>/dev/null && help "${prog}" && return
	man "${prog}" &>/dev/null && man "${prog}" && return
	info "${prog}" &>/dev/null && info "${prog}" && return
	cheat "${prog}" &>/dev/null && cheat "${prog}" && return
	printf '"%q" refuses to provide any help. Looking on Google..\n' "${prog}"
	firefox --new-tab -- "https://www.google.com/search?q=${prog}+usage"
}

# Remove carriage returns from files
repr() {
	declare -r infile=${1?No file given}
	[[ -w ${infile} ]] || { printf '"%q" not a writable file' "${infile}" >&2; return 1; }
	sed -i 's/\r//g' -- "${infile}"
}

# Create bash script
mkbash() {
	declare -r infile=${1?No file given}
	[[ -e ${infile} ]] && { printf '"%q" already exists\n' "${infile}" >&2; return 1; }
	printf '#!/usr/bin/env bash\n' > "${infile}"
	chmod u+x -- "${infile}"
	bgprog kate -- "${infile}"
}

# Open the command with kate, useful for modifying bash scripts
c() {
	declare -r findcmd=${1?No command given}
	declare runcmd
	runcmd=$(command -v -- "${findcmd}") || { printf '%q: command not found\n' "${findcmd}" >&2; return 127; }
	printf '%q\n' "${runcmd}"
	bgprog kate -- "${runcmd}"
}

# Find big files and limit output to tailc lines (default 100)
find-big-files(){
	declare fol=${1:-.}
	declare tailc=${2:-100}
	if [[ ! -d ${fol} ]]; then
		case ${fol} in
			''|*[!0-9]*) printf '"%q" not a folder or number\n' "${fol}"; return 1 ;;
			*) tailc=${fol}; fol='.' ;;
		esac
	fi
	du -ah "${fol}" | sort -h -k1 -t $'\t' | tail -n "${tailc}"
}

# Set completion options
type -t _man >/dev/null || {
	declare -r mcomplete=/usr/share/bash-completion/completions/man
	[[ -r ${mcomplete} ]] && . ${mcomplete} && complete -F _man m boy
}
complete -F _command bgprog c h

# Update helper for arch based systems
ud() {
	declare -r color='\e[91m\e[1m::\e[0m \e[1m'
	declare -r esc='\e[0m'
	declare -a rmdeps
	declare update=true

	while(($# > 0)); do
		case ${1} in
			-r | --refresh)
				printf '%bUpdating mirrorlist%b\n' "${color}" "${esc}"
				sudo reflector --ipv4 -p https -l 200 -n 20 -p https --sort rate --save /etc/pacman.d/mirrorlist
				printf 'Done.\n'
				shift
				;;
			-s | --skipupdate) update=false; shift; ;;
		esac
	done

	${update} || return 0


	printf '%bRunning yay -Syyu%b\n' "${color}" "${esc}"
	yay -Syyu

	printf '\n%bRunning yay -Rns for rmdeps%b\n' "${color}" "${esc}"
	mapfile -t rmdeps < <(yay -Qdtq)
	yay -Rns -- "${rmdeps[@]}" || printf 'Nothing to do.\n'

	printf '\n%bRunning yay -Scc%b' "${color}" "${esc}"
	printf 'y\ny\ny\n' | yay -Scc &>/dev/null

	printf '\nDone.\n\n%bRunning yay -Ps%b\n' "${color}" "${esc}"
	yay -Ps

	printf '\n%bRunning avg-audit%b\n' "${color}" "${esc}"
	avg-audit
}

# ALIASES
alias ls='ls -1Abhnrt --color=always --time-style=+"%d/%m/%y %R"'
alias grep='grep --color=auto'
alias s='sensors -A'
alias sc='shellcheck -oall'
alias z='tput reset'
alias mpva='mpv --lavfi-complex="[aid1] asplit [ao] [vis];[vis] showspectrum=size=1000x600:overlap=1:slide=scroll:scale=cbrt,setdar=dar=16/9 [vo]" --no-video'
alias is="yay -Syyu"
alias fp="yay -Ss"
alias fsf="yay -Fs"
alias rp="yay -Rns"
alias mv='mv -v'
alias cp='cp -v'
alias stracespy='echo "strace -e write=1,2 -e trace=write -f -q -p pid"'
alias q="qalc -t"
alias k='bgprog kate'
alias d='bgprog dolphin'
alias y='youtube-dlc'
alias feh='bgprog /usr/bin/feh'
