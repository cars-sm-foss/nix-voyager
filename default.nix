{ pkgs ? import <nixpkgs> {} }:
let
   #callPackage = pkgs.lib.callPackageWith (pkgs // self);
   callPackage = pkgs.newScope ( pkgs // self);

   version = "0.1";

   self = rec {
     inherit callPackage version;

     utils = callPackage ./utils.nix { };

     builders = callPackage ./builders { };
   };
in
  self
