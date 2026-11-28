import { Plugin } from "@opencode/plugin"

const message =
  "CI の完了は `gh lookout wait <owner>/<repo> <sha>` で待つ (MEMORY.md「git 運用」)。この `gh run watch` / `gh pr checks --watch` の呼び出しは止めた。"
const watch =
  /(^|[;&|(`]|\$\(|(^|\s)(do|then|else|time|timeout\s+[0-9]+[a-z]?))\s*gh\s+(run\s+watch|pr\s+checks[^;&|]*--watch)(\s|$)/m

export default Plugin.define({
  id: "ci-wait",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      const command = (event.input as { command?: string }).command ?? ""
      if (event.tool === "shell" && watch.test(command)) throw new Error(message)
    })
  },
})
