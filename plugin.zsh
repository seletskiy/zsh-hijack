_hijack_skip_history_first=false
_hijack_command_modified=false

_hijack_transformations=()

function hijack:transform() {
    zparseopts -a opts -D '-e=is_expression'

    local condition=$1
    local transformation=$2

    if [ -z "$is_expression" -a "$transformation" ]; then
        condition="grep -Eq ${(q)condition}"
    fi

    _hijack_transformations+=("$condition" "$transformation")
}

function hijack:reset() {
    _hijack_transformations=()
}

function :hijack:apply() {
    local command="$1"
    local condition
    local transformation
    local condition_result
    local new_command

    local i
    # typeset -A doesn't work for whatever reason here, however, it works if
    # applied in ~/.zshrc. WTF!
    for (( i = 1; i < ${#_hijack_transformations}; i += 2 )); do
        condition=${_hijack_transformations[$i]}
        transformation=${_hijack_transformations[$i + 1]}
        if condition_result=$(eval $condition <<< $command); then
            if [ ! "$transformation" ]; then
                command=$condition_result
            else
                if new_command=$(eval $transformation <<< $command); then
                    command=$new_command
                fi
            fi
        fi
    done

    printf "%s" "$command"
}

function :hijack:hook() {
    print -S "${BUFFER//\\/\\\\}"

    BUFFER="$(:hijack:foreach-pipe "$BUFFER")"
}

function :hijack:foreach-pipe() {
    local buffer="$1"

    local offset=()
    local _offsets=()
    local offsets_var="${2:-_offsets}"

    local parts=(${(z)buffer})

    local curr_pipe_index=1
    local prev_pipe_index=1
    local pipe_number=1

    local new_parts=()
    local command
    local command_regexp=""
    local new_command

    local command_part
    local command_index

    while (( curr_pipe_index <= ${#parts} )); do
        curr_pipe_index=${parts[(in.pipe_number.)\|]}
        command=(${parts[prev_pipe_index, curr_pipe_index - 1]})
        command="${command[@]}"

        new_command=$(:hijack:apply "${command}")
        if [ "$new_command" != "$command" ]; then
            _hijack_skip_history_first=true
            _hijack_command_modified=true

            # FIXME: implement precise highlighting
            _offsets=(0 ${#command})
        fi

        new_parts+=$new_command

        pipe_number+=1
        prev_pipe_index=$(( curr_pipe_index + 1 ))
    done

    eval $offsets_var='(${_offsets[@]})'

    printf "%s" "${(j: | :)new_parts}"
}

function :hijack:drop-history() {
    return 1
}

function :hijack:reset-history-skip() {
    if ! $_hijack_command_modified ; then
        _hijack_skip_history_first=false
    fi

    _hijack_command_modified=false
}

function hijack:history-substring-search-up() {
    zle kill-word
    zle history-substring-search-up

    if $_hijack_skip_history_first; then
        zle history-substring-search-up

        :hijack:reset-history-skip
    fi
}

zle -N zle-line-finish :hijack:hook
zle -N hijack:history-substring-search-up

add-zsh-hook zshaddhistory :hijack:drop-history
add-zsh-hook preexec :hijack:reset-history-skip

_zsh_highlight_hijack_highlighter_predicate() {
    _zsh_highlight_buffer_modified
}

_zsh_highlight_hijack_highlighter() {
    local offsets=()
    local offset
    local highlighting

    zstyle -g highlighting 'hijack:highlighting'

    :hijack:foreach-pipe "$BUFFER" "offsets" > /dev/null

    local i
    for (( i = 1; i < ${#offsets}; i += 2 )); do
        region_highlight+=("${offsets[i]} ${offsets[i + 1]} ${highlighting}")
    done
}

zstyle 'hijack:highlighting' 'fg=4'
