final: prev: {
  code-cursor = prev.code-cursor.overrideAttrs (old: {
    src = prev.appimageTools.extract {
      pname = "cursor";
      version = old.version;
      src = prev.fetchurl {
        url = "https://downloads.cursor.com/production/475871d112608994deb2e3065dfb7c6b0baa0c54/linux/x64/Cursor-3.0.16-x86_64.AppImage";
        hash = "sha256-dN8tFSppIpO/P0Thst5uaNzlmfWZDh0Y81Lx1BuSYt0=";
      };
    };
  });
}
