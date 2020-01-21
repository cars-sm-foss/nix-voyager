{ pkgs ? import <nixpkgs> {} }:
let

   # nix voyager is primarily used as a library to build docker-based
   # derivations. in practice this means there will be some other package set
   # with its own `pkgs` reference and `callPackage` function that loads this
   # library. `newScope` is used here to make sure `pkgs` is kept separate,
   # following examples in nixpkgs. if it ends up being unnecessary we can
   # replace it with a more standard callPackage definition
   callPackage = pkgs.newScope ( pkgs // self);

   version = "0.1";

   self = rec {
     inherit callPackage version;

     utils = callPackage ./utils.nix { };

     builders = callPackage ./builders { };
   };
in
  self
