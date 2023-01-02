{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-filter.url = "github:numtide/nix-filter";
  };
  outputs = { self, nixpkgs, flake-utils, gomod2nix, nix-filter, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ gomod2nix.overlays.default ];
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
            mkdir -p $out/bin
            cp build/launcher $out/bin/
            cp build/osquery-extension.ext $out/bin/
          '';
          nativeBuildInputs = with pkgs; [ go-bindata git ];
          GIT_SHA = "0000000000000000000000000000000000000000";
          GIT_BRANCH = "main";
          GIT_VERSION = version;
        };
        # TODO: should only be x86_64-linux
        packages.osquery = pkgs.stdenv.mkDerivation rec {
          pname = "osquery";
          version = "5.2.3";
          src = pkgs.fetchurl {
            url =
              "https://github.com/osquery/osquery/releases/download/${version}/osquery_${version}-1.linux_amd64.deb";
            sha256 = "sha256-RLDlNYlBXl63PEy/6gGj8T3ScJDGK4o9hp4k2Zp23vQ=";
          };
          sourceRoot = ".";
          unpackCmd = "${pkgs.dpkg}/bin/dpkg-deb -x $curSrc .";
          nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
          buildInputs = with pkgs; [ zlib ];
          installPhase = ''
            cp -r opt/osquery $out
          '';
        };
        # TODO: should only be x86_64-linux
        nixosModules.default = import ./modules self;
        apps.default = flake-utils.lib.mkApp { drv = packages.default; };
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
