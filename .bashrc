#!/usr/bin/env bash
# SET GLOBAL VARIABLES AND SET SETTINGS
shopt -s cdspell
shopt -s autocd
declare -x VISUAL=vim EDITOR=vim BROWSER=firefox
declare -x TIMEFORMAT=$'\nreal\t%R\nuser\t%U\nsys\t%S\ncpu\t%P\n'
declare -x PROMPT_DIRTRIM=2
declare -x PS1="[\[\e[31m\]\u\[\e[m\]\[\e[30m\]@\[\e[m\]\[\e[30m\]\H\[\e[m\] \[\e[34m\]\w\[\e[m\]]\[\e[30m\]\$(nonzero_return)\[\e[m\] \[\e[31m\]\\$\[\e[m\] "
declare -x PS2='->    '

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
	# 5 min
	LC_ALL=C sed 's/\x44\x89\x88[\x00-\xFF]\{4\}/\x44\x89\x88\x41\x12\x4F\x80/g' "${filen}" > "${filen%.*}_(Len_${vidlen}s).webm"
	# 1ms
	# LC_ALL=C sed 's/\x44\x89\x88[\x00-\xFF]\{4\}/\x44\x89\x88\x3F\xF0\x00\x00/g' "${filen}" > "${filen%.*}_(Len_${vidlen}s).webm"
	# 2 min
	# LC_ALL=C sed 's/\x44\x89\x88[\x00-\xFF]\{4\}/\x44\x89\x88\x40\xFD\x4C\x00/g' "${filen}" > "${filen%.*}_(Len_${vidlen}s).webm"
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

# Find command in $PATH and open in kate
c() {
	declare -r findcmd=${1?No command given}
	declare runcmd
	runcmd=$(command -v -- "${findcmd}") || { printf '%q: command not found\n' "${findcmd}" >&2; return 127; }
	printf '%q\n' "${runcmd}"
	bgprog kate -- "${runcmd}"
}

# Set completion options
type -t _man >/dev/null || {
	declare -r mcomplete=/usr/share/bash-completion/completions/man
	[[ -r ${mcomplete} ]] && . ${mcomplete} && complete -F _man m boy
}
complete -F _command bgprog c

# ALIASES
alias ls='ls -1bhAontr --color=auto --time-style=+"%d/%b/%y %R"'
alias s='sensors -A'
alias sc='shellcheck -oall'
alias mpva='mpv --lavfi-complex="[aid1] asplit [ao] [vis];[vis] showspectrum=size=1000x600:overlap=1:slide=scroll:scale=cbrt,setdar=dar=16/9 [vo]" --no-video'
alias is="yay -Syyu"
alias fp="yay -Ss"
alias rp="yay -Rns"
alias mv='mv -v'
alias cp='cp -v'
alias stracespy='strace -e write=1,2 -e trace=write -f -q -p'
alias k='bgprog kate'
alias d='bgprog dolphin'

# SET PATH
PATH="${PATH}:${HOME}/bin"
