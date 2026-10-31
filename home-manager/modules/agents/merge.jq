reduce $ops[0][] as $op ({result: ., warnings: []};
  (.result | getpath($op.path)) as $cur
  | if $op.op == "force" then
      .result |= setpath($op.path; $op.value)
    elif $op.op == "delete" then
      .result |= delpaths([$op.path])
    elif $cur == $op.from then
      .result |= setpath($op.path; $op.to)
    elif $cur == $op.to then
      .
    else
      .warnings += [
        "\u001b[1;33mWARN: \($label): \($target): .\($op.path | join(".")): expected \($op.from | tojson) or \($op.to | tojson), got \($cur | tojson), skipping\u001b[0m"
      ]
    end)
