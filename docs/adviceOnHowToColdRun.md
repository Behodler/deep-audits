export CLAUDE_CODE_SUBAGENT_MODEL=opus
export CLAUDE_CODE_EFFORT_LEVEL=xhigh
claude --dangerously-skip-permissions --model opus --effort xhigh
Then, one project per context:
/full-audit <project> --full      # let it fully finish
/clear                            # then next project