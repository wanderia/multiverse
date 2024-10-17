{
  description = "wanderia infra";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };

      # wanderia nodes
      # todo(py, 18/11/24): set actual nodes
      nodes = {
        aurora = "localhost";
        # artemis = "localhost";
        # hecate = "localhost";
        # luna = "localhost";
        # nemesis = "localhost";
        # nyx = "localhost";
      };
    in
    {
      packages."${system}" = {
        multiverse = pkgs.multiverse.multiverse;
        default = pkgs.multiverse.multiverse;
      };
      apps."${system}".multiverse = {
        type = "app";
        program = "${self.pacakges."${system}".multiverse}/bin/multiverse";
      };

      devShells."${system}".default = pkgs.mkShell {
        inputsFrom = [ self.packages."${system}".multiverse ];
        REST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        buildInputs = with pkgs; [
          nixVersions.latest
          cargo
          rustc
          rust-analyzer
          rustfmt
          clippy
          rust.packages.stable.rustPlatform.rustLibSrc
        ];
      };

      deploy.nodes = builtins.mapAttrs (node: hostname: {
        hostname = hostname;
        profiles = {
          # todo: add base nixos system profile.
          node = {
            user = "node";
            path = deployPkgs.deploy-rs.lib.activate.custom pkgs.multiverse.multiverse "${node}"; # todo(py): havent tested, could be "./bin/multiverse-activate ${node}"
          };
        };
      }) nodes;

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      formatter."${system}" = nixpkgs.legacyPackages."${system}".nixfmt-rfc-style;

      overlays.default = final: prev: {
        multiverse = {
          multiverse = final.rustPlatform.buildRustPackage {
            name = "multiverse";
            pname = "multiverse";
            version = "0.1.0";

            src = final.lib.sourceByRegex ./. [
              "Cargo\.lock"
              "Cargo\.toml"
              "src"
              "src/bin"
              ".*\.rs$"
            ];

            cargoLock.lockFile = ./Cargo.lock;

            meta = {
              description = "wanderia node controll";
              mainProgram = "multiverse-activate";
            };
          };

          lib = {
            activate = {
              __functor =
                node:
                final.buildEnv {
                  name = "multiverse-activate";
                  paths = [
                    (final.writeTextFile {
                      name = "multiverse-activate-" + node;
                      text = ''
                        #!${final.runtimeShell}
                        exec ${final.multiverse.multiverse}/bin/multiverse-activate "$@"
                      '';
                      executable = true;
                      destination = "/multiverse-activate";
                    })
                  ];
                };
            };
          };
        };
      };
    };
}
