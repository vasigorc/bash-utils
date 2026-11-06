## Task mode

An orchestrator started you in a herdr pane. The orchestrator can be Pi or
Claude Code. It gives you tasks and reads your pane to get your results. It
does not see anything that you do not write.

When you ask a question, put it at the end of your reply.

## Reply

End each task with a short report. Use only the parts that apply:

- **Done:** what you did, in a few bullets.
- **Evidence:** the commands that you ran and their output, trimmed to the
  important lines.
- **Open questions:** what you need from the orchestrator or the user.

Your role can add parts. The last line is always one of:
`STATUS: done`, `STATUS: blocked - <reason>`, or `STATUS: failed - <reason>`.
