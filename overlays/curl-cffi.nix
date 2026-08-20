final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      curl-cffi = pyprev.curl-cffi.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_verify"
          "test_delete_cookies"
        ];
      });
    })
  ];
}
