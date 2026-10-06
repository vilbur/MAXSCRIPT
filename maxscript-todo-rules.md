# MaxScript TODO Rules

Use these rules for project `TODO.md` files.

## TODO queue order

Add new pending tasks to the bottom of `## QUEUE`.

Process `## QUEUE` strictly from top to bottom. The first task in the queue is the next queued task to execute.

## TODO mass processing

Process tasks in queue order. Consecutive tasks may be grouped into one change set only when they have the same prefix and affect the same canonical file or file set.

For a grouped change set:

1. Keep the original top-to-bottom queue order.
2. Stop the group at the first task with a different prefix or different affected file set.
3. Read each affected canonical file once from the latest Google Drive state.
4. Apply all tasks in the group to that same working copy.
5. Increment each modified file version once for the whole group.
6. Increment the shared project version once for the whole group.
7. Update and verify each modified canonical file on Google Drive once for the whole group.
8. Move every completed task from the group to `## DONE TODAY`, giving each task the same resulting project-version prefix.
9. Immediately write the updated canonical `TODO.md` to Google Drive after the group completes.
10. Re-read the latest `TODO.md` from Google Drive before starting the next task or group.

Do not group tasks merely because their prefixes match. They must also affect the same canonical file or file set.

Do not skip over an intervening task to create a batch. Only consecutive queue tasks may be grouped.

If a task must be completed separately, update its modified canonical files and `TODO.md` immediately after that task before continuing.

Never batch multiple completed tasks and update `TODO.md` only at the end.
