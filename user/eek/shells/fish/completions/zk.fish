# Fish completions for zk — a plain text note-taking assistant.
# https://github.com/zk-org/zk
#
# Written against zk 0.15.6. Only the built-in commands and flags are
# completed. User-defined aliases (`zk config --list aliases`) are
# deliberately not, since they are personal to a notebook.
#
# Install by copying to $__fish_config_dir/completions/zk.fish, or into
# any directory on $fish_complete_path.

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# Name of the subcommand word, if one has been typed yet.
function __zk_command
    set -l tokens (commandline -opc)
    if test (count $tokens) -ge 2
        echo $tokens[2]
    end
end

# True before any subcommand has been typed, i.e. where the command list goes.
function __zk_needs_command
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 1
end

# True when the current subcommand is any of the given names.
function __zk_using_command
    set -l cmd (__zk_command)
    test -n "$cmd"; and contains -- $cmd $argv
end

# `list`, `graph` and `edit` share one filtering and sorting flag set.
function __zk_filtering
    __zk_using_command list graph edit
end

# True for `zk tag list` specifically: bare `zk tag` only accepts the global
# flags, so the formatting block must not be offered there.
function __zk_tag_list
    set -l tokens (commandline -opc)
    test (count $tokens) -ge 3; and test $tokens[2] = tag; and test $tokens[3] = list
end

# True when the cursor is at a positional argument rather than an option value,
# judged by whether the preceding token is a flag. Path arguments must not be
# offered while `--format` and friends are still waiting for their value.
function __zk_at_positional
    set -l tokens (commandline -opc)
    test (count $tokens) -ge 2; and not string match -qr '^-' -- $tokens[-1]
end

# Emitted from a function so the three filtering commands share one source of
# truth rather than three copies of the same twenty-odd flags.
function __zk_complete_filtering
    complete -c zk -f -n __zk_filtering -s i -l interactive -d 'Select notes interactively with fzf'
    complete -c zk -f -n __zk_filtering -s n -l limit -r -d 'Limit the number of notes found'
    complete -c zk -f -n __zk_filtering -s m -l match -r -d 'Terms to search for in the notes'
    complete -c zk -f -n __zk_filtering -s M -l match-strategy -r -a 'fts re exact' -d 'Text matching strategy'
    complete -c zk -f -n __zk_filtering -s x -l exclude -r -a '(__fish_complete_directories)' -d 'Ignore notes matching the given path, including its descendants'
    complete -c zk -f -n __zk_filtering -s t -l tag -r -d 'Find notes tagged with the given tags'
    complete -c zk -f -n __zk_filtering -l mention -r -d 'Find notes mentioning the title of the given ones'
    complete -c zk -f -n __zk_filtering -l mentioned-by -r -d 'Find notes whose title is mentioned in the given ones'
    complete -c zk -f -n __zk_filtering -s l -l link-to -r -d 'Find notes which are linking to the given ones'
    complete -c zk -f -n __zk_filtering -l no-link-to -r -d 'Find notes which are not linking to the given ones'
    complete -c zk -f -n __zk_filtering -s L -l linked-by -r -d 'Find notes which are linked by the given ones'
    complete -c zk -f -n __zk_filtering -l no-linked-by -r -d 'Find notes which are not linked by the given ones'
    complete -c zk -f -n __zk_filtering -l orphan -d 'Find notes which are not linked by any other note'
    complete -c zk -f -n __zk_filtering -l tagless -d 'Find notes which have no tags'
    complete -c zk -f -n __zk_filtering -l missing-backlink -d 'Find notes with at least one missing backlink'
    complete -c zk -f -n __zk_filtering -l broken-links -d 'Find notes with at least one broken internal link'
    complete -c zk -f -n __zk_filtering -l related -r -d 'Find notes which might be related to the given ones'
    complete -c zk -f -n __zk_filtering -l max-distance -r -d 'Maximum distance between two linked notes'
    complete -c zk -f -n __zk_filtering -s r -l recursive -d 'Follow links recursively'
    complete -c zk -f -n __zk_filtering -l created -r -d 'Find notes created on the given date'
    complete -c zk -f -n __zk_filtering -l created-before -r -d 'Find notes created before the given date'
    complete -c zk -f -n __zk_filtering -l created-after -r -d 'Find notes created after the given date'
    complete -c zk -f -n __zk_filtering -l modified -r -d 'Find notes modified on the given date'
    complete -c zk -f -n __zk_filtering -l modified-before -r -d 'Find notes modified before the given date'
    complete -c zk -f -n __zk_filtering -l modified-after -r -d 'Find notes modified after the given date'
    complete -c zk -f -n __zk_filtering -s s -l sort -r -d 'Order the notes by the given criterion'
end

# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

# Every entry below carries `-f`. That is not redundant: a bare
# `complete -c zk -f` does NOT suppress filenames for entries taking a
# required parameter, because fish treats an option's argument as a file
# position by default. The flag has to be repeated on each entry. Path
# arguments still complete, since their `-a '(__fish_complete_*)'` supplies
# the candidates explicitly.
#
# zk's own arguments are note paths and titles, not files, so the default
# listing is unwanted in every one of them.
complete -c zk -f -n __zk_needs_command -a init -d 'Create a new notebook in the given directory'
complete -c zk -f -n __zk_needs_command -a index -d 'Index the notes to be searchable'
complete -c zk -f -n __zk_needs_command -a config -d 'List configuration parameters'
complete -c zk -f -n __zk_needs_command -a new -d 'Create a new note in the given notebook directory'
complete -c zk -f -n __zk_needs_command -a list -d 'List notes matching the given criteria'
complete -c zk -f -n __zk_needs_command -a graph -d 'Produce a graph of the notes matching the given criteria'
complete -c zk -f -n __zk_needs_command -a edit -d 'Edit notes matching the given criteria'
complete -c zk -f -n __zk_needs_command -a tag -d 'Manage the note tags'

# ---------------------------------------------------------------------------
# global flags — accepted by every subcommand
# ---------------------------------------------------------------------------

complete -c zk -f -s h -l help -d 'Show context-sensitive help'
complete -c zk -f -l notebook-dir -r -a '(__fish_complete_directories)' -d 'Turn off notebook auto-discovery and set the notebook manually'
complete -c zk -f -s W -l working-dir -r -a '(__fish_complete_directories)' -d 'Run as if zk was started in PATH instead of the current directory'
complete -c zk -f -l no-input -d 'Never prompt or ask for confirmation'

# ---------------------------------------------------------------------------
# init / index
# ---------------------------------------------------------------------------

complete -c zk -f -n '__zk_using_command init; and __zk_at_positional' -a '(__fish_complete_directories)' -d 'Directory containing the notebook'

complete -c zk -f -n '__zk_using_command index' -s f -l force -d 'Force indexing all the notes'
complete -c zk -f -n '__zk_using_command index' -s v -l verbose -d 'Print detailed information about the indexing process'
complete -c zk -f -n '__zk_using_command index' -s q -l quiet -d 'Do not print statistics nor progress'

# ---------------------------------------------------------------------------
# config
# ---------------------------------------------------------------------------

complete -c zk -f -n '__zk_using_command config' -s l -l list -r -a 'aliases filters extras' -d 'List configuration objects'
complete -c zk -f -n '__zk_using_command config' -s f -l format -r -a 'short full json' -d 'Pretty print the list using a custom template or predefined format'
complete -c zk -f -n '__zk_using_command config' -l header -r -d 'Arbitrary text printed at the start of the list'
complete -c zk -f -n '__zk_using_command config' -l footer -r -d 'Arbitrary text printed at the end of the list'
complete -c zk -f -n '__zk_using_command config' -s d -l delimiter -r -d 'Print tags delimited by the given separator'
complete -c zk -f -n '__zk_using_command config' -s 0 -l delimiter0 -d 'Print tags delimited by ASCII NUL characters'
complete -c zk -f -n '__zk_using_command config' -s P -l no-pager -d 'Do not pipe output into a pager'
complete -c zk -f -n '__zk_using_command config' -s q -l quiet -d 'Do not print the total number of tags found'

# ---------------------------------------------------------------------------
# new
# ---------------------------------------------------------------------------

complete -c zk -f -n '__zk_using_command new; and __zk_at_positional' -a '(__fish_complete_directories)' -d 'Directory in which to create the note'
complete -c zk -f -n '__zk_using_command new' -s i -l interactive -d 'Read contents from standard input'
complete -c zk -f -n '__zk_using_command new' -s t -l title -r -d 'Title of the new note'
complete -c zk -f -n '__zk_using_command new' -l date -r -d 'Set the current date'
complete -c zk -f -n '__zk_using_command new' -s g -l group -r -d 'Name of the config group this note belongs to'
complete -c zk -f -n '__zk_using_command new' -l extra -r -d 'Extra variables passed to the templates'
complete -c zk -f -n '__zk_using_command new' -l template -r -a '(__fish_complete_path)' -d 'Custom template used to render the note'
complete -c zk -f -n '__zk_using_command new' -s p -l print-path -d 'Print the path of the created note instead of editing it'
complete -c zk -f -n '__zk_using_command new' -s n -l dry-run -d 'Do not create the note; print its content and generated path'
complete -c zk -f -n '__zk_using_command new' -l id -r -d 'Skip id generation and use the provided value'

# ---------------------------------------------------------------------------
# list / graph / edit
# ---------------------------------------------------------------------------

__zk_complete_filtering

# Note paths. Deliberately `-a` rather than `-F`: `--force-files` is not
# scoped to the condition, so it leaked file listings into every value
# position of every subcommand, including ones this line does not match.
complete -c zk -f -n '__zk_using_command list graph edit; and __zk_at_positional' -a '(__fish_complete_path)' -d 'Note path'

complete -c zk -f -n '__zk_using_command list' -s f -l format -r -a 'oneline short medium long full json jsonl' -d 'Pretty print the list using a custom template or predefined format'
complete -c zk -f -n '__zk_using_command list' -l header -r -d 'Arbitrary text printed at the start of the list'
complete -c zk -f -n '__zk_using_command list' -l footer -r -d 'Arbitrary text printed at the end of the list'
complete -c zk -f -n '__zk_using_command list' -s d -l delimiter -r -d 'Print notes delimited by the given separator'
complete -c zk -f -n '__zk_using_command list' -s 0 -l delimiter0 -d 'Print notes delimited by ASCII NUL characters'
complete -c zk -f -n '__zk_using_command list' -s P -l no-pager -d 'Do not pipe output into a pager'
complete -c zk -f -n '__zk_using_command list' -s q -l quiet -d 'Do not print the total number of notes found'

complete -c zk -f -n '__zk_using_command graph' -s f -l format -r -a json -d 'Format of the graph'
complete -c zk -f -n '__zk_using_command graph' -s q -l quiet -d 'Do not print the total number of notes found'

complete -c zk -f -n '__zk_using_command edit' -s f -l force -d 'Do not confirm before editing many notes at the same time'

# ---------------------------------------------------------------------------
# tag
# ---------------------------------------------------------------------------

complete -c zk -f -n '__zk_using_command tag' -a list -d 'List all the note tags'

complete -c zk -f -n __zk_tag_list -s f -l format -r -a 'name full json jsonl' -d 'Pretty print the list using a custom template or predefined format'
complete -c zk -f -n __zk_tag_list -l header -r -d 'Arbitrary text printed at the start of the list'
complete -c zk -f -n __zk_tag_list -l footer -r -d 'Arbitrary text printed at the end of the list'
complete -c zk -f -n __zk_tag_list -s d -l delimiter -r -d 'Print tags delimited by the given separator'
complete -c zk -f -n __zk_tag_list -s 0 -l delimiter0 -d 'Print tags delimited by ASCII NUL characters'
complete -c zk -f -n __zk_tag_list -s P -l no-pager -d 'Do not pipe output into a pager'
complete -c zk -f -n __zk_tag_list -s q -l quiet -d 'Do not print the total number of tags found'
complete -c zk -f -n __zk_tag_list -s s -l sort -r -d 'Order the tags by the given criterion'
