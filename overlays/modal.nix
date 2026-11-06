final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      synchronicity = pyprev.synchronicity.overridePythonAttrs (old: rec {
        version = "0.12.7";
        src = prev.fetchFromGitHub {
          owner = "modal-labs";
          repo = "synchronicity";
          tag = "v${version}";
          hash = "sha256-IOH69JpWIpKH/pzFoYA28XpKxPITHeHVtNhdwp6gfv0=";
        };
      });
      modal = pyprev.modal.overridePythonAttrs (old: rec {
        version = "1.6.3";
        src = prev.fetchFromGitHub {
          owner = "modal-labs";
          repo = "modal-client";
          tag = "py/v${version}";
          hash = "sha256-hs1XUfTKZ69+91UmK5Y/zdz+p79gPxcX5BIHDg4ht8E=";
        };
        sourceRoot = "${src.name}/py";
        doCheck = false;
        postPatch = ''
          grep -rl --include='*.py' 'def list(' modal | xargs sed -i 's/\([:>] \)list\[/\1builtins.list[/g'
          patchShebangs protoc_plugin/plugin.py
          inv protoc
          inv type-stubs
        '';
      });
    })
  ];
}
