final: prev: {
  go-tools = {
    deck = prev.buildGoModule rec {
      pname = "deck";
      version = "1.21.3";

      src = prev.fetchFromGitHub {
        owner = "k1LoW";
        repo = "deck";
        rev = "v${version}";
        sha256 = "sha256-HsEOZ96E6geak1rnEypLO1J1MGS0JHyFdlCZBsY9QJU=";
      };

      vendorHash = "sha256-Ik3wwjKgxiHhWRpMjUgb8A1u763NJ3JeYo3A7Yo8Y4o=";
      doCheck = false;
    };
  };
}
