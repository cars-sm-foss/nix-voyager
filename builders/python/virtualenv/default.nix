# builds copyable virtualenvs on ubuntu 16.04
{ pkgs , fetchurl, lib , builders }:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkDockerBuild;
in
{
# name of the package
  name

# a path (or nix derivation) containing all the python dists you want in the
# virtualenv. the builder will loop over the given directory and run
# `pip install <dist>` on each item. You can use source dists/wheel dists/etc,
# as long as they are pip installable.
# (for nix derivations, it will loop over the /nix/store/<hash>-your-derivation/
# directory)
, pythonDependencies

# full path to the python executable in the system, that's
# going to be used to build the virtualenv
, systemPython

# optionally supply a different version of virtualenv
, virtualEnvSrc ? null

# this is mainly for specifying alternate debian/ubuntu repos for
# python and its dependencies
, targetSystemRepos ? []

# if you need the public signing key for any of those you can add the
# hex ID of the key here (or anything usable by apt-key).
# e.g. "0xF1656F24C74CD1D8"
, targetSystemAptKeys ? []

, targetSystemBuildDependencies ? null

, extraTargetSystemBuildDependencies ? []
}:
mkDockerBuild {
  name = name;

  nixVoyagerScript = ./build_virtualenv.sh;

  envVars = { inherit systemPython; };
  nixVoyagerExpressionArgs = {
    inherit pythonDependencies;
    virtualEnvSrc = if (virtualEnvSrc != null) then virtualEnvSrc else  pkgs.fetchurl {
      url = https://files.pythonhosted.org/packages/22/e1/ec3567a4471aa812a3fcf85b2f25e1b79a617da8b1f716ea3a9882baf4fb/virtualenv-16.7.3.tar.gz;
      sha256 = "5e4d92f9a36359a745ddb113cabb662e6100e71072a1e566eb6ddfcc95fdb7ed";
    };
  };
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";

  # TODO: this should not be hardcoded, but it's the only current use case. it can be
  # changed when we have more use cases.
  targetSystem = "ubuntu-16.04";

  inherit targetSystemRepos targetSystemAptKeys;

  targetSystemBuildDependencies = if (targetSystemBuildDependencies != null) then targetSystemBuildDependencies else [
     "make"
     "gcc"
     "g++"
     "build-essential"
  ] ++ extraTargetSystemBuildDependencies;

  outputs = [ "out" ];

  # debug settings
  alwaysRemoveBuildContainers = true;
  keepBuildImage = false;
}
