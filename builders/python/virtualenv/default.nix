{ pkgs , fetchurl, lib , builders }:
{ mainPackageName
, src
, installDepsFromRequires ? ""
, systemPython ? "/usr/bin/python"
, virtualEnvSrc ? null
, preLoadedPythonDeps ? []
, exposedCmds ? []
, useBinaryWheels ? false
, namePrefix ? null
, logExecution ? false
, ...} @ args:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkBuild;

  defaultVirtualEnvSrc = fetchurl {
     url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.2.0.tar.gz";
     sha256 = "1ka0rlwhcsqkv995jr1xfglhj9d94avbwippxszx52xilwqnhwzs";
   };

  virtualEnvTar = (
    if virtualEnvSrc != null
      then  virtualEnvSrc
    else  defaultVirtualEnvSrc
  );

  coreAttributes = {
    inherit logExecution;
    namePrefix = args.namePrefix or null;
    allowedSystemCmds = [
      "/usr/bin/ldd"
      "/usr/bin/lsb_release"
      "/usr/bin/dpkg-query" # dependency of lsb_release
      "/usr/bin/gcc"
      "/bin/uname"
    ];
    buildInputs = with pkgs; [
      gnutar gzip which file findutils
      coreutils gnugrep
    ];
    scriptPath = ./python-venv-builder.sh;
    directAttrs = {
      preLoadedPythonDeps = lists.flatten (map (d: [ d.name d.src ]) preLoadedPythonDeps);
      inherit mainPackageName src systemPython virtualEnvSrc
              exposedCmds useBinaryWheels virtualEnvTar
              installDepsFromRequires;
    };
  };

  mkBuildArgs = removeAttrs args (attrNames coreAttributes.directAttrs);
in
   mkBuild (coreAttributes // mkBuildArgs)
