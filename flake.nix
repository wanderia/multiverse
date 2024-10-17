{
  description = "wanderia infra";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    deployPkgs = import nixpkgs {
      inherit system;
      overlays = [
        deploy-rs.overlay
        (self: super: { deploy-rs = { inherit (pkgs) deploy-rs; lib = super.deploy-rs.lib; }; })
      ];
    };
    nodes = {
      aurora = "locahost";
    };
    profiles = {
      base = {
        user = "root";
        path = deployPkgs.deploy-rs.lib.activate.custom deployPkgs.hello "./bin/hello";
      };
    };
  in {
    deploy.nodes = builtins.mapAttrs(node: hostname: {
      hostname = hostname;
      profiles = profiles;
    }) nodes;
  
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
