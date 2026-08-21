{ self, inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "v8-9.7.106.18" ];
        };
        overlays = [
          (import inputs.rust-overlay)
          self.overlays.default
          (final: prev: {
            curl_8_6 = prev.curl.overrideAttrs (old: rec {
              version = "8.6.0";
              src = prev.fetchurl {
                urls = [
                  "https://curl.haxx.se/download/curl-${version}.tar.xz"
                  "https://github.com/curl/curl/releases/download/curl-${
                    builtins.replaceStrings [ "." ] [ "_" ] version
                  }/curl-${version}.tar.xz"
                ];
                hash = "sha256-PM1V2Rr5UWU534BiX4GMc03G8uz5utozx2dl6ZEh2xU=";
              };
              configureFlags = builtins.filter (
                flag: !builtins.elem flag [
                  "--with-nghttp3"
                  "--with-ngtcp2"
                ]
              ) old.configureFlags;
            });
            v8_oldstable = prev.callPackage ./packages/v8-oldstable { };
          })
          inputs.devshell.overlays.default
        ];
      };
    };
}
