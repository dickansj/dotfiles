
# not the most obvious place for this
#  function, but its need came from
#  seeing the prompt, so here it is.
function on_exit --on-process %self
  if test -n "$VIRTUAL_ENV"
    deactivate
  end
end

function _sjml_errcode_data -a errCode colorize
  if test $errCode -ne 0
    if test $colorize -ne 0
      set_color "red"
    end
    echo -n "Error code:"
    if test $colorize -ne 0
      set_color normal
    end
    echo -n " $errCode"
  end
end

function _sjml_tmux_data -a colorize
  if not test -z (string match 'screen*' $TERM)
    return
  end
  # no tmux, nothing to report - and the 2>/dev/null below only covers
  #   tmux's own stderr, not fish's "Unknown command" complaint
  if not type -q tmux
    return
  end
  set icon "⛶" #"⛚" #"⚄" #"▢" #"[]"
  set tmcount (command tmux list-sessions 2>/dev/null| grep -cv 'attached')
  set tmnames (command tmux list-sessions 2>/dev/null | sed -e "s/^\([^:]*\):.*/\1/" | string join ", ")
  if test $tmcount -ne 0
    echo -n "$icon $tmcount detached tmux session"
    if test $tmcount -gt 1
      echo -n "s"
    end
    echo -n " ($tmnames)"
  end
end

function _sjml_runtime_data -a runtime colorize
  if test $runtime -gt 3000
    if test $colorize -ne 0
      set_color "yellow"
    end
    echo -n "Long execution: "
    if test $colorize -ne 0
      set_color normal
    end
    set runtime (math $runtime / 1000.0)
    if test $runtime -ge 86400
      echo -n (math --scale=0 $runtime / 86400)
      echo -n "d"
    end
    if test $runtime -ge 3600
      echo -n (math --scale=0 $runtime % 86400 / 3600)
      echo -n "h"
    end
    if test $runtime -ge 60
      echo -n (math --scale=0 $runtime % 3600 / 60)
      echo -n "m"
    end
    printf "%.2fs" (math $runtime % 60.0)
  end
end

function fish_prompt
  set errStatus $status
  set cmdDur $CMD_DURATION

  set normColor "cyan"
  set remoteColor "green"
  set rootColor "red"
  set userColor "yellow"
  set hostColor "blue"
  set outlineColor $normColor
  set topLt "╭"
  set botLt "╰"
  set topRt "╮"
  set botRt "╯"
  set vertBar "│"
  set sep "─"

  set pchar "%"
  if test (id -u) -eq 0
    set pchar "#"
    set outlineColor $rootColor
  else if test -n "$SSH_CLIENT"
    set outlineColor $remoteColor
  else if test -n "$SSH_TTY"
    set outlineColor $remoteColor
  else
    set outlineColor $normColor
  end

  set snake "🐍"
  set dragon "🐉" # ♻️

  set prettyPath (rtab)
  set hostName (string split '.' $hostname)[1]

  set incUser    true
  set incHost    true

  set scaffold "$topLt$sep<> @ $sep$topRt"
  if test -n "$VIRTUAL_ENV"
    set scaffold "$scaffold\[$snake\]"
  else if test -n "$CONDA_SHLVL"
    if test $CONDA_SHLVL -gt 1
      set scaffold "$scaffold\[$dragon\]"
    end
  end

  set topLen (math  \
    (string length $scaffold) +   \
    (string length $prettyPath) + \
    (string length $USER) +       \
    (string length $hostName)     \
  )
  if test $topLen -ge $COLUMNS;
    set incUser false
    set topLen (math  \
        (string length $scaffold) +   \
        (string length $prettyPath) + \
        (string length $hostName)     \
    )
  end
  if test $topLen -ge $COLUMNS;
    set incHost false
    set topLen (math  \
      (string length $scaffold) +   \
      (string length $prettyPath)
  )
  end
  if test $topLen -gt $COLUMNS;
    set lenDiff (math \
      $topLen - \
      $COLUMNS
    )
    # character slice via `string sub`, NOT $prettyPath[n..-1] - that's a
    #   *list* slice on a one-element list, which silently yields the whole
    #   path or nothing. Shave lenDiff+1 leading chars, spend one back on
    #   the ellipsis, and the line comes out exactly $COLUMNS wide.
    set prettyPath "…"(string sub --start (math $lenDiff + 2) -- $prettyPath)
  end

  set lcount 0
  set_color $outlineColor
  echo -n "$topLt$sep"
  set lcount (math $lcount + 2)
  set_color normal
  echo -n "($prettyPath)"
  set lcount (math $lcount + 2 + (string length $prettyPath))
  if test -n "$VIRTUAL_ENV"
    echo -n "[$snake]"
    set lcount (math $lcount + 3 + (string length $snake))
  else if test -n "$CONDA_SHLVL"
    if test $CONDA_SHLVL -gt 1
      echo -n "[$dragon]"
      set lcount (math $lcount + 3 + (string length $dragon))
    end
  end
  set rcount 6
  if $incUser;
    set rcount (math (string length $USER) + $rcount)
  end
  if $incHost;
    set rcount (math (string length $hostName) + $rcount)
  end
  set_color $outlineColor
  # clamped at 0: emoji widths and pathological terminal sizes can still
  #   push the count negative, which `string repeat` rejects outright
  echo -n (string repeat -n (math "max(0, $COLUMNS - $lcount - $rcount)") $sep)
  set_color normal
  echo -n " "
  if $incUser; and $incHost;
    set_color $userColor
    echo -n $USER
    set_color normal
    echo -n "@"
    set_color $hostColor
    echo -n "$hostName"
  else if $incHost;
    set_color $userColor
    echo -n "@"
    set_color $hostColor
    echo -n $hostName
  else
    set_color $userColor
    echo -n "@"
  end
  set_color normal
  echo -n " "
  set_color $outlineColor
  echo $sep$topRt

  set -a plainAlerts (_sjml_errcode_data $errStatus 0)
  set -a alerts      (_sjml_errcode_data $errStatus 1)

  set -a plainAlerts (_sjml_tmux_data 0)
  set -a alerts      (_sjml_tmux_data 1)

  set -a plainAlerts (_sjml_runtime_data $cmdDur 0)
  set -a alerts      (_sjml_runtime_data $cmdDur 1)

  if test (count $alerts) -gt 0
    for ali in (seq (count $alerts));
      set al $alerts[$ali]
      set alp $plainAlerts[$ali]
      set_color $outlineColor
      echo -n $vertBar
      set_color normal
      echo -n " $al"
      set_color normal
      # same 0-clamp as the top line: a long alert (e.g. many tmux session
      #   names) can exceed the terminal width
      set alpLen (string length $alp)
      echo -n (string repeat -n (math "max(0, $COLUMNS - 4 - $alpLen)") " ")
      set_color $outlineColor
      echo $vertBar
    end
  end

  # long-command notification: macOS-only (mdls / get-frontmost / teller);
  #   $__CFBundleIdentifier is only set by macOS GUI terminals, so its
  #   absence (SSH, Linux, tmux from a login shell) skips the whole thing
  if test $cmdDur -gt 10000; and test -n "$__CFBundleIdentifier"
    if ! string match --quiet " *" $history[1]
      if test "$__CFBundleIdentifier" != (mdls -name kMDItemCFBundleIdentifier -r (get-frontmost))
        if test $errStatus -eq 0
          teller success --message $history[1] --title Success --sound Glass
        else
          teller failure --message $history[1] --title ERROR --sound Basso
        end
      end
    end
  end

  set_color $outlineColor
  echo -n $botLt$sep
  set_color normal
  echo -n " $pchar> "
end

function fish_right_prompt
  set normColor "cyan"
  set remoteColor "green"
  set rootColor "red"
  set userColor "yellow"
  set hostColor "blue"
  set outlineColor $normColor
  set topLt "╭"
  set botLt "╰"
  set topRt "╮"
  set botRt "╯"
  set vertBar "│"
  set sep "─"

  if test (id -u) -eq 0
    set outlineColor $rootColor
  else if test -n "$SSH_CLIENT"
    set outlineColor $remoteColor
  else if test -n "$SSH_TTY"
    set outlineColor $remoteColor
  else
    set outlineColor $normColor
  end

  set_color normal

  git rev-parse --is-inside-work-tree >/dev/null 2>&1
  if test $status -eq 0
    fish_git_prompt
  else
    date "+%d-%b %H:%M"
  end

  set_color $outlineColor
  echo " $botRt "
end
