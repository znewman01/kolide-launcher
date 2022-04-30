{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix.url = "github:matthewpi/gomod2nix/matthewpi";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
    nix-filter.url = "github:numtide/nix-filter";
  };
  outputs = { nixpkgs, flake-utils, gomod2nix, nix-filter, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ gomod2nix.overlay ];
        };
      in rec {
        packages.default = pkgs.buildGoApplication rec {
          pname = "kolide-launcher";
          version = "v0.11.26";
          src = ./.;
          modules = ./gomod2nix.toml;
          buildPhase = ''
            # `make deps`
            go run cmd/make/make.go -targets=install-tools
            go generate ./pkg/packagekit/... ./pkg/packaging/... ./pkg/osquery/tables/... ./pkg/augeas/...

            # TUF update requires network connection
            # go run cmd/make/make.go -targets=generate-tuf

            # `make`
            go run cmd/make/make.go -targets=launcher -linkstamp
            go run cmd/make/make.go -targets=osquery-extension.ext -linkstamp
          '';
          checkPhase = ""; # tests fail on nixos
          installPhase = ''
            mkdir -p $out/{bin/lib}
            cp build/launcher $out/bin/
            cp build/osquery-extension.ext $out/lib/
          '';
          nativeBuildInputs = with pkgs; [ go-bindata git ];
          GIT_SHA = "0000000000000000000000000000000000000000";
          GIT_BRANCH = "main";
          GIT_VERSION = version;
        };
        applications.default = flake-utils.mkApp { drv = packages.default; };
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs;
            [
              nixfmt
              gocode
              gore
              gomodifytags
              gopls
              go-symbols
              gopkgs
              go-outline
              gotests
              gotools
              golangci-lint
              gomod2nix
            ] ++ packages.default.nativeBuildInputs;
        };
      });
}
