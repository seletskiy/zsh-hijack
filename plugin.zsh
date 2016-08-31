_hijack_skip_history_first=false
_hijack_transformations=()

hijack:transform() {
    zparseopts -a opts -D '-e=is_expression'

    local condition=$1
    local transformation=$2

    if [ -z "$is_expression" -a "$transformation" ]; then
        condition="grep -Eq ${(q)condition}"
    fi

    _hijack_transformations+=("$condition" "$transformation")
}

hijack:reset() {
    _hijack_transformations=()
}

:hijack:apply() {
    local buffer="$1"

    local condition
    local transformation
    local condition_result
    local new_buffer
    local result=1

    for (( i = 1; i < ${#_hijack_transformations}; i += 2 )); do
        condition=${_hijack_transformations[$i]}
        transformation=${_hijack_transformations[$i + 1]}

        if condition_result=$(eval $condition <<< $buffer); then
            if [ ! "$transformation" ]; then
                if [ "$condition_result" != "$buffer" ]; then
                    result=0
                fi

                buffer=$condition_result
            else
                if new_buffer=$(eval $transformation <<< $buffer); then
                    result=0

                    buffer=$new_buffer
                fi
            fi
        fi
    done

    printf "%s" "$buffer"

    return "$result"
}

zle -N zle-line-finish :hijack:hook

:hijack:hook() {
    print -S "${BUFFER//\\/\\\\}"

    _hijack_skip_history_first=false

    if BUFFER="$(:hijack:apply "$BUFFER")"; then
        if type _zsh_highlight >/dev/null; then
             _zsh_highlight
        fi

        _hijack_skip_history_first=true
    fi
}

zle -N hijack:history-substring-search-up

hijack:history-substring-search-up() {
    zle kill-word
    zle history-substring-search-up

    if $_hijack_skip_history_first; then
        zle history-substring-search-up

        _hijack_skip_history_first=false
    fi
}

add-zsh-hook zshaddhistory :hijack:on-history-add

:hijack:on-history-add() {
    return 1
}

_zsh_highlight_hijack_highlighter_predicate() {
    _zsh_highlight_buffer_modified
}

_zsh_highlight_hijack_highlighter() {
    local offsets=()
    local offset
    local highlighting

    zstyle -g highlighting 'hijack:highlighting'

    if :hijack:apply "$BUFFER" > /dev/null; then
        region_highlight+=("0 ${#BUFFER} ${highlighting}")
    fi
}

zstyle 'hijack:highlighting' 'fg=4'
