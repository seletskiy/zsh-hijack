zstyle 'hijack:highlighting' style'fg=4'

_hijack_skip_history_first=false
_hijack_transformations=()

hijack:transform() {
    zparseopts -a opts -D 'e=is_expression'

    local condition=$1
    local transformation=$2

    if [ -z "$is_expression" -a "$transformation" ]; then
        condition="?${condition}"
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

    local MATCH MBEGIN MEND
    local match mbegin mend

    local i

    for (( i = 1; i < ${#_hijack_transformations}; i += 2 )); do
        condition=${_hijack_transformations[$i]}
        transformation=${_hijack_transformations[$i + 1]}

        if [[ "${condition[1]}" == "?" ]]; then
            if [[ ! "$buffer" =~ "${condition:1}" ]]; then
                continue
            fi
        else
            if ! condition_result=$(builtin eval $condition <<< $buffer); then
                continue
            fi
        fi

        if [ ! "$transformation" ]; then
            if [ "$condition_result" != "$buffer" ]; then
                result=0
            fi

            buffer=$condition_result
        else
            if new_buffer=$(builtin eval $transformation <<< $buffer); then
                result=0

                buffer=$new_buffer
            fi
        fi
    done

    printf "%s" "$buffer"

    return "$result"
}

:hijack:get-history-line() {
    printf "%s" "$1"
}

:hijack:hook() {
    local origin=$BUFFER
    local line=$(:hijack:get-history-line "$BUFFER")

    print -S -- "${line//\\/\\\\}"

    _hijack_skip_history_first=false

    if BUFFER="$(:hijack:apply "$BUFFER")"; then
        if type _zsh_highlight >/dev/null; then
            _zsh_highlight
        fi

        if [[ "$origin" != "$BUFFER" ]]; then
            _hijack_skip_history_first=true
        fi
    fi

    zle -R
}

zle -N hijack:history-substring-search-up

hijack:history-substring-search-up() {
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

:hijack:highlight() {
    local offsets=()
    local offset
    local highlighting

    zstyle -g highlighting 'hijack:highlighting' style

    if :hijack:apply "$BUFFER" > /dev/null; then
        hijack:_zsh_highlight
        _zsh_highlight_apply_zle_highlight hijack ${highlighting} "0" "${#BUFFER}"
        return 0
    else
        return 1
    fi
}

:hijack:bind-widget() {
    local id="$1"
    local widget="$2"
    local func="$3"
    shift 3

    local name="::hijack:widget:$id:$widget:$func"

    if [[ "${widgets[$name]}" ]]; then
        return
    fi

    local origin="$(zle -lL $widget | cut -f4- -d' ')"

    eval "$name() {
        $func ${@} \"$id\" \"\$@\"

        if [[ \"$origin\" ]]; then
            if [[ "\$\{widgets\[\$origin\]\}" ]]; then
                zle \"$origin\" -- \"\$@\"
            else
                $origin \"\$@\"
            fi
        fi
    }"

    zle -N "$name"
    zle -N "$widget" "$name"

}

:hijack:bind-widget ":hijack:finish" zle-line-finish :hijack:hook
