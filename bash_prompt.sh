# shellcheck shell=bash

# We only work with bash
if [[ "${BASH##*/}" != "bash" ]]; then
    return
fi

__create_prompt() (
    # shellcheck disable=SC2034
    local exit_status=$?

    shopt -s extglob
    HISTTIMEFORMAT='%s '

    # These are the defaults
    local -rA default_colors=(
        [fg]="#fdfdfd"
        [bg]="#212121"
        [level1]="#a97fff"
        [level2]="#eeff7f"
        [level3]="#7fe5ff"
        [level4]="#ff7fbd"
        [level5]="#8cff7f"
        [vcs]="#FF0"
        [repo]="#0FF"
        [branch]="#90ff7f"
        [added]="#7FFF7F"
        [deleted]="#DD4B39"
        [modified]="#40A1FF"
        [outgoing]="#0FF"
        [untracked]="#FF40FF"
        [parens]="#ff7f81"
        [users]="#90ff7f"
    )

    local parens0=${BASH_PROMPT_PARENS_OPEN-'('}
    local parens1=${BASH_PROMPT_PARENS_CLOSE-')'}

    # Set some constants
    local -r ESC='\[\033['
    local -r RESET=${ESC}"0m\]" \
        BOLD=${ESC}"1m\]" \
        UNDERSCORE=${ESC}"4m\]" \
        BLINK=${ESC}"5m\]" \
        REVERSE=${ESC}"7m\]" \
        ITALIC=${ESC}"3m\]" \
        STRIKETHROUGH=${ESC}"9m\]"

    # Give the length of the given string with ansi control codes removed
    len() {
        local stripped

        stripped=${1//'\[\033['+([0-9;])'m\]'}
        echo ${#stripped}
    }

    hextoint() {
        local red
        local green
        local blue
        local color=$1

        if [[ "${color:0:1}" == "#" ]] ; then
            color=${color:1}
        fi

        if [[ ${#color} -eq 3 ]]; then
            red=${color:0:1} ; red=${red}${red}
            green=${color:1:1} ; green=${green}${green}
            blue=${color:2:1} ; blue=${blue}${blue}
        else
            red=${color:0:2}
            green=${color:2:2}
            blue=${color:4:2}
        fi

        echo $((16#${red})) $((16#${green})) $((16#${blue}))
    }

    hg_stat() {
        local stat _ root
        local -i modified=0 added=0 deleted=0 untracked=0

        root=$(hg root 2>/dev/null)
        if [[ -z "$root" ]]; then
            return 1
        fi

        root=${root##*/}

        local revision branch
        read -r revision branch < <(hg --debug id -i -b)

        while read -r stat _; do
            case ${stat} in
                M)
                    (( modified++ ))
                    ;;
                D|R)
                    (( deleted++ ))
                    ;;
                A)
                    (( added++ ))
                    ;;
                ?)
                    (( untracked++ ))
            esac
        done < <(hg status 2>/dev/null)

        stat="${modified}m ${added}a ${deleted}d ${untracked}u"
        echo "hg ${root} ${branch} ${revision} ${stat}"
    }

    git_stat() {
        local branch index=1 remote revision root stat _
        local -i modified=0 added=0 deleted=0 untracked=0

        read -ra remote < <(git remote -v show 2>/dev/null)

        if (( ${#remote[@]} == 0 )); then
            index=0
            read -ra remote < <(git rev-parse --show-toplevel 2> /dev/null)
        fi

        if (( ${#remote[@]} == 0 )); then
            return 1
        fi

        root=${remote[${index}]}
        root=${root##*/}
        root=${root%.git}
        root=${root##git:}

        branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
        revision=$(git rev-parse --short HEAD 2> /dev/null)

        while read -r stat _; do
            case ${stat} in
                M|MM)
                    (( modified++ ))
                    ;;
                D)
                    (( deleted++ ))
                    ;;
                R)
                    (( deleted++ ))
                    (( added++ ))
                    ;;
                A)
                    (( added++ ))
                    ;;
                *)
                    (( untracked++ ))
            esac
        done < <(git status --porcelain 2>/dev/null)

        stat="${modified}m ${added}a ${deleted}d ${untracked}u"
        echo "git ${root} ${branch} ${revision} ${stat}"
    }

    humanize_time() {
        local minutes seconds hours

        seconds=$1
        if [[ "${seconds:=0}" -le 120 ]] ; then
            echo "${seconds}s"
            return
        fi

        minutes=$(( seconds / 60 ))
        seconds=$(( seconds % 60 ))

        if [[ $minutes -gt 59 ]] ; then
            hours=$(( minutes / 60 ))
            minutes=$(( minutes % 60 ))
            printf "%d:%02d:%02ds" "${hours}" "${minutes}" "${seconds}"
            return
        fi

        printf "%d:%02ds" "${minutes}" "${seconds}"
    }

    get_previous_command_time() {
        local uptime hist histtime histcmd

        uptime=$SECONDS
        read -ra hist < <(history 1)
        histtime="${hist[1]}"
        histcmd="${hist[2]}"

        case "$histcmd" in
            sudo|ssh|hg|git|svn|man)
                histcmd="${histcmd} ${hist[3]}"
                ;;
        esac

        local histtime now elapsed

        if [[ -v EPOCHSECONDS ]]; then
            now=$EPOCHSECONDS
        else
            now=$(date +"%s")
        fi

        elapsed=$((now - histtime))

        # If the shell's uptime is less than elapsed, then this command was not
        # run in the current shell
        [[ "${elapsed}" -gt "${uptime}" ]] && return

        echo "${elapsed}" "${histcmd}"
    }

    # convert RBG string to ANSI
    rgb() {
        local -r fg=$1
        local -r bg=$2
        shift 2
        local attrs="$*"

        if [[ -z "${fg}${bg}" ]]; then
            echo "${RESET}"
            return
        fi

        local s=""
        local parts
        if [[ -n "${fg}" ]]; then
            read -ra parts < <(hextoint "$fg")
            s="${s}${ESC}38;2;${parts[0]};${parts[1]};${parts[2]}m\]"
        fi

        if [[ -n "${bg}" ]]; then
            read -ra parts < <(hextoint "$bg")
            s="${s}${ESC}48;2;${parts[0]};${parts[1]};${parts[2]}m\]"
        fi

        for attr in ${attrs}; do
            case ${attr} in
                bold)
                    s="${s}${BOLD}"
                    ;;
                underline|under)
                    s="${s}${UNDERSCORE}"
                    ;;
                blink)
                    s="${s}${BLINK}"
                    ;;
                reverse)
                    s="${s}${REVERSE}"
                    ;;
                *)
                    ;;
            esac
        done

        echo "${s}"
    }

    # reset colors
    off() {
        echo "${RESET}"
    }

    # A little hard to describe.
    # Turns:
    #
    # |one two three             |
    #
    # into
    #
    # |one        two       three|
    #
    # Where "one", "two", and "three" are $1, $2, and $3 respectively and the
    # space between the two "|"s is the length of the terminal.
    three_cent()
    {
        local p1 p2 l2 l3

        l2=$(len "$2") 
        l3=$(len "$3")
        p1=$((COLUMNS - l3))
        p2=$(( (COLUMNS - l2) / 2))

        line=$(printf "%- ${p1}s$3\r%- ${p2}s$2\r$1" "")
        line=${line//./·}

        echo "$line"
    }

    get_tty() {
        local tty seconds command elapsed

        tty=$1
        [[ "${WINDOW}" ]] && tty="${tty} «${WINDOW}»"
        read -r seconds command < <(get_previous_command_time)

        if [[ -z "$command" ]]; then
            echo "$tty"
            return
        fi

        elapsed=$(humanize_time "$seconds")

        echo "↑ ${command}: ${elapsed} $tty"
    }

    # get the color with the given name or return the default
    get_color() {
        local name color

        name=$1
        color=${default_colors[$name]}

        echo "${BASH_PROMPT_COLORS[$name]-$color}"
    }

    fancy_stats() {
        local sep=""
        local newstats=""
        local stat

        for stat in "$@"; do
            if [[ ${stat:0:1} == "0" ]]; then
                stat="٠٠"
            fi
            newstats="${newstats}${sep}${stat}"
            sep=" "
        done

        echo "${newstats}"
    }

    _() {
        if [[ -z "$*" ]]; then
            rgb "$(get_color fg)" "$(get_color bg)"
            return
        fi

        local fgcolor bgcolor
        if [[ -n "$1" ]]; then
            fgcolor=$(get_color "$1")
        fi

        if [[ -n "$2" ]]; then
            bgcolor=$(get_color "$2")
        fi

        rgb "${fgcolor}" "${bgcolor}" "$*"
    }

    # slower than the executable, but gets the job done
    builtin_bash_prompt_vars() {
        local myos myversion version loadavg load tty users

        case ${OSTYPE} in
            linux*)
                myos=Linux
                read -ra version < /proc/version
                myversion=${version[2]}
                read -ra loadavg < /proc/loadavg
                load="${loadavg[0]} ${loadavg[1]} ${loadavg[2]}"
                ;;
            netbsd)
                myos=NetBSD
                read -ra version < /proc/version
                myversion=${version[2]}
                myversion=${myversion%_STABLE}
                read -ra loadavg < /proc/loadavg
                load="${loadavg[0]} ${loadavg[1]} ${loadavg[2]}"
                ;;
            darwin*)
                myos=MacOS
                myversion="$(defaults read loginwindow SystemVersionStampAsString)"
                load="$(sysctl -n vm.loadavg)"
                load="${load:1:-1}"
                ;;
            *)
            myversion=$(uname -v)
            load="$(ps -e -o "" | wc -l) processes"
            ;;
        esac

        tty=$(tty)
        tty=${tty#/dev/}
        read -r users < <(w -h |wc -l)

        if [[ ! -v BASH_PROMPT_SKIP_VCS_CHECK ]]; then
            vcs="$(git_stat || hg_stat)"
        fi

        printf 'myos="%s"\nload="%s"\nmyversion="%s"\ntty="%s"\nusers="%s"\nvcs="%s"\n' "${myos}" "${load}" "${myversion}" "${tty}" "${users}" "${vcs}"
    }

    PS1='\$ '
    if [[ -e ~/.location ]]; then
        # shellcheck source=/dev/null
        source ~/.location
    fi

    local myos today myversion users tty load vcs
    if [[ -v BASH_PROMPT_SKIP_VCS_CHECK ]]; then
        eval "$(BASH_PROMPT_SKIP_VCS_CHECK="$BASH_PROMPT_SKIP_VCS_CHECK" bash_prompt_vars 2>/dev/null || builtin_bash_prompt_vars)"
    else
        eval "$(bash_prompt_vars 2>/dev/null || builtin_bash_prompt_vars)"
    fi

    myos="$(_ level1)${myos}"
    tty="$(get_tty "$tty")"
    today=$(printf "%(%a %b %d)T" "$EPOCHSECONDS")
    myversion=${myversion//-/ }
    local parts
    read -ra parts <<< "${myversion}"
    myversion="$(_ level2)${parts[0]/%.0/}$(_) $(_ level3)${ITALIC}${parts[1]}$(_)${parts[2]}"
    read -ra parts <<< "$load"
    load="$(_ level3)${parts[0]}$(_) $(_ level4)${parts[1]}$(_) $(_ level5)${parts[2]}$(_)"

    users="$(_ parens)${parens0} $(_ users)${users} users $(_ parens)${parens1}$(_)"

    if [[ -n "${vcs}" ]]; then
        local repo branch revision stat
        read -r vcs repo branch revision stat <<< "$vcs"
        users="$(_ parens)${parens0}$(_ vcs "" bold)${vcs}$(off)$(_)∙$(_ repo)${repo}$(_)∙$(_ branch)${branch}$(_)∙$(_ vcs)${ITALIC}${revision:0:7}$(off)$(_)$(_ parens)${parens1}$(_)"
        local modified added deleted untracked
        stat="$(fancy_stats ${stat})"
        read -r modified added deleted untracked <<< "${stat}"

        load="$(_ modified)${modified} $(_ added)${added} $(_ deleted)${deleted} $(_ untracked)${untracked}$(_)"
    fi

    local userhost
    userhost="<${LOGNAME}@${HOSTNAME%.*}>"
    local line
    line=(
        [0]="$(_ fg "" under)$(three_cent)$(off)\n"
        [1]="$(_)$(three_cent " $myos $myversion" "$users" "$load ")$(off)\n"
        [2]="$(_ fg bg under)$(three_cent " $today" "$userhost" "$tty ")$(off)\n"
        [3]="$(off)$(_ parens)${parens0}$(off)$PS1\w$(_ parens)${parens1}$(off)  "
    )

    case "${__prompt_mode}" in
        short)
            echo "${line[3]}"
            ;;
        none)
            echo '\$ '
            ;;
        *)
            echo "${line[0]}${line[1]}${line[2]}${line[3]}"
            ;;
    esac
)

prompt() {
    __prompt_mode="$1"
}

PROMPT_COMMAND='PS1="$(__create_prompt)"'

# vim: syntax=bash
