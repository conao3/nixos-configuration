{ lib }:
let
  opTag = "_agentsSettingOp";

  isOp = v: builtins.isAttrs v && v ? ${opTag};

  force = value: {
    ${opTag} = "force";
    inherit value;
  };

  delete = {
    ${opTag} = "delete";
  };

  migrate =
    { from, to }:
    {
      ${opTag} = "migrate";
      inherit from to;
    };

  flatten =
    onConflict: settings:
    let
      go =
        path: value:
        if isOp value then
          [
            (
              removeAttrs value [ opTag ]
              // {
                inherit path;
                op = value.${opTag};
              }
            )
          ]
        else if builtins.isAttrs value then
          lib.concatLists (lib.mapAttrsToList (name: go (path ++ [ name ])) value)
        else if onConflict == "overwrite" then
          [
            {
              inherit path value;
              op = "force";
            }
          ]
        else
          [
            {
              inherit path;
              op = "migrate";
              from = null;
              to = value;
            }
          ];
    in
    go [ ] settings;

  resolve =
    settings:
    lib.mapAttrs (
      _: v:
      if isOp v then
        v.value or v.to
      else if builtins.isAttrs v then
        resolve v
      else
        v
    ) (lib.filterAttrs (_: v: !(isOp v && v.${opTag} == "delete")) settings);
in
{
  inherit
    force
    delete
    migrate
    flatten
    resolve
    ;
}
