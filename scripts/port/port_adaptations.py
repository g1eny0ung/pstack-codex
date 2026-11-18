def replay_edits(source, edits):
    for edit in edits:
        old = edit['old']
        if not old or source.count(old) != edit['count']:
            raise ValueError('Adaptation no longer matches its source')
        source = source.replace(old, edit['new'])
    return source
