{ pkgs, callPackage }:
let
  base = callPackage ./base { };
  python = callPackage ./python { };
  docker = callPackage ./docker { base=base; };

in
 base // python // docker
