{
  description = "JuicedUpCardGame development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    # The Godot project alone, so deploy-only edits do not rebuild the export.
    projectSrc = nixpkgs.lib.fileset.toSource {
      root = ./.;
      fileset = nixpkgs.lib.fileset.difference ./. (nixpkgs.lib.fileset.unions [
        ./.github
        ./deploy
        ./flake.lock
        ./flake.nix
      ]);
    };
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = [pkgs.godot_4_7];
      };
    });

    packages = forAllSystems (pkgs: let
      deploy = pkgs.callPackage ./deploy/image.nix {
        src = projectSrc;
        version = self.shortRev or self.dirtyShortRev or "dev";
      };
    in {
      server = deploy.server;
      server-image = deploy.image;
    });

    # `nix run .#server-image | podman load` streams the image without leaving
    # a `result` link in the project root, which Godot would try to import.
    apps = forAllSystems (pkgs: {
      server-image = {
        type = "app";
        program = "${self.packages.${pkgs.system}.server-image}";
      };
    });
  };
}
