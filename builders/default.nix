{ pkgs, callPackage }:
let
  base = callPackage ./base { };
  python = callPackage ./python { };
  docker = callPackage ./docker { base=base; };

in
 # add a reference for mere convenience for pkgs
 { inherit pkgs; } // base // python // docker
