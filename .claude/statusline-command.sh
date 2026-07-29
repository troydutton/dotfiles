#!/bin/sh
# Claude Code statusline: workspace | branch | model | effort | context | limits
#
# Runs on every render (each message and tool event), so the hot path avoids
# subprocesses: one jq call for the whole payload, integer arithmetic instead of
# awk, and shell builtins for string work. perl is only reached on shells with
# no multibyte support (see the probe below), where builtins would count bytes.

# --- Multibyte capability probe ---
# ${#var} and ${var#?} only count characters when the shell has multibyte
# support AND a UTF-8 locale; bash/zsh do, dash never does (and /bin/sh is dash
# on Debian/Ubuntu). Probe with a 2-byte character: first try to fix the locale,
# and if the shell still counts bytes, fall back to perl for the two places
# where character counts actually matter. MB_OK empty means "use perl".
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

# --- Single jq pass over the payload ---
# Emits @sh-quoted `name=value` lines for eval. Percentages are carried as
# tenths of a percent (integers) so the bars can be computed without floats.
eval "$(jq -r '
  def k1: (. / 100 | round) as $t
        | (($t / 10 | floor | tostring) + "." + ($t % 10 | tostring) + "k");
  (.context_window.total_input_tokens // 0) as $used |
  (.context_window.context_window_size // 0) as $size |
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
# Claude Code omits `rate_limits` from the statusline input until the first
# API response of a session comes back, so the limit segment would otherwise
# be blank for a few seconds on every new session. Persist the last known
# values so we can show them immediately (flagged as possibly-stale with
# "~") instead of showing nothing until fresh data arrives. Only rewrite the
# file when a value actually changed, since this runs on every render.
RATE_LIMIT_CACHE="$HOME/.claude/.statusline-ratelimit-cache"
five_hour_stale=""
seven_day_stale=""
if [ -z "$five_hour_pct10" ] || [ -z "$seven_day_pct10" ]; then
    if [ -f "$RATE_LIMIT_CACHE" ]; then
        # shellcheck disable=SC1090
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

# --- Shared helper: truncate a name to a max character count, adding a
# trailing "..." when it's cut. Keeps a single long branch/project name from
# blowing out the whole line's width.
MAX_NAME_LEN=16
truncate_name() {
    name="$1"
    if [ -z "$MB_OK" ]; then
        # Shell counts bytes: let perl do the character-aware slicing.
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

# --- Shared helper: build a 10-cell block bar from tenths of a percent ---
# Appends whole glyph literals rather than slicing a template string, so this
# stays correct even where the shell has no multibyte support.
bar_from_pct10() {
    filled=$(( ($1 + 50) / 100 ))
    [ $filled -gt 10 ] && filled=10
    [ $filled -lt 0 ] && filled=0
    b=""
    i=0
    while [ $i -lt $filled ]; do b="${b}█"; i=$(( i + 1 )); done
    i=$filled
    while [ $i -lt 10 ];      do b="${b}░"; i=$(( i + 1 )); done
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
# Each bar-bearing segment gets a "full" form (with bar) and a "compact" form
# (numbers only); the compact forms are used when the full line would overflow.
if [ -n "$has_ctx" ]; then
    ctx_segment="🔋 $(bar_from_pct10 "$ctx_pct10") ${used_k}/${total_k}"
    ctx_segment_compact="🔋 ${used_k}/${total_k}"
else
    ctx_segment="🔋 ░░░░░░░░░░ -/-"
    ctx_segment_compact="🔋 -/-"
fi

# --- Effort segment ---
if [ -n "$effort" ]; then
    effort_segment="⚡ ${effort}"
fi

# --- Rate limit segment (session / weekly usage), styled like the context bar ---
limit_segment=""
limit_segment_compact=""
if [ -n "$five_hour_pct10" ]; then
    five_hour_tail="${five_hour_stale}$(pct10_round "$five_hour_pct10")%"
    if [ -n "$five_hour_reset_at" ]; then
        five_hour_reset_str=$(fmt_time "$five_hour_reset_at" "%-I:%M%p")
        [ -n "$five_hour_reset_str" ] && five_hour_tail="${five_hour_tail} (${five_hour_reset_str})"
    fi
    limit_segment="⏳ $(bar_from_pct10 "$five_hour_pct10") ${five_hour_tail}"
    limit_segment_compact="⏳ ${five_hour_tail}"
fi
if [ -n "$seven_day_pct10" ]; then
    seven_day_tail="${seven_day_stale}$(pct10_round "$seven_day_pct10")%"
    if [ -n "$seven_day_reset_at" ]; then
        seven_day_reset_str=$(fmt_time "$seven_day_reset_at" "%a")
        [ -n "$seven_day_reset_str" ] && seven_day_tail="${seven_day_tail} (${seven_day_reset_str})"
    fi
    seven_day_full="📅 $(bar_from_pct10 "$seven_day_pct10") ${seven_day_tail}"
    seven_day_compact="📅 ${seven_day_tail}"
    if [ -n "$limit_segment" ]; then
        limit_segment="${limit_segment} | ${seven_day_full}"
        limit_segment_compact="${limit_segment_compact} | ${seven_day_compact}"
    else
        limit_segment="$seven_day_full"
        limit_segment_compact="$seven_day_compact"
    fi
fi

# --- Assemble segments ---
# Everything up to the context segment is identical in both forms, so build
# that shared prefix once and append either the full (with bars) or compact
# (numbers only) tail depending on available width.
prefix="📂 ${workspace}"
[ -n "$branch" ] && prefix="$prefix | 🌿 $branch"
prefix="$prefix | 🤖 ${model}"
[ -n "$effort_segment" ] && prefix="$prefix | $effort_segment"

segments="$prefix | $ctx_segment"
[ -n "$limit_segment" ] && segments="$segments | $limit_segment"

# If the full line would overflow the terminal, drop the bars and keep the
# numbers. COLUMNS is set by Claude Code to the current terminal width; when it
# is unset or non-numeric (e.g. older clients), keep the full line unchanged.
# ${#segments} counts characters; each segment carries exactly one emoji, and
# emoji render two cells wide, so add the segment count to get display width.
# Where the shell counts bytes instead, perl does the counting.
case "$COLUMNS" in
    ''|*[!0-9]*) ;;
    *)
        emoji=3
        [ -n "$branch" ] && emoji=$(( emoji + 1 ))
        [ -n "$effort_segment" ] && emoji=$(( emoji + 1 ))
        [ -n "$five_hour_pct10" ] && emoji=$(( emoji + 1 ))
        [ -n "$seven_day_pct10" ] && emoji=$(( emoji + 1 ))
        if [ -n "$MB_OK" ]; then
            width=$(( ${#segments} + emoji ))
        else
            width=$(printf '%s' "$segments" | perl -CS -ne 'chomp; print length($_)')
            width=$(( width + emoji ))
        fi
        if [ "$width" -gt "$COLUMNS" ]; then
            segments="$prefix | $ctx_segment_compact"
            [ -n "$limit_segment_compact" ] && segments="$segments | $limit_segment_compact"
        fi
        ;;
esac

printf "%s" "$segments"
