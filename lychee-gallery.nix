{ stdenv, fetchzip, pkgs, env ? {} }:
stdenv.mkDerivation rec {
  pname = "Lychee";
  version = "4.6.2";
  src = fetchzip {
    url = "https://github.com/LycheeOrg/Lychee/releases/download/v${version}/Lychee.zip";
    sha256 = "sha256-dNujUTGaxvc6uZgyanNh9kIzRqfFA9yFhAtexu1sVc4=";
  };
  installPhase = ''
    shopt -s dotglob
    mkdir $out
    mv .env.example .env
    mv * $out/
    '';
}
