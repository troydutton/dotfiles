#!/bin/sh
# Claude adapter for the shared agent UI status-line specification.

# --- Multibyte capability probe ---
__u="é"
MB_OK=1
if [ ${#__u} -ne 1 ]; then
    __saved_lc_all="${LC_ALL-}"
    for __c in C.UTF-8 en_US.UTF-8 UTF-8; do
        LC_ALL=$__c; export LC_ALL
        [ ${#__u} -eq 1 ] && break
    done
    if [ ${#__u} -ne 1 ]; then
        MB_OK=""
        if [ -n "$__saved_lc_all" ]; then
            LC_ALL="$__saved_lc_all"; export LC_ALL
        else
            unset LC_ALL
        fi
    fi
fi

# --- Single jq pass over the payload and shared UI specification ---
AGENT_UI_SPEC_PATH="${AGENT_UI_SPEC_PATH:-$HOME/.agents/statusline.json}"
if [ -f "$AGENT_UI_SPEC_PATH" ]; then
    AGENT_UI_JQ_PATH="$AGENT_UI_SPEC_PATH"
else
    AGENT_UI_JQ_PATH=/dev/null
fi

eval "$(jq --slurpfile agent_ui "$AGENT_UI_JQ_PATH" -r '
  def k1: (. / 100 | round) as $t
        | (($t / 10 | floor | tostring) + "." + ($t % 10 | tostring) + "k");
  ($agent_ui[0] // {}) as $ui |
  (.context_window.total_input_tokens // 0) as $used |
  (.context_window.context_window_size // 0) as $size |
  @sh "segment_order=\(($ui.status_line.segments // ["workspace", "branch", "model_reasoning", "context", "five_hour_limit", "weekly_limit"]) | join(" "))",
  @sh "separator=\($ui.status_line.separator // " | ")",
  @sh "max_name_len=\($ui.status_line.max_name_length // 16)",
  @sh "bar_width=\($ui.status_line.bar_width // 10)",
  @sh "workspace_icon=\($ui.status_line.icons.workspace // "📂")",
  @sh "branch_icon=\($ui.status_line.icons.branch // "🌿")",
  @sh "model_icon=\($ui.status_line.icons.model // "🤖")",
  @sh "reasoning_icon=\($ui.status_line.icons.reasoning // "⚡")",
  @sh "context_icon=\($ui.status_line.icons.context // "🔋")",
  @sh "five_hour_icon=\($ui.status_line.icons.five_hour_limit // "⏳")",
  @sh "weekly_icon=\($ui.status_line.icons.weekly_limit // "📅")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "model=\(.model.display_name // "unknown")",
  @sh "repo_name=\(.workspace.repo.name // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "has_ctx=\(if $size > 0 then "1" else "" end)",
  @sh "used_k=\($used | k1)",
  @sh "total_k=\(($size / 1000 | round | tostring) + "k")",
  @sh "ctx_pct10=\(if $size > 0 then ($used * 1000 / $size | round) else 0 end)",
  @sh "five_hour_pct10=\(.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else (. * 10 | round) end)",
  @sh "seven_day_pct10=\(.rate_limits.seven_day.used_percentage // "" | if . == "" then "" else (. * 10 | round) end)",
  @sh "five_hour_reset_at=\(.rate_limits.five_hour.resets_at // "")",
  @sh "seven_day_reset_at=\(.rate_limits.seven_day.resets_at // "")"
')"
: "${cwd:=$PWD}"

# --- Rate limit cache ---
RATE_LIMIT_CACHE="$HOME/.claude/.statusline-ratelimit-cache"
five_hour_stale=""
seven_day_stale=""
if [ -z "$five_hour_pct10" ] || [ -z "$seven_day_pct10" ]; then
    if [ -f "$RATE_LIMIT_CACHE" ]; then
        . "$RATE_LIMIT_CACHE" 2>/dev/null
        if [ -z "$five_hour_pct10" ] && [ -n "$cached_five_hour_pct10" ]; then
            five_hour_pct10="$cached_five_hour_pct10"
            five_hour_reset_at="$cached_five_hour_reset_at"
            five_hour_stale="~"
        fi
        if [ -z "$seven_day_pct10" ] && [ -n "$cached_seven_day_pct10" ]; then
            seven_day_pct10="$cached_seven_day_pct10"
            seven_day_reset_at="$cached_seven_day_reset_at"
            seven_day_stale="~"
        fi
    fi
else
    new_cache="cached_five_hour_pct10='${five_hour_pct10}'
cached_five_hour_reset_at='${five_hour_reset_at}'
cached_seven_day_pct10='${seven_day_pct10}'
cached_seven_day_reset_at='${seven_day_reset_at}'"
    [ "$new_cache" = "$(cat "$RATE_LIMIT_CACHE" 2>/dev/null)" ] ||
        printf '%s\n' "$new_cache" > "$RATE_LIMIT_CACHE" 2>/dev/null
fi

# --- Shared helper: truncate a name to a max character count
case "$max_name_len" in
    ''|*[!0-9]*|0|1|2|3) MAX_NAME_LEN=16 ;;
    *) MAX_NAME_LEN=$max_name_len ;;
esac
case "$bar_width" in
    ''|*[!0-9]*|0) BAR_WIDTH=10 ;;
    *) BAR_WIDTH=$bar_width ;;
esac
truncate_name() {
    name="$1"
    if [ -z "$MB_OK" ]; then
        printf '%s' "$name" | perl -CS -ne '
            chomp;
            if (length($_) > '"$MAX_NAME_LEN"') {
                print substr($_, 0, '"$MAX_NAME_LEN"' - 3) . "...";
            } else {
                print $_;
            }
        '
        return
    fi
    if [ ${#name} -le $MAX_NAME_LEN ]; then
        printf '%s' "$name"
        return
    fi
    rest="$name"
    out=""
    i=0
    while [ $i -lt $(( MAX_NAME_LEN - 3 )) ]; do
        out="${out}${rest%"${rest#?}"}"
        rest="${rest#?}"
        i=$(( i + 1 ))
    done
    printf '%s...' "$out"
}

# --- Workspace segment: prefer repo name, fall back to directory basename ---
if [ -n "$repo_name" ]; then
    workspace="$repo_name"
else
    workspace="${cwd##*/}"
    [ -n "$workspace" ] || workspace="$cwd"
fi
workspace=$(truncate_name "$workspace")

# --- Git branch segment (short SHA when HEAD is detached) ---
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null) ||
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
branch=$(truncate_name "$branch")

# --- Shared helper: build a configurable block bar from tenths of a percent ---
bar_from_pct10() {
    filled=$(( ($1 * BAR_WIDTH + 500) / 1000 ))
    [ $filled -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
    [ $filled -lt 0 ] && filled=0
    b=""
    i=0
    while [ $i -lt $filled ]; do b="${b}█"; i=$(( i + 1 )); done
    i=$filled
    while [ $i -lt "$BAR_WIDTH" ]; do b="${b}░"; i=$(( i + 1 )); done
    printf '%s' "$b"
}

# --- Shared helper: render tenths of a percent as a whole-number percentage ---
pct10_round() {
    printf '%s' "$(( ($1 + 5) / 10 ))"
}

# --- Shared helper: format a unix timestamp, BSD date then GNU date ---
fmt_time() {
    date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null
}

# --- Context window progress bar ---
if [ -n "$has_ctx" ]; then
    ctx_segment="${context_icon} $(bar_from_pct10 "$ctx_pct10") ${used_k}/${total_k}"
    ctx_segment_compact="${context_icon} ${used_k}/${total_k}"
else
    ctx_segment="${context_icon} $(bar_from_pct10 0) -/-"
    ctx_segment_compact="${context_icon} -/-"
fi

# --- Rate limit segments, styled like the context bar ---
five_hour_segment=""
five_hour_segment_compact=""
if [ -n "$five_hour_pct10" ]; then
    five_hour_tail="${five_hour_stale}$(pct10_round "$five_hour_pct10")%"
    if [ -n "$five_hour_reset_at" ]; then
        five_hour_reset_str=$(fmt_time "$five_hour_reset_at" "%-I:%M%p")
        [ -n "$five_hour_reset_str" ] && five_hour_tail="${five_hour_tail} (${five_hour_reset_str})"
    fi
    five_hour_segment="${five_hour_icon} $(bar_from_pct10 "$five_hour_pct10") ${five_hour_tail}"
    five_hour_segment_compact="${five_hour_icon} ${five_hour_tail}"
fi

weekly_segment=""
weekly_segment_compact=""
if [ -n "$seven_day_pct10" ]; then
    seven_day_tail="${seven_day_stale}$(pct10_round "$seven_day_pct10")%"
    if [ -n "$seven_day_reset_at" ]; then
        seven_day_reset_str=$(fmt_time "$seven_day_reset_at" "%a")
        [ -n "$seven_day_reset_str" ] && seven_day_tail="${seven_day_tail} (${seven_day_reset_str})"
    fi
    weekly_segment="${weekly_icon} $(bar_from_pct10 "$seven_day_pct10") ${seven_day_tail}"
    weekly_segment_compact="${weekly_icon} ${seven_day_tail}"
fi

# --- Assemble semantic segments in the order from the shared specification ---
segments=""
segments_compact=""
emoji_count=0
append_segment() {
    full_value="$1"
    compact_value="$2"
    value_emoji_count="$3"
    [ -n "$full_value" ] || return
    if [ -n "$segments" ]; then
        segments="${segments}${separator}${full_value}"
        segments_compact="${segments_compact}${separator}${compact_value}"
    else
        segments="$full_value"
        segments_compact="$compact_value"
    fi
    emoji_count=$(( emoji_count + value_emoji_count ))
}

for segment_name in $segment_order; do
    case "$segment_name" in
        workspace)
            append_segment "${workspace_icon} ${workspace}" "${workspace_icon} ${workspace}" 1
            ;;
        branch)
            [ -n "$branch" ] &&
                append_segment "${branch_icon} ${branch}" "${branch_icon} ${branch}" 1
            ;;
        model_reasoning)
            model_reasoning_segment="${model_icon} ${model}"
            model_reasoning_emoji=1
            if [ -n "$effort" ]; then
                model_reasoning_segment="${model_reasoning_segment}${separator}${reasoning_icon} ${effort}"
                model_reasoning_emoji=2
            fi
            append_segment "$model_reasoning_segment" "$model_reasoning_segment" \
                "$model_reasoning_emoji"
            ;;
        context)
            append_segment "$ctx_segment" "$ctx_segment_compact" 1
            ;;
        five_hour_limit)
            append_segment "$five_hour_segment" "$five_hour_segment_compact" 1
            ;;
        weekly_limit)
            append_segment "$weekly_segment" "$weekly_segment_compact" 1
            ;;
    esac
done

# If the full line would overflow the terminal, compress the statusline
case "$COLUMNS" in
    ''|*[!0-9]*) ;;
    *)
        if [ -n "$MB_OK" ]; then
            width=$(( ${#segments} + emoji_count ))
        else
            width=$(printf '%s' "$segments" | perl -CS -ne 'chomp; print length($_)')
            width=$(( width + emoji_count ))
        fi
        if [ "$width" -gt "$COLUMNS" ]; then
            segments="$segments_compact"
        fi
        ;;
esac

printf "%s" "$segments"
