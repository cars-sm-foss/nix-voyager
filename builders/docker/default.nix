{ callPackage, base }:
{
  mkDockerBuild = callPackage ./base-builder.nix { inherit base; };
}
