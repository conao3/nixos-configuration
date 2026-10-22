{
  inputs,
  system,
  ...
}:
{
  home.packages = with inputs.llm-agents.packages.${system}; [
    t3code
    t3code-desktop
  ];
}
