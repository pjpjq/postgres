{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  python3,
  openssl,
  zlib,
  libpq,
  lz4,
  bzip2,
  libxml2,
  libyaml,
  zstd,
  libbacktrace,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pgbackrest";
  version = "2.58.0";

  src = fetchFromGitHub {
    owner = "pgbackrest";
    repo = "pgbackrest";
    tag = "release/${finalAttrs.version}";
    hash = "sha256-RxvVqThfGnTCWTaM54Job+2HgJ7baf6ciFYTz496aKQ=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    python3
  ];

  buildInputs = [
    openssl
    zlib
    libpq
    lz4
    bzip2
    libxml2
    libyaml
    zstd
    libbacktrace
  ];

  # S3-only deployment: no SFTP repo support needed, and zstd compression
  # must be present (not left to "auto" detection).
  mesonFlags = [
    "-Dlibzstd=enabled"
    "-Dlibssh2=disabled"
  ];

  meta = {
    homepage = "https://pgbackrest.org";
    changelog = "https://github.com/pgbackrest/pgbackrest/releases/tag/release%2F${finalAttrs.version}";
    license = lib.licenses.mit;
    description = "Reliable PostgreSQL backup & restore";
    mainProgram = "pgbackrest";
  };
})
